# Kubernetes Lab Tutorial
**Kubernetes** is an open-source platform for automating deployment, scaling, and operations of application containers across a cluster of hosts. This lab tutorial is based on CentOS distribution. 

## Content
1. [Architecture](./content/architecture.md)
    * [etcd](./content/architecture.md#etcd)
    * [API Server](./content/architecture.md#api-server)
    * [Controller Manager](./content/architecture.md#controller-manager)
    * [Scheduler](./content/architecture.md#scheduler)
    * [Agent](./content/architecture.md#agent)
    * [Proxy](./content/architecture.md#proxy)
    * [CLI](./content/architecture.md#command-line-client)

2. [Setup](./content/setup.md)
    * [Requirements](./content/setup.md#requirements)
    * [Configure Master](./content/setup.md#configure-masters)
    * [Configure Workers](./content/setup.md#configure-workers)
    * [Configure DNS service](./content/setup.md#configure-dns-service)

3. [Core Concepts](./content/core.md)
    * [Pods](./content/core.md#core)
    * [Labels](./content/core.md#labels)
    * [Controllers](./content/core.md#controllers)
    * [Deployments](./content/core.md#deployments)
    * [Services](./content/core.md#services)
    * [Volumes](./content/core.md#volumes)
    
4. [Networking](./content/network.md)
    * [Pod Networking](./content/network.md#pod-networking)
    * [Exposing services](./content/network.md#exposing-services)
    * [Service discovery](./content/network.md#service-discovery)
    * [Accessing services](./content/network.md#accessing-services)
    * [Ingress controller](./content/ingress.md)

5. [Storage](./content/storage.md)
    * [Local Persistent Volume](./content/storage.md#local-persistent-volume)
    * [Volume Access Mode](./content/storage.md#volume-access-mode)
    * [Volume Reclaim Policy](./content/storage.md#volume-reclaim-policy)
    * [NFS Persistent Volume](./content/storage.md#nfs-persistent-volume)
    
6. [Additional Concepts](./content/additional.md)
    * [Namespaces](./content/additional.md#namespaces)
    * [Quotas and Limits](./content/additional.md#quotas-and-limits)
    * [Daemon Sets](./content/additional.md#daemon-sets)
    
7. [Cluster Healing](./content/admin.md)

8. [Securing the Cluster](./content/secure.md)
    * [Create TLS certificates](./content/secure.md#create-tls-certificates)
    * [Securing etcd](./content/secure.md#securing-etcd)
    * [Securing the master](./content/secure.md#securing-the-master)
    * [Accessing the server](./content/secure.md#accessing-the-server)   
    * [Securing the worker](./content/secure.md#securing-the-worker)

9. [Scaling the Control Plane](./content/info.md)

10. [Users Management](./content/info.md)

## Disclaimer
This tutorial is for personal use only. This is just a lab guide, not a documentation for Kubernets, please go to their online
documentation sites for more details about what Kubernets is and how does it work.
