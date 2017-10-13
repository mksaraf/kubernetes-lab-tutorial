# Multitenancy
In this section we are going to cover additional concepts related to the sharing of a kubernetes cluster across multiple teams, projects and users.

   * [Namespaces](#namespaces)
   * [Quotas and Limits](#quotas-and-limits)

## Namespaces
Kubernetes supports multiple virtual clusters backed by the same physical cluster. These virtual clusters are called namespaces. Within the same namespace, kubernetes objects name should be unique. Different objects in different namespaces may have the same name.

Kubernetes comes with two initial namespaces

  * **default**: the default namespace for objects with no other namespace
  * **kube-system** the namespace for objects created by the kubernetes system

To get namespaces

    kubectl get namespaces
    NAME          STATUS    AGE
    default       Active    7d
    kube-system   Active    7d


To see objects belonging to a specific namespace

    kubectl get all --namespace default

    NAME           DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
    deploy/nginx   2         2         2            2           52s
    NAME             CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
    svc/kubernetes   10.254.0.1     <none>        443/TCP          7d
    svc/nginx        10.254.33.40   <nodes>       8081:31000/TCP   51s
    NAME                  DESIRED   CURRENT   READY     AGE
    rs/nginx-2480045907   2         2         2         52s
    NAME                        READY     STATUS    RESTARTS   AGE
    po/nginx-2480045907-56t21   1/1       Running   0          52s
    po/nginx-2480045907-8n2t5   1/1       Running   0          52s

or objects belonging to all namespaces

    kubectl get service --all-namespaces
    NAMESPACE     NAME                   CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
    default       kubernetes             10.254.0.1       <none>        443/TCP          7d
    default       nginx                  10.254.33.40     <nodes>       8081:31000/TCP   2m
    kube-system   kube-dns               10.254.3.100     <none>        53/UDP,53/TCP    3d
    kube-system   kubernetes-dashboard   10.254.180.188   <none>        80/TCP           1d

Please, note that not all kubernetes objects are in namespaces, i.e. nodes, are cluster resources not included in any namespaces.

Define a new project namespace from the ``projectone-ns.yaml`` configuration file
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: projectone
```

Create the new namespace

    kubectl create -f projectone-ns.yaml
    namespace "projectone" created

    kubectl get ns project-one
    NAME          STATUS    AGE
    projectone   Active    6s

Objects can be assigned to a specific namespace in an explicit way, by setting the namespace in the metadata. For example, to create a nginx pod inside the project-one namespace, force the namespace in the pod definition file
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: projectone
  labels:
    run: nginx
spec:
  containers:
  - name: mynginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

Create the nginx pod and check it lives only in the project-one namespace

    kubectl create -f nginx-pod.yaml
    pod "nginx" created

    kubectl get pod nginx -n projectone
    NAME      READY     STATUS    RESTARTS   AGE
    nginx     1/1       Running   0          51s

    kubectl get pod nginx
    Error from server (NotFound): pods "nginx" not found

Deleteing a namespace, will delete all the objects living in that namespaces. For example

    kubectl delete ns projectone
    namespace "projectone" deleted

    kubectl get pod  --all-namespaces

Another way to create object in namespaces is to force the desired namespace into the contest of *kubectl* command line. The kubectl is the client interface to interact with a kubernetes cluster. The contest of kubectl is specified into the ``~.kube/conf`` kubeconfig file. The contest defines the namespace as well as the cluster and the user accessing the resources.

See the kubeconfig file use the ``kubectl config view`` command

```yaml
  apiVersion: v1
    clusters:
    - cluster:
        server: http://kube00:8080
      name: musa-cluster
    contexts:
    - context:
        cluster: musa-cluster
        namespace: default
        user: admin
      name: default-context
    current-context: default-context
    kind: Config
    preferences: {}
    users:
    - name: admin
      user: {}    
```   
    
The file above defines a default-context operating on the musa-cluster as admin user. All objects created in this contest will be in the default namespace unless specified. We can add more contexts to use different namespaces and switch between contexts.

Create a new contest using the projectone namespace we defined above

    kubectl config set-credentials admin
    kubectl config set-cluster musa-cluster --server=http://kube00:8080
    kubectl config set-context projectone/musa-cluster/admin --cluster=musa-cluster --user=admin
    kubectl config set contexts.projectone/musa-cluster/admin.namespace projectone

The kubeconfig file now looks like
```yaml
apiVersion: v1
clusters:
- cluster:
    server: http://kube00:8080
  name: musa-cluster
contexts:
- context:
    cluster: musa-cluster
    namespace: default
    user: admin
  name: default-context
- context:
    cluster: musa-cluster
    namespace: projectone
    user: admin
  name: projectone/musa-cluster/admin
current-context: default-context
kind: Config
preferences: {}
users:
- name: admin
  user: {}
```

It is not strictly required but it is a convention to use the name of contests as ``<namespace>/<cluster>/<user>`` combination. To switch contest use

    kubectl config use-context projectone/musa-cluster/admin
    Switched to context "projectone/musa-cluster/admin".

    kubectl config current-context
    projectone/musa-cluster/admin

Starting from this point, all objects will be created in the projectone namespace.

Switch back to default context

    kubectl config use-context default-context
    Switched to context "default-context".

## Quotas and Limits
Namespaces let different users or teams to share a cluster with a fixed number of nodes. It can be a concern that one team could use more than its fair share of resources. Resource quotas are the tool to address this concern. 

A resource quota provides constraints that limit aggregate resource consumption per namespace. It can limit the quantity of objects that can be created in a namespace by type, as well as the total amount of compute resources that may be consumed in that project.

Users create resources in the namespace, and the quota system tracks usage to ensure it does not exceed hard resource limits defined in the resource quota. If creating or updating a resource violates a quota constraint, the request will fail. When quota is enabled in a namespace for compute resources like cpu and memory, users must specify resources consumption, otherwise the quota system rejects pod creation.

Define a resource quota ``quota.yaml`` configuration file to assign constraints to current namespace
```yaml
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: project-quota
spec:
  hard:
    limits.memory: 1Gi
    limits.cpu: 1
    pods: 10
```

Create quota and check the current namespace

    kubectl config current-context
    projectone/musa-cluster/admin

    kubectl create -f quota.yaml
    resourcequota "project-quota" created

    kubectl describe ns projectone
    Name:   projectone
    Labels: type=project
    Status: Active

    Resource Quotas
     Name:          project-quota
     Resource       Used    Hard
     --------       ---     ---
     limits.cpu     0       1
     limits.memory  0       1Gi
     pods           0       10

    No resource limits.

Current namespace has now hard constraints set to 1 core CPU, 1 GB of RAM and max 10 running pods. Having set constraints for the namespace, all further requests for pod creation inside that namespace, must specify resources consumption, otherwise the quota system will reject the pod creation. 

Trying to create a nginx pod

    kubectl create -f nginx-pod.yaml
    Error from server (Forbidden) ..

The reason is that, by default, a pod try to allocate all the CPU and memory available in the system. Since we have limited cpu and memory consumption for the namespaces, the quota system cannot honorate a request for pod creation crossing these limits.

We can specify the resource contraint for a pod in its configuration file or in the ``nginx-deploy-limited.yaml`` configuration file
```yaml
...
    spec:
      containers:
      - image: nginx:latest
        resources:
          limits:
            cpu: 200m
            memory: 512Mi
        name: nginx
        ports:
        - containerPort: 80
          protocol: TCP
...
```

and deploy the pod

    kubectl create -f nginx-deploy-limited.yaml
    deployment "nginx" created

    kubectl get pods
    NAME                     READY     STATUS    RESTARTS   AGE
    nginx-3094295584-rsxns   1/1       Running   0          1m

The above pod can take up to 200 millicore of CPU, i.e. the 20% of total CPU resource quota of the namespace; it also can take up to 512 MB of memory, i.e. 50% of total memory resource quota.

So we can scale to 2 pod replicas

    kubectl scale deploy/nginx --replicas=2
    deployment "nginx" scaled

    kubectl get pods
    NAME                     READY     STATUS              RESTARTS   AGE
    nginx-3094295584-bxkln   0/1       ContainerCreating   0          3s
    nginx-3094295584-rsxns   1/1       Running             0          3m

At this point, we consumed all memory quotas we reserved for the namespace. Trying to scale further

    kubectl scale deploy/nginx --replicas=3
    deployment "nginx" scaled

    kubectl get pods
    NAME                     READY     STATUS    RESTARTS   AGE
    nginx-3094295584-bxkln   1/1       Running   0          2m
    nginx-3094295584-rsxns   1/1       Running   0          6m

    kubectl get all
    NAME           DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
    deploy/nginx   3         2         2            2           6m
    NAME                  DESIRED   CURRENT   READY     AGE
    rs/nginx-3094295584   3         2         2         6m
    NAME                        READY     STATUS    RESTARTS   AGE
    po/nginx-3094295584-bxkln   1/1       Running   0          3m
    po/nginx-3094295584-rsxns   1/1       Running   0          6m

we cannot get more than 2 containers running.

Quotas lets the cluster administrators to control the resource consumption within a shared cluster. However, a single namespace may be used by more than a single user and it may deploy more than an application. To avoid a single pod consumes all resource of a given namespace, kubernetes introduces the limit range object. The limit range object limits the resources that a pod can consume by specifying the minimum, maximum and default resource consumption.

The configuration file ``limitranges.yaml`` defines limits for all containers running in the current namespace
```yaml
---
kind: LimitRange
apiVersion: v1
metadata:
  name: container-limit-ranges
spec:
  limits:
  - type: Container
    max:
      cpu: 200m
      memory: 512Mi
    min:
      cpu:
      memory:
    default:
      cpu: 100m
      memory: 256Mi
```

Create the limit ranges object and inspect the namespace

    kubectl create -f limitranges.yaml
    limitrange "container-limit-ranges" created

    kubectl describe namespace projectone
    Name:   projectone
    Labels: type=project
    Status: Active

    Resource Quotas
     Name:          project-quota
     Resource       Used    Hard
     --------       ---     ---
     limits.cpu     0       1
     limits.memory  0       1Gi
     pods           0       10

    Resource Limits
     Type           Resource        Min     Max     Default Request Default Limit   Max Limit/Request Ratio
     ----           --------        ---     ---     --------------- -------------   -----------------------
     Container      memory          0       512Mi   256Mi           256Mi           -
     Container      cpu             0       200m    100m            100m            -

The current namespace defines limits for each container running in the namespace. If an user tryes to create a pod with a resource consumption more than limits range, the kubernetes scheduler will deny the request even if within the quota set.

Try to create a nginx pod as
```yaml
...
  containers:
  - name: nginx
    image: nginx:latest
    resources:
      limits:
        cpu: 250m
        memory: 512Mi
    ports:
    - containerPort: 80
...
```

our request will be denied

    kubectl create -f nginx-limited-pod.yaml
    Error from server (Forbidden): error when creating "nginx-limited-pod.yaml":
    pods "nginx" is forbidden: maximum cpu usage per Container is 200m, but limit is 250m.

The default value we set into limit range definition above is used as default for all pods that do not specify resource consumption. So, if we create a nginx pod as follow
```yaml
...
  containers:
  - name: nginx
    image: nginx:latest
    resources:
    ports:
    - containerPort: 80
...
```

the pod will be created with the default resource consumption limits

    kubectl create -f nginx-limited-pod.yaml
    pod "nginx" created

    kubectl describe namespace projectone
    Name:   projectone
    Labels: type=project
    Status: Active

    Resource Quotas
     Name:          project-quota
     Resource       Used    Hard
     --------       ---     ---
     limits.cpu     100m    1
     limits.memory  256Mi   1Gi
     pods           1       10

    Resource Limits
     Type           Resource        Min     Max     Default Request Default Limit   Max Limit/Request Ratio
     ----           --------        ---     ---     --------------- -------------   -----------------------
     Container      cpu             0       200m    100m            100m            -
     Container      memory          0       512Mi   256Mi           256Mi           -

Just to recap, quota defines the total amount of resources within a namespace, while limit ranges define the resource usage for a single pod within the same namespace.

Overcommitting of resource is possible, i.e. it is possible to specify limits exceding the real resources on the cluster nodes. To check real resources and their allocation, describe the worker nodes

    kubectl get nodes

    NAME      STATUS    AGE
    kuben05   Ready     6d
    kuben06   Ready     6d

    kubectl describe node kuben06
    ...
    ExternalID:             kuben06
    Non-terminated Pods:    (3 in total)
      Namespace             Name                    CPU Requests    CPU Limits      Memory Requests Memory Limits
      ---------             ----                    ------------    ----------      --------------- -------------
      default               nginx                   0 (0%)          0 (0%)          0 (0%)          0 (0%)
      default               nginx-2480045907-8n2t5  0 (0%)          0 (0%)          0 (0%)          0 (0%)
      projectone            nginx                   100m (10%)      100m (10%)      256Mi (13%)     256Mi (13%)
    Allocated resources:
      (Total limits may be over 100 percent, i.e., overcommitted.
      CPU Requests  CPU Limits      Memory Requests Memory Limits
      ------------  ----------      --------------- -------------
      100m (10%)    100m (10%)      256Mi (13%)     256Mi (13%)
      
