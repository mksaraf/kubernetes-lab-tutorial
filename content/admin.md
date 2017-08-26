# Cluster Administration
In this section we are going to deal with some advanced cluster admin tasks:

   * [Cluster healing](#cluster-healing)
   * [Securing the Cluster](#securing-the-cluster)
   * [Scale the Control Plane](#scaling-the-control-plane)

## Cluster healing
In this section we'll walk through some fire drills and to understand how to operate with a running kubernetes cluster. To show the impact of the cluster on user applications, start a simple nginx deploy of three pods and the related service

    kubectl create -f nginx-deploy.yaml
    kubectl create -f nginx-svc.yaml

    kubectl get all

    NAME                        READY     STATUS    RESTARTS   AGE
    po/nginx-1423793266-bfpg6   1/1       Running   0          13m
    po/nginx-1423793266-qfgvb   1/1       Running   0          13m
    po/nginx-1423793266-vhzq7   1/1       Running   1          2h

    NAME             CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
    svc/kubernetes   10.32.0.1      <none>        443/TCP          1d
    svc/nginx        10.32.163.25   <nodes>       8000:31000/TCP   2h

    NAME           DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
    deploy/nginx   3         3         3            3           2h

    NAME                  DESIRED   CURRENT   READY     AGE
    rs/nginx-1423793266   3         3         3         2h


### Cluster Backup and Restore
The state of the cluster is stored in the etcd db, usually running on the master node along with the API Server and other components of the control plane. To avoid single point of failure, it is recommended to use an odd number of etcd nodes.

For now, let's take a backup of the cluster data. To interact with etcd, we're going to use the ``etcdctl`` admin tool. The etcd db supports both v2 and v3 APIs.

For v2 APIs:

    etcdctl --endpoints=http://10.10.10.80:2379 member list

    89f7d3a76f81eee3: name=kubem00
    peerURLs=http://10.10.10.80:2380
    clientURLs=http://10.10.10.80:2379
    isLeader=true

For v3 APIs, set first the env variable

    export ETCDCTL_API=3
    etcdctl --endpoints=http://10.10.10.80:2379 member list
    
    89f7d3a76f81eee3, started, kubem00, http://10.10.10.80:2380, http://10.10.10.80:2379


Our kubernetes cluster is using, by default, the v3 APIs.

First, take a snapshot of the current cluster state

    etcdctl --endpoints=http://10.10.10.80:2379 snapshot save etcd-backup.db

The sanpshot is taken as backup ``etcd-backup.db`` file on the local disk.

    etcdctl --endpoints=http://10.10.10.80:2379 snapshot status etcd-backup.db
    be27a17b, 184596, 613, 3.3 MB

Now make some changes to the cluster, for example by deleting the nginx deploy

    kubectl delete deploy nginx
    
so, no more pods running on the cluster

    kubectl get pods
    No resources found.

To restore the previous cluster state from the backup file, stop the etcd service, remove the current db content and restore from the backup

    systemctl stop etcd
    rm -rf /var/lib/etcd

    etcdctl --endpoints=http://10.10.10.80:2379 snapshot restore etcd-backup.db \
            --data-dir="/var/lib/etcd"  \
            --initial-advertise-peer-urls="http://10.10.10.80:2380" \
            --initial-cluster="kubem00=http://10.10.10.80:2380" \
            --initial-cluster-token="etcd-cluster-token"  \
            --name="kubem00"

Note that to restore data, we also need to specify all the parameters of the etcd service.

Now start the etcd service and restart also the kubernetes service to reconcilie the previous state

    systemctl start etcd
    systemctl restart kube-apiserver kube-controller-manager kube-scheduler
    
Check if everything is restored

    kubectl get pods
    NAME                     READY     STATUS    RESTARTS   AGE
    nginx-1423793266-0fh6d   1/1       Running   0          19m
    nginx-1423793266-4lxgp   1/1       Running   0          19m
    nginx-1423793266-q2nnw   1/1       Running   0          19m


### APIs Server failure
An APIs server failure breaks the cluster control plane preventings users and administrators to interact with it. For this reason, production envinronments should leverage on an high availability control plane.

However, a failure in the control plane does not prevents user applications to work. To check this, login to the master node and stop the APIs server

    systemctl stop kube-apiserver

Now it no more possible to access any resource in the cluster

    kubectl get all
    The connection to the server was refused - did you specify the right host or port?

However, our nginx pods are still serving

    curl http://kubew03:31000
    Welcome to nginx!

Restart the APIs server

    systemctl start kube-apiserver


### Scheduler failure
A Scheduler failure prevents the users to schedule new pods to the cluster. However already running pods are still serving. To check this, login to the master node and stop the scheduler

    systemctl stop kube-scheduler

Now try to scale up the nginx deploy

    kubectl scale deploy nginx --replicas=6
    deployment "nginx" scaled

    kubectl get pods
    NAME                     READY     STATUS    RESTARTS   AGE
    nginx-1423793266-0fh6d   1/1       Running   0          33m
    nginx-1423793266-4lxgp   1/1       Running   0          33m    
    nginx-1423793266-q2nnw   1/1       Running   0          33m
    nginx-1423793266-wjmjs   0/1       Pending   0          9s
    nginx-1423793266-14x09   0/1       Pending   0          9s
    nginx-1423793266-fbrvg   0/1       Pending   0          9s
    
We see new pods stucking in pending state since the scheduler is not available.

Restore the scheduler service and check the status of the pods

    kubectl get pods
    NAME                     READY     STATUS    RESTARTS   AGE
    nginx-1423793266-0fh6d   1/1       Running   0          35m
    nginx-1423793266-14x09   1/1       Running   0          2m
    nginx-1423793266-4lxgp   1/1       Running   0          35m
    nginx-1423793266-fbrvg   1/1       Running   0          2m
    nginx-1423793266-q2nnw   1/1       Running   0          35m
    nginx-1423793266-wjmjs   1/1       Running   0          2m


### Controller Manager failure
Primary task of the control manager is to reconcile the actual state of the system with the desired state. A failure of the controller prevents the cluster to update the actual state with changes requested by the users.

Login to the master node and stop the controller manager service

    systemctl stop kube-controller-manager
    
Now change the status of the cluster by deleting some running pods

    kubectl delete pod nginx-1423793266-0fh6d nginx-1423793266-14x09
    pod "nginx-1423793266-0fh6d" deleted
    pod "nginx-1423793266-14x09" deleted

In normal conditions, with the controller manager running, this trigger the recreation of two new pods to honour the replica set specified by the user. But the controller failure prevents it

    kubectl get pods
    NAME                     READY     STATUS    RESTARTS   AGE
    nginx-1423793266-fbrvg   1/1       Running   0          14m
    nginx-1423793266-ghk3t   1/1       Running   0          1m
    nginx-1423793266-q2nnw   1/1       Running   0          47m
    nginx-1423793266-wjmjs   1/1       Running   0          14m

Restore the controller manager and check it does its job correctly

    systemctl start kube-controller-manager
    
    kubectl get pods
    NAME                     READY     STATUS              RESTARTS   AGE
    nginx-1423793266-b10l0   0/1       ContainerCreating   0          1s
    nginx-1423793266-fbrvg   1/1       Running             0          15m
    nginx-1423793266-ghk3t   1/1       Running             0          2m
    nginx-1423793266-q2nnw   1/1       Running             0          48m
    nginx-1423793266-w87jh   0/1       ContainerCreating   0          1s
    nginx-1423793266-wjmjs   1/1       Running             0          15m



