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
Kubernetes adds a new mindset to the software application design by offering a new set of distributed primitives and runtime
for creating distributed systems spreading across multiple nodes of a cluster. Having these new primitives, we have an additional set of tools to implements software applications, in addition to the already well known primitives offered by programming languages and runtimes.

#### Containers
Containers are building blocks for applications running in Kubernetes. From the technical point of view, a container provides
packaging and isolation. However, in the context of a distributed application, the container can be described as:

 * The boundary of a unit of functionality that addresses a single concern.
 * It is has its own release cycle.
 * It is self contained, defines and carries its own build time dependencies.
 * It is immutable and once it is built, it does not change.
 * It has a well defined set of APIs to expose its functionality.
 * It runs as a single well behaved process.
 * A container instance is safe to scale up or down at any moment.
 * It is parameterised and created for reuse.
 * It is paremetrized for the different environments.
 * It is parameterised for the different use cases.

Having small and modular reusable containers leads us to create a set of standard tools, similarly to a good reusable library provided by a programming language or runtime.

Containers are designed to run only a single process per container, unless the process itself spawns child processes. Running multiple unrelated processes in a single container, leads to keep all those processes up and running, manage their logs, their interactions, and their healtiness. For example, we have to include a mechanism for automatically restarting individual processes if they crash. Also, all those processes would log to the same standard output, so we'll have hard time figuring out which process logged what.


#### Pods
In Kubernetes, a group of one or more containers is called a pod. Containers in a pod are deployed together, and are started, stopped, and replicated as a group. When a pod does contain multiple containers, all of them are always run on a single node, it never spans multiple nodes.

The simplest pod definition describes the deployment of a single container as in the following configuration file  

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace:
  labels:
    run: nginx
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

We can have more containers in the same pod. All containers inside the same pod share the same resources, e.g. network and process namespaces. This allows the containers in a pod to interact each other through networking via localhost, or inter-process communication mechanisms, if desired. Kubernetes achieves this by configuring all containers in the same pod to use the same set of Linux namespaces, instead of each container having its own set. They can also share the same PID namespace, but that isn’t enabled by default.

Containers of the same pod need to take care not to bind to the same port number or they will run into port conflicts. However, containers of different pods can never run into port conflicts, because each pod has a separate port space.

Multiple containers in the same pod cannot share their file system becuse the container’s filesystem comes from the container image, and, by default, it is fully isolated from other containers. However, containers in the same pod can share some host file folders called volumes.

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
