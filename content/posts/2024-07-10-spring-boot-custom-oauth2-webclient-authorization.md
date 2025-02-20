---
title: Spring Boot Custom OAuth2 WebClient Authorization
date: 2024-07-10T20:38:52.963Z
draft: true
tags:
    - springboot
---
#  Overview
Lately there was this requirement to connect web services requiring an authorization bearer token.
Unfortunenately these were not using the standardize OAuth2 client credentials.

In a hurry a first implementation was created.
- These first checked if token is expired.
- If expired called the services for the authentication token.
- Finally calling the web server after manually adding the ```Authorization: Bearer ...``` header.

This worked. But that wasn't satisfying.

Spring Security provides a full OAuth2 token registry with automatically token expiration handling available and we are not able using it.

It nagged me... what would it take to support our custom tokens re-using as much as possible from the Spring Security implementation.

# Spring Securtiy OAuth2 Client
First I want to show an example of a OAuth2 ```ClientRegistration``` using the Spring Boot property mapping

```YAML
spring:
    security:
        oauth2:
            client:
                registration:
                    provider: auth
                    client-id: clientId
                    client-secret: clientSecret
                    client-authentication-method: client-secret-post
                    authorization-grant-type: client_credentials
                provider:
                    auth:
                        token-uri: https:/auth/token
```

- For details of the OAuth2 client registration please look into the offical Spring Security OAuth2 client documentation.\
https://docs.spring.io/spring-security/reference/reactive/oauth2/client/index.html
- Documentation about the implementation of the Spring OAuth2 Client can be found here:\
https://docs.spring.io/spring-security/reference/reactive/oauth2/client/core.html

# Implementing support of a custom token

After peeking into the OAuth2 implementation I found that it would not be that complicated to extend the implementation but
- first I found that all the implemenation classes using ```default``` package access 
    - This requires to implement everything in the ```org.springframework.security.oauth2.client``` package.
- next was that all the OAuth2 classes are final classes

Peeking into the client registration handling one see it is not possible to extend the existing implementation directly without forking the Spring Boot Code. There are no extensions points. 

## CustomClientRegistration

We circumvent this inconvenience using custom ```ConfigurationProperties``` name ```CustomClientRegistration``` using the property prefix ```spring.security.oauth2.client.custom```

Here an example using the ```custom``` client registration.

```YAML
spring:
    securitry:
        oauth2:
            client:
                registration:
                    provider: custom-auth
                    authorization-grant-type: custom
                provider:
                    custom-auth:
                        token-uri: https:/auth/token
                custom:
                    custom-auth:
                        username: clientId
                        password: password
                        source: client
```
## ServerOAuth2AuthorizedClientRepository / ReactiveOAuth2AuthorizedClientService

To make it easy we just re-use the provided implementations.\
And just replacing the OAuth2 token with the custom token.

## ReactiveOAuth2AuthorizedClientManager / ReactiveOAuth2AuthorizedClientProvider

What we are interested in is to implement a custom ```ReactiveOAuth2AuthorizedClientProvider```.\
Custom authentication requires a username, password and source for authorization.\
That sounds similar to the OAuth2 client credentials authorization. 

### Implement CustomReactiveOAuth2AuthorizedClientProvider

We want to re-use the Spring Security OAuth2 client credentials implementation.\
But the ```ClientCredentialsReactiveOAuth2AuthorizedClientProvider``` is a final class.\
https://github.com/spring-projects/spring-security/blob/main/oauth2/oauth2-client/src/main/java/org/springframework/security/oauth2/client/ClientCredentialsReactiveOAuth2AuthorizedClientProvider.java

This requires that we need to create a clone of this class.\


The clone has some dependencies. We just follow the implementation from Spring Security closely.\
This requires to clone the following classes too:
- ```OAuth2ClientCredentialsGrantRequest```\
https://github.com/spring-projects/spring-security/blob/main/oauth2/oauth2-client/src/main/java/org/springframework/security/oauth2/client/endpoint/OAuth2ClientCredentialsGrantRequest.java
- ```OAuth2AccessTokenResponseBodyExtractor``` as ```CustomOAuth2AccessTokenResponseBodyExtractor```\ https://github.com/spring-projects/spring-security/blob/main/oauth2/oauth2-core/src/main/java/org/springframework/security/oauth2/core/web/reactive/function/OAuth2AccessTokenResponseBodyExtractor.java
-```AbstractWebClientReactiveOAuth2AccessTokenResponseClient``` as ```WebClientReactiveCustomTokenResponseClient```\
https://github.com/spring-projects/spring-security/blob/main/oauth2/oauth2-client/src/main/java/org/springframework/security/oauth2/client/endpoint/AbstractWebClientReactiveOAuth2AccessTokenResponseClient.java

### Modify clone OAuth2CustomGrantRequest

1. Create a clone of ```OAuth2ClientCredentialsGrantRequest``` with the name ```OAuth2CustomGrantRequest```.
2. We add a field ```customClientRegistration``` for holding our ```CustomClientRegistration```
3. We add a getter for the ```customClientRegistration```
4. We add the ```CustomClientRegistration customClientRegistration``` parameter to the constructor
5. The constructor set the new ```customClientRegistration``` field from above

### OAuth2AccessTokenResponseBodyExtractor

1. Create a clone of ```OAuth2AccessTokenResponseBodyExtractor``` with the name ```CustomOAuth2AccessTokenResponseBodyExtractor```
2. Get the encoded JWT token
    - The jwt token is send in the field "jwt"
3. Decode the encoded JWT token
4. Get expiration from JWT and calculate the life time using the duration between now and expiration date time 
    - Our custom authorization is returning a Json object that is missing the standard ```lifetime``` field in seconds.
5. Create a AccessTokenResponse
    - create BearerAccessToken with the encoded JWT, the calculated life time and an empty Scope

### WebClientReactiveCustomTokenResponseClient

1. Create a clone of ```AbstractWebClientReactiveOAuth2AccessTokenResponseClient``` with the name ```WebClientReactiveCustomTokenResponseClient```
2. Remove the no longer required headers converter ```headersConverter```


### CustomReactiveOAuth2AuthorizedClientProvider

1. Create a clone of ```ClientCredentialsReactiveOAuth2AuthorizedClientProvider``` wiht the name ```CustomReactiveOAuth2AuthorizedClientProvider```
2. Replace ```WebClientReactiveClientCredentialsTokenResponseClient``` with our implementation ```CustomWebClientReactiveClientCredentialsTokenResponseClient```
3. We implement our own custom ```AuthorizationGrantType``` used to validate if the ClientRegistration is referencing the correct authorization-grant-type ```custom-legacy-auth```.
4. Replace ```OAuth2ClientCredentialsGrantRequest``` with ```OAuth2CustomGrantRequest```


