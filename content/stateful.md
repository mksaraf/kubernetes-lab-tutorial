# Stateful Applications
Common controller as Replica Set and Daemon Set are a great way to run stateless applications on kubernetes, but their semantics are not so friendly for deploying stateful applications. A better approach for deploying stateful applications on a kubernetes cluster, is to use **Stateful Set**.

## Stateful Set
The purpose of Stateful Set is to provide a controller with the correct semantics for deploying stateful workloads. However, before move all in a converging storage and orchestration framework, one should consider with care to implement stateful applications in kubernetes.

A Stateful Set manages the deployment and scaling of a set of pods, and provides guarantees about the ordering and uniqueness of these pods. Like a Replica Set, a Stateful Set manages pods that are based on an identical container specifications. Unlike Replica Set, a Stateful Set maintains a sticky identity for each of pod across any rescheduling.

In the example below, the ``apache-sts.yaml`` configuration file define a simple Stateful Set for an apache application made of two replicas

```yaml
---
apiVersion: apps/v1beta2
kind: StatefulSet
metadata:
  name: apache
  namespace:
  labels:
    type: statefulset
spec:
  podManagementPolicy: OrderedReady
  serviceName: web
  replicas: 2
  selector:
    matchLabels:
      app: apache
  template:
    metadata:
      labels:
        app: apache
    spec:
      containers:
      - name: apache
        image: centos/httpd:latest
        ports:
        - containerPort: 80
          name: web
```

Create the stateful set and check the pod creation giving attention to the name of the pods and the order of creation

    kubectl create -f _apache-sts.yaml
    statefulset "apache" created

    kubectl get sts
    NAME      DESIRED   CURRENT   AGE
    apache    2         2         51s
    
    kubectl get pods -o wide
    NAME            READY     STATUS    RESTARTS   AGE       IP           NODE
    apache-0        1/1       Running   0          1m        10.38.3.79   kubew03
    apache-1        1/1       Running   0          58s       10.38.5.86   kubew05

For a Stateful Set with n replicas, when pods are deployed, they are created sequentially, in order from {0..n-1} with a sticky, unique identity in the form ``<statefulset name>-<ordinal index>``. The (i)th pod is not created until the (i-1)th is running. This ensure a predictable order of pod creation. Deletion of pods in stateful set follows the inverse order from {n-1..0}. However, if the order of pod creation is not strictly required, it is possible to creat pods in parallel by setting the ``podManagementPolicy: Parallel`` option.

A Stateful Set can be scaled up and down ensuring the same order of creation and deletion

    kubectl scale sts apache --replicas=3

    kubectl get pods -o wide
    NAME            READY     STATUS    RESTARTS   AGE       IP           NODE
    apache-0        1/1       Running   0          6m        10.38.3.79   kubew03
    apache-1        1/1       Running   0          5m        10.38.5.86   kubew05
    apache-2        1/1       Running   0          4m        10.38.3.80   kubew03

A stateful set requires an headless service to control the domain of its pods. Here the headless service ``apache-headless-sts.yaml`` configuration file for the example above
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: web
  labels:
    app: apache
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: apache
```

The domain managed by this service takes the form ``$(service name).$(namespace).svc.cluster.local``. 

Create the service and check the pods domain name

    kubectl create -f apache-headless-sts.yaml
    service "web" created
    
    kubectl get svc
    NAME                                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   
    web                                     ClusterIP   None            <none>        80/TCP

    for i in $(seq -w 0 2); do kubectl exec apache-$i -- sh -c 'hostname -f'; done
    apache-0.web.project.svc.cluster.local
    apache-1.web.project.svc.cluster.local
    apache-2.web.project.svc.cluster.local

As each pod is created, it gets a matching service name, taking the form ``$(podname).$(service)``, where the service is defined by the service name field on the Stateful Set. This leads to a predictable service name surviving to pod deletions and restarts.

Start a busybox shell and check the service resolution

    kubectl exec -it busybox -- sh -c 'nslookup apache-0.web'
    Server:    10.32.0.10
    Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local
    Name:      apache-0.web
    Address 1: 10.38.5.87

    kubectl exec -it busybox -- sh -c 'nslookup apache-1.web'
    Server:    10.32.0.10
    Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local
    Name:      apache-1.web
    Address 1: 10.38.3.81

    kubectl exec -it busybox -- sh -c 'nslookup apache-2.web'
    Server:    10.32.0.10
    Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local
    Name:      apache-2.web
    Address 1: 10.38.3.82

The example above does not provide storage persistence across pod deletions and restarts. To achieve persistance of data, as required in a stateful application, the Stateful Set leverages on the Persistant Volume Claim model on a shared storage environment. Here the ``apache-sts-pvc.yaml`` configuration file adding data persistance to the example above

```yaml
---
apiVersion: apps/v1beta2
kind: StatefulSet
metadata:
  name: apache
  namespace:
  labels:
    type: statefulset
