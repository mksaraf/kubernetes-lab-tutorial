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


### Cluster Backup
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

Now start the etcd service and restart also the kubernetes service to reconcile the previous state

    systemctl start etcd
    systemctl restart kube-apiserver kube-controller-manager kube-scheduler
    
Check if everithing is restored

    kubectl get pods
    NAME                     READY     STATUS    RESTARTS   AGE
    nginx-1423793266-0fh6d   1/1       Running   0          19m
    nginx-1423793266-4lxgp   1/1       Running   0          19m
    nginx-1423793266-q2nnw   1/1       Running   0          19m







