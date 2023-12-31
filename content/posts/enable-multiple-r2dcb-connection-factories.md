---
date: "2023-11-26T00:00:00"
draft: false
tags:
- springboot
title: Enable multiple R2DBC database connection factories
---
Migrating an existing project to Spring WebFlux requires quite some effort.
You have to touch the entire configurations. 
If you work incrementally you will find most parts of an WebFlux application are implemented fast and easy.
But if you dig deeper into the application requirements things can become interesting.

While working on the database access layer and migrating from JDBC to R2DBC I found one of this interesting challenges.

Starting small and followed first the documentation.

From the reference documentation: (https://docs.spring.io/spring-boot/docs/current/reference/html/data.html#data.sql.r2dbc)
>`ConnectionFactory` configuration is controlled by external configuration properties in `spring.r2dbc.*`.
>For example, you might declare the following section in `application.properties`:
>```yaml
>spring:
>  r2dbc:
>    url: "r2dbc:postgresql://localhost/test"
>    username: "dbuser"
>    password: "dbpass"
>```
{.blockqoute}

The refactoring from JDBC to R2DBC for the first database connection was done easily:
- adding the R2DBC config to the application.yaml file
- create repository interface for entity class
- Adding the `@EnableR2dbcRepositories` annotation to the application class
- using the default repository methods for lookup by id
- adding `@query` annotations using complex SQL queries

But after that there was a big question mark how to add a second connection.

This information is not available in the Spring Boot documentation.
You have to go to the Spring Data R2DBC documentation.
There you are told that you
>**...need to define a few beans yourself to configure Spring Data R2DBC to work with multiple databases.**
{.blockqoute}

***Please note that I use the current version Spring Data is 2.0 (as of November 2023) as reference.***

## Multiple Connection Properties
Multiple connection properties from the application properties is currently not supported out the box by Spring Boot.

https://docs.spring.io/spring-boot/docs/3.2.0/api/org/springframework/boot/autoconfigure/r2dbc/R2dbcProperties.html
These are the default `@ConfigurationProperties` used by the Spring Boot auto configuration.

Based on this class I generated a new custom `@ConfigurationProperties` class.
This simply expects a keyed set of `import org.springframework.boot.autoconfigure.r2dbc.R2dbcProperties.R2dbcProperties` in the application configuration.

```java
@ConfigurationProperties(prefix = "r2dbc")
@RequiredArgsConstructor
public class R2DBCConfigurationProperties {
    @Getter
    @Setter
    private Map<String, R2dbcProperties> options;

    public static ConnectionFactoryOptions.Builder buildConnectionFactoryOptions(R2dbcProperties r2dbcProperties) {
		ConnectionFactoryOptions urlOptions = ConnectionFactoryOptions.parse(r2dbcProperties.getUrl());
		ConnectionFactoryOptions.Builder optionsBuilder = urlOptions.mutate();
        //...
		return optionsBuilder;    
    }
}
```
This way you can now specify multiple R2DBC connections properties in the `application.yaml`.
```yaml
r2dbc:
    connection1:
        url:r2dbc:h2:mem:///demo
        username:conn
        password:conn
    connection2:
        url:r2dbc:h2:mem:///demo
        username:conn
        password:conn
```

## Connection Factories
Using the above `ConfigurationProperties` you can now build a `@Configuration` class.
This configuration enables `R2DBCConfigurationProperties`.
Unfortunately these properties cannot be used directly to create a new `ConnectionFactory` instance.
For this webflux-recipes repository provides the `R2DBCConfigurationProperties.buildConnectionFactoryOptions` method.
This creates a `ConnectionFactoryOptions.Builder` instance and applies the properties to it.
Now it is possible to create a `ConnectionFactory` using the `ConnectionFactoryBuilder`.
The builder is initialized with options derived from the properties.

```java
@Configuration
@EnableConfigurationProperties(R2DBCConfigurationProperties.class)
public class R2DBCConfiguration extends R2DBCConfigurationProperties {
    
    @Bean
    ConnectionFactory connection1Factory(R2DBCConfigurationProperties properties) {
        return ConnectionFactoryBuilder
            .withOptions(R2DBCConfigurationProperties.buildConnectionFactoryOptions(properties.getOptions().get("connection1"))
        ).build();
    }
    
}
```
## R2DBC repositories and multiple connection factories
Now that we have multiple properties available how to assign these to a specific `ReactiveCrudRepositiory` interface.

To make it short. This is not possible. The longer version. At least not directly.

### EnableR2dbcRepositories
Repositories are enabled with the `@EnableR2dbcRepositories` annotation.
As stated in the documentation (https://docs.spring.io/spring-data/relational/reference/r2dbc/repositories.html) repositories require an `R2dbcEntityOperations` class instance.

### Default `R2dbcEntityOperations`
The default configuration is expecting exactly one `ConnnectionFactory` bean and creates a `R2dbcEntityOperations` instance and scans the entire application class path for `ReactiveCrudRepository` definitions.

### Custom `R2dbcEntityOperations`
Actually we want to use multiple `ConnectionFactory` instances.
To be able to do this we need to customize the `@EnableR2dbcRepositories`.
First we add the parameter `basePackages`. Here we can add one or more base package paths that are scanned for repositories.
The second parameter `entityOperationsRef` takes the bean name of `R2dbcEntityOperations` instance to used to back the identified repositories.

```java
@Configuration
@EnableR2dbcRepositories(basePackages = "io.github.d_sch.connection1", entityOperationsRef = "connection1R2dbcEntityOperations")
static class Connection1FactoryConfiguration {

    @Bean
    public R2dbcEntityOperations mysqlR2dbcEntityOperations(@Qualifier("connection1Factory") ConnectionFactory connectionFactory) {

        DatabaseClient databaseClient = DatabaseClient.create(connectionFactory);

        return new R2dbcEntityTemplate(databaseClient, MySqlDialect.INSTANCE);
    }
}
```

As I promised above. It is not possible target single repositories. But it is possible to add multiple package paths containing single repositories.

## Wrapping up
Hope this post was interesting, if you have any concerns or questions please create an issue 
- using R2DBC instead of JDBC requires some substantial application changes.
- there is no out of the box support in Spring Data or Spring Boot to access multiple data sources.


You can find the full source code in my git repository: (https://github.com/d-sch/webflux-recipes)