spec:
  serviceName: web
  replicas: 3
  selector:
    matchLabels:
      app: apache
  template:
    metadata:
      labels:
        app: apache
    spec:
      containers:
      - name: apache
        image: centos/httpd:latest
        ports:
        - containerPort: 80
          name: web
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
      storageClassName: default
```

The file assumes a default storage class already set and configured.

Delete the previous instance of stateful set and create the new one

    kubectl delete -f apache-sts.yaml
    kubectl create -f apache-sts-pvc.yaml

Each pod in the stateful set will claim for a volume where to store its persistent data.

    kubectl get pods -o wide
    NAME            READY     STATUS    RESTARTS   AGE       IP           NODE
    apache-0        1/1       Running   0          5m        10.38.3.83   kubew03
    apache-1        1/1       Running   0          4m        10.38.5.88   kubew05
    apache-2        1/1       Running   0          4m        10.38.3.84   kubew03

    kubectl get pvc
    NAME                  STATUS    VOLUME          CAPACITY   ACCESS MODES   STORAGECLASS 
    www-apache-0          Bound     pvc-1789513b2   2Gi        RWO            default  
    www-apache-1          Bound     pvc-306a1f362   2Gi        RWO            default 
    www-apache-2          Bound     pvc-484a031f2   2Gi        RWO            default 

For each pod, write the index.html file and check that the pod serves its own page

    for i in $(seq -w 0 2); \
      do \
        kubectl exec apache-$i -- sh -c 'echo Welcome from $(hostname) > /var/www/html/index.html'; \
      done

    for i in $(seq -w 0 2); do kubectl exec -it apache-$i -- curl localhost; done
    Welcome from apache-0
    Welcome from apache-1
    Welcome from apache-2

The example above can be scaled up and down preserving the identity of each pod along with their persistant data.

## Deploy a Consul cluster
HashiCorp Consul is a distributed key-value store with service discovery. Consul is based on the Raft alghoritm for distributed consensus. Details about Consul and how to configure and use it can be found on the product documentation.

The most difficult part to run a Consul cluster on Kubernetes is how to form a cluster having Consul strict requirements about instance names of nodes being part of it. In this section we are going to deploy a three node Consul cluster by using the stateful set controller.

### Prerequisites
We assume a persistent shared storage environment is available to the kubernetes cluster. This is because each Consul node uses a data directory where to store the status of the cluster and this directory needs to be preserved across pod deletions and restarts. A default storage class needs to be created before to try to implement this example.

### Configuration files
Configuration files for this example are available [here](https://github.com/kalise/consul-sts).

Clone the repo

    git clone https://github.com/kalise/consul-sts
    cd consul-sts

### Bootstrap the cluster
First define a headless service for the Stateful Set as in the ``consul-svc.yaml`` configuration file
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: consul
  labels:
    app: consul
spec:
  ports:
  - name: rpc
    port: 8300
    targetPort: 8300
  - name: lan
    port: 8301
    targetPort: 8301
  - name: wan
    port: 8302
    targetPort: 8302
  - name: http
    port: 8500
    targetPort: 8500
  - name: dns
    targetPort: 8600
    port: 8600
  clusterIP: None
  selector:
    app: consul
```

Then define a Stateful Set for the Consul cluster as in the ``consul-sts.yaml`` configuration file
```yaml
---
apiVersion: apps/v1beta2
kind: StatefulSet
metadata:
  name: consul
  namespace:
  labels:
    type: statefulset
spec:
  serviceName: consul
  replicas: 3
  selector:
    matchLabels:
      app: consul
  template:
    metadata:
      labels:
        app: consul
    spec:
      containers:
      - name: consul
        image: consul:latest
        env:
          - name: POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
        ports:
        - name: rpc
          containerPort: 8300
        - name: lan
          containerPort: 8301
        - name: wan
          containerPort: 8302
        - name: http
          containerPort: 8500
        - name: dns
          containerPort: 8600
        volumeMounts:
        - name: consuldata
          mountPath: /consul/data
        - name: configdata
          mountPath: /consul/config
        args:
        - agent
        - -server
        - -datacenter=kubernetes
        - -data-dir=/consul/data
        - -log-level=trace
        - -config-file=/consul/config/consul.json
        - -client=0.0.0.0
        - -advertise=$(POD_IP)
        - -advertise-wan=127.0.0.1
        - -serf-wan-bind=127.0.0.1
        - -bootstrap-expect=3
        - -retry-join=consul-0.consul.$(POD_NAMESPACE).svc.cluster.local
        - -retry-join=consul-1.consul.$(POD_NAMESPACE).svc.cluster.local
        - -retry-join=consul-2.consul.$(POD_NAMESPACE).svc.cluster.local
        - -domain=cluster.local
        - -ui
      volumes:
        - name: configdata
          configMap:
            name: consulconfigdata
  volumeClaimTemplates:
  - metadata:
      name: consuldata
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
      storageClassName: default
```

