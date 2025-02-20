---
title: Terraform Structuring Lessons
description: ""
date: 2025-02-02T18:57:01.827Z
preview: ""
draft: false
tags: [terraform]
categories: [IaC]
---
# Overview
Working with Terraform takes some time to get comfortable with. One of the greatest myths in all the examples is the `main.tf`. Starting a new infrastructure it can make sense to begin with one file an put all resources in there. But after reaching several pages in editor things can easily go down hill from there.

I want to share some lessons learned after taking over larger applications infrastructure project without being able to reach the initial author.

# Obstacles For Reading Into Existing Terraform Code
Terraform code for an cloud infrastructure doesn't make it easy to understand the full picture easily.
There is no real beginning or end. Having files containing multiple resources hide all the complexity.
Having only one large file to start with is the worst case. Following the dependencies and build a mental 
overview overloads the mental resource on multiple levels. Simply remembering multiple resources and there 
dependencies at once is slowing your working memory and increase the error probability.

# Remove Obstacles By Refactor First
This learning lead me to conclude that it is takes too much time to try to understand unstructured Terraform code. 
And it is painful too. Working with a lot of files containing multiple resource definitions I found doing refactoring 
first instead really worth the effort. 

This makes it much easier do get into a infrastructure. Breaking these into atomic files and applying a
good file naming convention already helps. You get an understanding of the different parts of the infrastructure
just by looking at the files.

# Conventions For Readable Readable Code

## Don't
### Declare Multiple Resources Into One File
Multiple resource within one file make it complicate to find and understand changes
- First you must identify the scope of the change, e.g. which resource is affected.
- Understand the change
- Finally make sure this affects the correct resource or property

This requires highest concentration and drains a lot of power. This leads to errors and at the same time 
makes them harder to detect.

## Do
### Have Atomic Resource Files
Files should contain only one single resource definition. Complex resources can easily fill multiple screens.

- Changes to files consisting only of one resource definition can be applied and verified with higher confidence. 
- Having atomic resource files make concurrent changes less error prone and prevents or at least reduce number of merge conflicts.

### File Name Conventions
Using a good file naming convention you can identify important resource information just by the filename and it's parent directories. This reduces the information one must remember to understand the structure of the infrastructure.

A good naming convention 
- orders related resources 
- enables to get an high-level overview without reading into the files
- provides most important information like resource type 

### Use Modules
The usage of modules can help to adhere to one or multiple of these principles
- Structure complex infrastructure

Defining an infrastructure component that requires a large number of dependent or interdependent resources
is hard. Especially if all resources are in flat file or even a flat structure files. Especially naming gets
cumbersome.

- don't repeat yourself - DRY

If you create multiple infrastructure components using similar resource definitions it is a good idea to place
these into modules.

- re-use

While implementing multiple infrastructure components finally pattern emerge. These can be used to define modules
used by multiple infrastructure components. First within the project. Matured modules can be stored within a separate 
git repository and referenced by the infrastructure components these.

# Closing
This provides an overview about what to take care of to form a high quality IaC project.
In further posts I will highlight more details of the different aspects mentioned above.
And I plan to create posts sharing details what to take care of while building AWS infrastructure components.
