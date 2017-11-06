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

2. [Core Concepts](./content/core.md)
    * [Pods](./content/core.md#core)
    * [Labels](./content/core.md#labels)
    * [Controllers](./content/core.md#controllers)
    * [Deployments](./content/core.md#deployments)
    * [Services](./content/core.md#services)
    * [Volumes](./content/core.md#volumes)
    * [Daemons](./content/core.md#daemons)
    * [Namespaces](./content/core.md#namespaces)
    * [Quotas and Limits](./content/core.md#quotas-and-limits)
    
3. [Networking](./content/network.md)
    * [Pod Networking](./content/network.md#pod-networking)
    * [Exposing services](./content/network.md#exposing-services)
    * [Service discovery](./content/network.md#service-discovery)
    * [Accessing services](./content/network.md#accessing-services)
    * [Ingress controller](./content/ingress.md)

4. [Storage](./content/storage.md)
    * [Local Persistent Volumes](./content/storage.md#local-persistent-volumes)
    * [Volume Access Mode](./content/storage.md#volume-access-mode)
    * [Volume State](./content/storage.md#volume-state)
    * [Volume Reclaim Policy](./content/storage.md#volume-reclaim-policy)
    * [Manual volumes provisioning](./content/storage.md#manual-volumes-provisioning)
    * [Storage Classes](./content/storage.md#storage-classes)
    * [Dynamic volumes provisioning](./content/storage.md#dynamic-volumes-provisioning)
    
5. [Cluster Healing](./content/admin.md)
    * [Cluster Backup and Restore](./content/admin.md#cluster-backup-and-restore)
    * [Control Plane Failure](./content/admin.md#control-plane-failure)
    * [Worker Failure](./content/admin.md#worker-failure)

6. [Setup a Secure Cluster](./content/setup.md)
   * [Requirements](./content/setup.md#requirements)
   * [Install binaries](./content/setup.md#install-binaries)
   * [Create TLS certificates](./content/setup.md#create-tls-certificates)
   * [Configure etcd](./content/setup.md#configure-etcd)
   * [Configure the Control Plane](./content/setup.md#configure-the-control-plane)
   * [Configure the clients](./content/setup.md#configure-the-clients)
   * [Configure the Compute Plane](./content/setup.md#configure-the-compute-plane)
   * [Define the Network Routes](./content/setup.md#define-the-network-routes)
   * [Configure DNS service](./content/setup.md#configure-dns-service)

7. [Scaling the Control Plane](./content/info.md)

8. [User Management](./content/users.md)
   * [Service Accounts](./content/users.md#service-accounts)
   * [Authentication](./content/users.md#authentication)
   * [Authorization](./content/users.md#authorization)

9. [Additional Concepts](./content/info.md)
    * [Stateful Applications](./content/stateful.md)
    * [Batch Processes](./content/batch.md)
    * [Static Pods](./content/static.md)
   

## Disclaimer
This tutorial is for personal use only. This is just a lab guide, not a documentation for Kubernets, please go to their online
documentation sites for more details about what Kubernets is and how does it work.
