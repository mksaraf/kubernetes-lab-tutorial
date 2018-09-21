# Applications Design Patterns
With the adoption of microservices and containers in the recent years, the way we design, develop and run software applications has changed significantly. Modern software applications are optimised for scalability, elasticity, failure, and speed of change. Driven by these new principles, modern applications require a different set of patterns and practices to be applied in an effective way.

In this section, we're going to analyze these new principles with the aim to give a set of guidelines for the design of modern software applications on Kuberentes. The principles and the approach to the design patterns are inspired by the *[Kubernets Patters](http://leanpub.com/k8spatterns)* book by *Bilgin Ibryam* and *Roland Huß*.

Design patterns are grouped into several categories:

  * **Foundational Patterns:** underlying principles and practices for building cloud native applications in Kuberentes.
  * **Behavorial Patterns:** concepts for managing various types of containers and their interactions in Kuberentes.
  * **Structural Patterns:** how to organize containers in Kubernetes.
  * **Configuration Patterns:** how application configurations can be handled in Kubernetes.

However, the same pattern may have multiple implications and fall into multiple categories. Also patterns are often interconnected, as we will see in the following sections.

## Foundational Patterns
