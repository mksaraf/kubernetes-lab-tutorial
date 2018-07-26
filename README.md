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

2. [Core Concepts](./content/basics.md)
    * [Pods](./content/basics.md#pods)
    * [Labels](./content/basics.md#labels)
    * [Replica Sets](./content/basics.md#replica-sets)
    * [Deployments](./content/basics.md#deployments)
    * [Services](./content/basics.md#services)
    * [Volumes](./content/basics.md#volumes)
    * [Config Maps](./content/basics.md#config-maps)
    * [Daemons](./content/basics.md#daemons)
    * [Jobs](./content/basics.md#jobs)
    * [Cron Jobs](./content/basics.md#cron-jobs)
    * [Namespaces](./content/basics.md#namespaces)
    * [Quotas and Limits](./content/basics.md#quotas-and-limits)
    
3. [Cluster Networking](./content/network.md)
    * [Pod Networking](./content/network.md#pod-networking)
    * [Exposing services](./content/network.md#exposing-services)
    * [Service discovery](./content/network.md#service-discovery)
    * [Accessing services](./content/network.md#accessing-services)
    * [External services](./content/network.md#external-services)
    * [Ingress controller](./content/ingress.md)
    * [Static Pods](./content/static.md)

4. [Data Management](./content/storage.md)
    * [Local Persistent Volumes](./content/storage.md#local-persistent-volumes)
    * [Volume Access Mode](./content/storage.md#volume-access-mode)
    * [Volume State](./content/storage.md#volume-state)
    * [Volume Reclaim Policy](./content/storage.md#volume-reclaim-policy)
    * [Manual volumes provisioning](./content/storage.md#manual-volumes-provisioning)
    * [Storage Classes](./content/storage.md#storage-classes)
    * [Dynamic volumes provisioning](./content/storage.md#dynamic-volumes-provisioning)
    * [Redis benchmark](./content/storage.md#redis-benchmark)
    * [Stateful Applications](./content/stateful.md)
    * [Configure GlusterFS as Storage backend](./content/glusterfs.md)
    * [Configure Ceph as Storage backend](./content/ceph.md)
    
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

7. [Scaling the Control Plane](./content/hacp.md)
   * [Configuring multiple etcd instances](./content/hacp.md#configuring-multiple-etcd-instances)
   * [Configuring multiple APIs servers](./content/hacp.md#configuring-multiple-apis-servers)
   * [Configuring multiple Controller Managers](./content/hacp.md#configuring-multiple-controller-managers)
   * [Configuring multiple Schedulers](./content/hacp.md#configuring-multiple-schedulers)
   * [Configuring the Load Balancer](./content/hacp.md#configuring-the-load-balancer)
   * [APIs server redundancy](./content/hacp.md#apis-server-redundancy)   
   * [Controllers redundancy](./content/hacp.md#controllers-redundancy)

8. [Secure Access](./content/secure.md)
   * [Service Accounts](./content/secure.md#service-accounts)
   * [Authentication](./content/secure.md#authentication)
   * [Authorization](./content/secure.md#authorization)
   * [Admission Control](./content/secure.md#admission-control)
   * [Accessing the APIs server](./content/secure.md#accessing-the-apis-server)
   * [Pod Security Context](./content/secure.md#pods-security-context) 

## Disclaimer
This tutorial is for personal use only. This is just a lab guide, not a documentation for Kubernets, please go to their online
documentation sites for more details about what Kubernets is and how does it work.