Create the headless service

    kubectl create -f consul-svc.yaml

    kubectl get svc -o wide
    NAME    TYPE       CLUSTER-IP EXTERNAL-IP PORT(S)                                        AGE  SELECTOR
    consul  ClusterIP  None       <none>      8300/TCP,8301/TCP,8302/TCP,8500/TCP,8600/TCP   25s  app=consul

The presence of headless service, ensure node discovery for the Consul cluster.

Create a Config Map for Consul configuration file

    kubectl create configmap consulconfigdata --from-file=consul.json
    
Create a Stateful Set of three nodes

    kubectl create -f consul-sts.yaml

The Consul pods will be created in a strict order with a predictable name

    kubectl get pods -o wide
    NAME            READY     STATUS    RESTARTS   AGE       IP           NODE
    consul-0        1/1       Running   0          7m        10.38.5.95   kubew05
    consul-1        1/1       Running   0          6m        10.38.3.88   kubew03
    consul-2        1/1       Running   0          5m        10.38.5.96   kubew05

Each pod creates its own volume where to store its data

    kubectl get pvc
    NAME                  STATUS    VOLUME         CAPACITY   ACCESS MODES   STORAGECLASS 
    consuldata-consul-0   Bound     pvc-7bf6c16e   2Gi        RWO            default 
    consuldata-consul-1   Bound     pvc-951e3b17   2Gi        RWO            default
    consuldata-consul-2   Bound     pvc-adfbf7ce   2Gi        RWO            default
    
Consul cluster should be formed

    kubectl exec -it consul-0 -- consul members
    Node      Address          Status  Type    Build  Protocol  DC          Segment
    consul-0  10.38.5.95:8301  alive   server  0.9.3  2         kubernetes  <all>
    consul-1  10.38.3.88:8301  alive   server  0.9.3  2         kubernetes  <all>
    consul-2  10.38.5.96:8301  alive   server  0.9.3  2         kubernetes  <all>

and ready to be used by any other pod in the kubernetes cluster.

Also each pod creates its own storage volume where to store its own copy of the distributed database

    kubectl get pvc
    NAME                  STATUS    VOLUME         CAPACITY   ACCESS MODES   STORAGECLASS   AGE
    consuldata-consul-0   Bound     pvc-e975189c   2Gi        RWO            default        1h
    consuldata-consul-1   Bound     pvc-02461605   2Gi        RWO            default        1h
    consuldata-consul-2   Bound     pvc-1ac2d8d5   2Gi        RWO            default        1h

### Access the cluster from pods
Create a simple curl shell in a pod from the ``curl.yaml`` file
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: curl
  namespace:
spec:
  containers:
  - image: kalise/curl:latest
    command:
      - sleep
      - "3600"
    name: curl
  restartPolicy: Always
```

Attach to the curl shell, create and retrieve a key/value pair in the Consul cluster

    kubectl exec -it curl sh
    / # curl --request PUT --data my-data http://consul:8500/v1/kv/my-key
    true
    / # curl --request GET http://consul:8500/v1/kv/my-key
    [{"LockIndex":0,"Key":"my-key","Flags":0,"Value":"bXktZGF0YQ==","CreateIndex":336,"ModifyIndex":349}]
    / # exit

### Expose the cluster
Consul provides a simple HTTP graphical interface on port 8500 for interact with it. To expose this interface to the external of the kubernetes cluster, define an service as in the ``consul-svc-ext.yaml`` configuration file
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: consul-ext
  labels:
    app: consul
spec:
  type: ClusterIP
  ports:
  - name: ui
    port: 8500
    targetPort: 8500
  selector:
    app: consul
```

Assuming we have an Ingress Controller in place, define the ingress as in the ``consul-ingress.yaml`` configuration file
```yaml
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: consul
spec:
  rules:
  - host: consul.cloud.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: consul-ext
          servicePort: 8500
```

Create the service and expose it

    kubectl create -f consul-svc-ext.yaml
    kubectl create -f consul-ingress.yaml

Point the browser to the http://consul.cloud.example.com/ui to access the GUI.

### Cleanup everything
Remove every object create in the previous steps

    kubectl delete -f consul-ingress.yaml
    kubectl delete -f consul-svc-ext.yaml
    kubectl delete -f consul-sts.yaml
    kubectl delete -f consul-svc.yaml
    kubectl delete pvc consuldata-consul-0 consuldata-consul-1 consuldata-consul-2
    kubectl delete configmap consulconfigdata
