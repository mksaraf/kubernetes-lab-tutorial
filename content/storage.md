# Persistent Storage Model
Containers are ephemeral, meaning the container file system only lives as long as the container does. Volumes are simplest way to achieve data persistance. In kubernetes, a more flexible and powerful model is available.

This model is based on the following abstractions:

  * **PersistentVolume**: it models shared storage that has been provisioned by the cluster administrator. It is a resource in the cluster just like a node is a cluster resource. Persistent volumes are like standard volumes, but having a lifecycle independent of any individual pod. Also they hide to the users the details of the implementation of the storage, e.g. NFS, iSCSI, or other cloud storage systems.

  * **PersistentVolumeClaim**: it is a request for storage by a user. It is similar to a pod. Pods consume node resources and persistent volume claims consume persistent volume objects. As pods can request specific levels of resources like cpu and memory, volume claimes claims can request the access modes like read-write or read-only and stoarage capacity.

Kubernetes provides two different ways to provisioning storage:

  * **Manual Provisioning**: the cluster administrator has to manually make calls to the storage infrastructure to create persisten volumes and then users need to create volume claims to consume storage volumes.
  * **Dynamic Provisioning**: storage volumes are automatically created on-demand when users claim for storage avoiding the cluster administrator to pre-provision storage. 

In this section we're going to introduce this model by using simple examples. Please, refer to official documentation for more details.

  * [Local Persistent Volume](#local-persistent-volume)
  * [Volume Access Mode](#volume-access-mode)
  * [Volume Reclaim Policy](#volume-reclaim-policy)
  * [NFS Persistent Volume](#nfs-persistent-volume)

## Local Persistent Volume
Start by defining a persistent volume ``local-persistent-volume-recycle.yaml`` configuration file

```yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: local
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/data"
  persistentVolumeReclaimPolicy: Recycle
```

The configuration file specifies that the volume is at ``/data`` on the the cluster’s node. The volume type is ``hostPath`` meaning the volume is local to the host node. The configuration also specifies a size of 2GB and the access mode of ``ReadWriteOnce``, meanings the volume can be mounted as read write by a single pod at time. The reclaim policy is ``Recycle`` meaning the volume can be used many times.  It defines the Storage Class name manual for the persisten volume, which will be used to bind a claim to this volume.

Create the persistent volume

    kubectl create -f local-persistent-volume-recycle.yaml
    
and view information about it 

    kubectl get pv
    NAME      CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS      CLAIM     STORAGECLASS   REASON    AGE
    local     2Gi        RWO           Recycle         Available             manual                   33m

Now, we're going to use the volume above by creating a claiming for persistent storage. Create the following ``volume-claim.yaml`` configuration file
```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: volume-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

Note the claim is for 500MB of space where the the volume is 2GB. The claim will bound any volume meeting the minimum requirements specified into the claim definition. 

Create the claim

    kubectl create -f volume-claim.yaml

Check the status of persistent volume to see if it is bound

    kubectl get pv
    NAME      CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS    CLAIM                  STORAGECLASS   REASON    AGE
    local     2Gi        RWO           Recycle         Bound     project/volume-claim   manual                   37m

Check the status of the claim

    kubectl get pvc
    NAME           STATUS    VOLUME    CAPACITY   ACCESSMODES   STORAGECLASS   AGE
    volume-claim   Bound     local     2Gi        RWO           manual         1m

Create a ``nginx-pod-pvc.yaml`` configuration file for a nginx pod using the above claim for its html content directory
```yaml
---
kind: Pod
apiVersion: v1
metadata:
  name: nginx
  namespace: default
  labels:
spec:

  containers:
    - name: nginx
      image: nginx:latest
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
      - mountPath: "/usr/share/nginx/html"
        name: html

  volumes:
    - name: html
      persistentVolumeClaim:
       claimName: volume-claim
```

Note that the pod configuration file specifies a persistent volume claim, but it does not specify a persistent volume. From the pod point of view, the claim is the volume. Please note that a claim must exist in the same namespace as the pod using the claim.

Create the nginx pod

    kubectl create -f nginx-pod-pvc.yaml

Accessing the nginx will return *403 Forbidden* since there are no html files to serve in the data volume

    kubectl get pod nginx -o yaml | grep IP
      hostIP: 10.10.10.86
      podIP: 172.30.5.2

    curl 172.30.5.2:80
    403 Forbidden

Let's login to the worker node and populate the data volume

    echo "Welcome to $(hostname)" > /data/index.html

Now try again to access the nginx application

     curl 172.30.5.2:80
     Welcome to kubew05

To test the persistence of the volume and related claim, delete the pod and recreate it

    kubectl delete pod nginx
    pod "nginx" deleted

    kubectl create -f nginx-pod-pvc.yaml
    pod "nginx" created

Locate the IP of the new nginx pod and try to access it

    kubectl get pod nginx -o yaml | grep podIP
      podIP: 172.30.5.2

    curl 172.30.5.2
    Welcome to kubew05

## Volume Access Mode
A persistent volume can be mounted on a host in any way supported by the resource provider. Different storage providers have different capabilities and access modes are set to the specific modes supported by that particular volume. For example, NFS can support multiple read write clients, but an iSCSI volume can be support only one.

The access modes are:

  * **ReadWriteOnce**: the volume can be mounted as read-write by a single node
  * **ReadOnlyMany**: the volume can be mounted read-only by many nodes
  * **ReadWriteMany**: the volume can be mounted as read-write by many nodes

Claims and volumes use the same conventions when requesting storage with specific access modes. Pods use claims as volumes. For volumes which support multiple access modes, the user specifies which mode desired when using their claim as a volume in a pod.

A volume can only be mounted using one access mode at a time, even if it supports many. For example, a NFS volume can be mounted as ReadWriteOnce by a single node or ReadOnlyMany by many nodes, but not at the same time.

## Volume status
When a pod claims for a volume, the cluster inspects the claim to find the volume meeting claim requirements and mounts that volume for the pod. Once a pod has a claim and that claim is bound, the bound volume belongs to the pod.

A volume will be in one of the following status:

  * **Available**: a volume that is not yet bound to a claim
  * **Bound**: the volume is bound to a claim
  * **Released**: the claim has been deleted, but the volume is not yet available
  * **Failed**: the volume has failed 

The volume is considered released when the claim is deleted, but it is not yet available for another claim. Once the volume becomes available again then it can bound to another other claim. 

In our example, delete the volume claim

    kubectl delete pvc volume-claim

See the status of the volume

    kubectl get pv persistent-volume
    NAME      CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS      CLAIM     STORAGECLASS   REASON    AGE
    local     2Gi        RWO           Recycle         Available             manual                   57m

## Volume Reclaim Policy
When deleting a claim, the volume becomes available to other claims only when the volume claim policy is set to ``Recycle``. Volume claim policies currently supported are:

  * **Retain**: the content of the volume still exists when the volume is unbound and the volume is released
  * **Recycle**: the content of the volume is deleted when the volume is unbound and the volume is available
  * **Delete**: the content and the volume are deleted when the volume is unbound. 
  
*Please note that, currently, only NFS and HostPath support recycling.* 

When the policy is set to ``Retain`` the volume is released but it is not yet available for another claim because the previous claimant’s data are still on the volume.

Define a persistent volume ``local-persistent-volume-retain.yaml`` configuration file

```yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: local-retain
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/data"
  persistentVolumeReclaimPolicy: Retain
```

Create the persistent volume and the claim

    kubectl create -f local-persistent-volume-retain.yaml
    kubectl create -f volume-claim.yaml

Login to the pod using the claim and create some data on the volume

    kubectl exec -it nginx bash
    root@nginx:/# echo "Hello World" > /usr/share/nginx/html/index.html
    root@nginx:/# exit

Delete the claim

    kubectl delete pvc volume-claim

and check the status of the volume

    kubectl get pv
    NAME           CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS     CLAIM                  STORAGECLASS     AGE
    local-retain   2Gi        RWO           Retain          Released   project/volume-claim   manual           3m
    
We see the volume remain in the released status and not becomes available since the reclaim policy is set to ``Retain``. Now login to the worker node and check data are still there.

An administrator can manually reclaim the volume by deleteting the volume and creating a another one.

## NFS Persistent Volume
In this section we're going to use a NFS storage backend. Main limit of local stoorage backend for container volumes is that storage area is tied to the host where it resides. If kubernetes moves the pod from another host, the moved pod is no more to access the storage area since local storage is not shared between multiple hosts of the cluster. To achieve a more useful storage backend we need to leverage on a shared storage technology like NFS.

For this example, we'll assume a simple external NFS server ``fileserver``	sharing some folders. To make worker nodes able to consume these NFS shares, install the NFS client on all the worker nodes by ``yum install -y nfs-utils`` command.

Define a persistent volume as in the ``nfs-persistent-volume.yaml`` configuration file
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-volume
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  nfs:
    path: "/data"
    server: fileserver
  persistentVolumeReclaimPolicy: Recycle
```

Create the persistent volume

    kubectl create -f nfs-persistent-volume.yaml
    persistentvolume "nfs" created

    kubectl get pv nfs -o wide
    NAME        CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS      CLAIM     STORAGECLASS   REASON    AGE
    nfs-volume  1Gi        RWO           Recycle         Available             manual                   7s

Thanks to the persistent volume model, kubernetes hides the nature of storage and its complex setup to the applications. An user need only to claim volumes for their pods without deal with storage configuration and operations.

Create the claim

    kubectl create -f volume-claim.yaml

Check the bound 

    kubectl get pv
    NAME        CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS    CLAIM                  STORAGECLASS   REASON    AGE
    nfs-volume  1Gi        RWO           Recycle         Bound     project/volume-claim   manual                   5m

    kubectl get pvc
    NAME           STATUS    VOLUME      CAPACITY   ACCESSMODES   STORAGECLASS   AGE
    volume-claim   Bound     nfs-volume  1Gi        RWO           manual         9s

Now we are going to create more nginx pods using the same claim.

For example, create the ``nginx-pvc-template.yaml`` template for a nginx application having the html content folder placed on the shared storage 
```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  generation: 1
  labels:
    run: nginx
  name: nginx-pvc
spec:
  replicas: 3
  selector:
    matchLabels:
      run: nginx
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        run: nginx
    spec:
      containers:
      - image: nginx:latest
        imagePullPolicy: IfNotPresent
        name: nginx
        ports:
        - containerPort: 80
          protocol: TCP
          name: "http-server"
        volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: html
      volumes:
      - name: html
        persistentVolumeClaim:
          claimName: volume-claim
      dnsPolicy: ClusterFirst
      restartPolicy: Always
```

The template above defines a nginx application based on a nginx deploy of 3 replicas. The nginx application requires a shared volume for its html content. The application does not have to deal with complexity of setup and admin an NFS share.

Deploy the application

    kubectl create -f nginx-pvc-template.yaml
    
Check all pods are up and running

    kubectl get pods -o wide
    NAME                         READY     STATUS    RESTARTS   AGE       IP            NODE
    nginx-pvc-3474572923-3cxnf   1/1       Running   0          2m        10.38.5.89    kubew05
    nginx-pvc-3474572923-6cr28   1/1       Running   0          6s        10.38.3.140   kubew03
    nginx-pvc-3474572923-z17ls   1/1       Running   0          2m        10.38.5.90    kubew05

Login to one of these pods and create some html content

    kubectl exec -it nginx-pvc-3474572923-3cxnf bash
    root@nginx-pvc-3474572923-3cxnf:/# cd /usr/share/nginx/html                 
    root@nginx-pvc-3474572923-3cxnf:/usr/share/nginx/html# echo "Hello from NFS" > index.html
    root@nginx-pvc-3474572923-3cxnf:/usr/share/nginx/html# exit

Since all three pods mount the same shared folder on the NFS, the just created html content is placed on the NFS share and it is accessible from any of the three pods

    curl 10.38.5.89    
    Hello from NFS
    
    curl 10.38.5.90
    Hello from NFS
    
    curl 10.38.3.140
    Hello from NFS

## Storage Classes
A volume can uses a storage class specified into its definition file. If the storage class is not specified, the volume has no class and can only be bound to claims that do not request any class. A claim can request a particular class by specifying the name of a storage class in its definition file. Only volumes of the requested class can be bound to the claim requesting that class.

Multiple storage classes can be defined each specifying a volume provisioner to use when creating a volume of that class. This allows the cluster administrator to define multiple type of storage within a cluster, each with a custom set of parameters.

Storage classes have to specify a provisioner that determines what volume plugin is used for provisioning the volume.

