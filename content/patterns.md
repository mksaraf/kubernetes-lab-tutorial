# Applications Design Patterns
With the adoption of microservices and containers in the recent years, the way we design, develop and run software applications has changed significantly. Modern software applications are optimised for scalability, elasticity, failure, and speed of change. Driven by these new principles, modern applications require a different set of patterns and practices to be applied in an effective way.

In this section, we're going to analyse these new principles with the aim to give a set of guidelines for the design of modern software applications on Kuberentes.

Design patterns are grouped into several categories:

1. [Foundational Patterns](#foundational-patterns): basic principles for cloud native applications.
2. [Behavorial Patterns](#behavorial-patterns): define various types of containers.
3. [Structural Patterns](#structural-patterns): organize interactions between containers.
4. [Configuration Patterns](#configuration-patterns): handle configurations in containers.

However, the same pattern may have multiple implications and fall into multiple categories. Also patterns are often interconnected, as we will see in the following sections.

## Foundational Patterns
Foundational patterns refer to the basic principles for building cloud native applications in Kubernetes. In this section, we're going to cover:

* [Distributed Primitives](#distributed-primitives)
* [Predictable Demands](#predictable-demands)
* [Dynamic Placement](#dynamic-placement)
* [Declarative Deployment](#declarative-deployment)
* [Observable Interior](#observable-interior)
* [Life Cycle Conformance](#life-cycle-conformance)

### Distributed Primitives
### Predictable Demands
### Dynamic Placement
### Declarative Deployment
### Observable Interior
### Life Cycle Conformance

## Behavorial Patterns
Behavorial Patterns define various type of container behaviour:

* [Batch Jobs](#batch-jobs)
* [Scheduled Jobs](#scheduled-jobs)
* [Daemon Services](#daemon-services)
* [Singleton Services](#singleton-services)
* [Self Awareness](#self-awareness)

### Batch Jobs
### Scheduled Jobs
### Daemon Services
### Singleton Services
### Self Awareness

## Structural Patterns
Structural Patterns refer to how organize containers interaction:

* [Sidecar](#sidecar)
* [Initialiser](#initialiser)
* [Ambassador](#ambassador)
* [Adapter](#adapter)

### Sidecar
### Initialiser
### Ambassador
### Adapter

## Configuration Patterns
Configuration Patterns refer to how handle configurations in containers:

* [Environment Variables](#environment-variables)
* [Configuration Resources](#configuration-resources)
* [Configuration Templates](#configuration-templates)
* [Immutable Configurations](#immutable-configurations)

### Environment Variables
### Configuration Resources
### Configuration Templates
### Immutable Configurations
