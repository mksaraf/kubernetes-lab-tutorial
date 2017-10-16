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
        - ReadWriteMany
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
    www-apache-0          Bound     pvc-1789513b2   2Gi        RWX            default  
    www-apache-1          Bound     pvc-306a1f362   2Gi        RWX            default 
    www-apache-2          Bound     pvc-484a031f2   2Gi        RWX            default 

For each pod, write the index.html file and check that the pod serves its own page

    for i in $(seq -w 0 2); \
      do \
        kubectl exec apache-$i -- sh -c 'echo Welcome from $(hostname) > /var/www/html/index.html'; \
      done

    for i in $(seq -w 0 2); do kubectl exec -it apache-$i -- curl localhost; done
    Welcome from apache-0
    Welcome from apache-1
    Welcome from apache-2


