# Stateful Applications
Common controller as Replica Set and Daemon Set are a great way to run stateless applications, but their semantics are not so friend for deploying stateful applications. In this section we are going to configure Stateful applications on a kubernetes cluster through Stateful Set.

## Stateful Set
The purpose of Stateful Set is to provide a controller with the correct semantics for deploying stateful workloads. However, before you go all in on converging your storage tier and your orchestration framework, you should consider using external storage through a headless service. See an example [here](./network.md#external-services).

A Stateful Set manages the deployment and scaling of a set of pods, and provides guarantees about the ordering and uniqueness of these pods. Like a Replica Set a StatefulSet manages pods that are based on an identical container specifications. Unlike Replica Set, a Stateful Set maintains a sticky identity for each of pod that is maintained across any rescheduling.

The apache-sts.yaml configuration file define a simple Stateful Set for an apache application made of three replicas
