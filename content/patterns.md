# Applications Design Patterns
With the adoption of microservices and containers in the recent years, the way we design, develop and run software applications has changed significantly. Modern software applications are optimised for scalability, elasticity, failure, and speed of change. Driven by these new principles, modern applications require a different set of patterns and practices to be applied in an effective way.

In this section, we're going to analyse these new principles with the aim to give a set of guidelines for the design of modern software applications on Kuberentes.

Design patterns are grouped into several categories:

1. [Foundational Patterns](#foundational-patterns): basic principles for cloud native applications.
2. [Behavorial Patterns](#behavorial-patterns): define various types of containers.
3. [Structural Patterns](#structural-patterns): organize interactions between containers.
4. [Configuration Patterns](#configuration-patterns): handle configurations in containers.

However, the same pattern may have multiple implications and fall into multiple categories. Also patterns are often interconnected, as we will see in the following sections.

## Foundational Patterns
Foundational patterns refer to the basic principles for building cloud native applications in Kubernetes. In this section, we're going to cover:

* [Distributed Primitives](#distributed-primitives)
* [Predictable Demands](#predictable-demands)
* [Dynamic Placement](#dynamic-placement)
* [Declarative Deployment](#declarative-deployment)
* [Observable Interior](#observable-interior)
* [Life Cycle Conformance](#life-cycle-conformance)

### Distributed Primitives
Kubernetes adds a new mindset to the software application design by offering a new set of primitives for creating distributed systems spreading across multiple nodes. Having these new primitives, we add a new set of tools to implements software applications, in addition to the already well known tools offered by programming languages and runtimes.

#### Containers
Containers are building blocks for applications running in Kubernetes. From the technical point of view, a container provides
packaging and isolation. However, in the context of a distributed application, the container can be described as:

 * It addresses a single concern.
 * It is has its own release cycle.
 * It is self contained, defines and carries its own build time dependencies.
 * It is immutable and once it is built, it does not change.
 * It has a well defined set of APIs to expose its functionality.
 * It runs as a single well behaved process.
 * It is safe to scale up or down at any moment.
 * It is parameterised and created for reuse.
 * It is paremetrized for the different environments.
 * It is parameterised for the different use cases.

Having small and modular reusable containers leads us to create a set of standard tools, similarly to a good reusable library provided by a programming language or runtime.

Containers are designed to run only a single process per container, unless the process itself spawns child processes. Running multiple unrelated processes in a single container, leads to keep all those processes up and running, manage their logs, their interactions, and their healtiness. For example, we have to include a mechanism for automatically restarting individual processes if they crash. Also, all those processes would log to the same standard output, so we'll have hard time figuring out which process logged what.

#### Pods
In Kubernetes, a group of one or more containers is called pod. Containers in a pod are deployed together, and are started, stopped, and replicated as a group. When a pod contains multiple containers, all of them are always run on a single node, it never spans multiple nodes.

The simplest pod definition describes the deployment of a single container as in the following configuration file  

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace:
  labels:
    run: nginx
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

All containers inside the same pod can share the same set of resources, e.g. network and process namespaces. This allows the containers in a pod to interact each other through networking via localhost, or inter-process communication mechanisms, if desired. Kubernetes achieves this by configuring all containers in the same pod to use the same set of Linux namespaces, instead of each container having its own set. They can also share the same PID namespace, but that isn’t enabled by default.

On the other side, multiple containers in the same pod cannot share the file system because the container’s filesystem comes from the container image, and by default, it is fully isolated from other containers. However, multiple containers in the same pod can share some host file folders called volumes.

For example, the following file describes a pod with two containers using a shared volume to comminicate each other

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace:
  labels:
    run: nginx
spec:
  containers:
  - name: main
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
  - name: supporting
    image: busybox:latest
    volumeMounts:
    - name: html
      mountPath: /mnt
    command: ["/bin/sh", "-c"]
    args:
      - while true; do
          date >> /mnt/index.html;
          sleep 10;
        done
  volumes:
  - name: html
    emptyDir: {}
```

The first container running a ``nginx`` server, is called ``main`` and it is serving a static webpage created dynamically by a second container called ``supporting``. The main container has a shared volume called ``html`` mounted to the directory ``/usr/share/nginx/html``. The supporting container has the shared volume mounted to the directory ``/mnt``. Every ten seconds, the supporting container adds the current date and time into the ``index.html`` file, which is located in the shared volume. When the user makes an HTTP request to the pod, the nginx server reads this file and transfers it back to the user in response to the request.

All containers in a pod are being started in parallel and there is no way to define that one container must be started after other container. To deal with dependencies and startup order, Kubernetes introduces the Init Containers, which start first and sequentially, before the main and the other supporting containers in the same pod.

For example, the following file describe a pod with one main container and an init container using a shared volume to comminicate each other

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace:
  labels:
spec:
  initContainers:
  - name: prepare-html
    image: busybox:latest
    command: ["/bin/sh", "-c", "echo 'Hello World from '$POD_IP'!' > /tmp/index.html"]  
    env:
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    volumeMounts:
    - name: content-data
      mountPath: /tmp
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: content-data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: content-data
    emptyDir: {}
```

The main requirement of the pod above is to reply to user requests with a greeting message containing the IP address of the pod. Because the IP address of a pod is only known after the pod started, we need to get the IP before the main container. This is the sequence of events happening here:

1. The pod is created and it is scheduled on a given node.
2. The IP address of the pod is assigned.
3. The init container starts and gets the IP address from the APIs server.
4. The init container creates a simple html file containing the pod's IP and places it into the shared volume.
5. The init container exits
6. The main container starts, reads this file and transfers it back to the user in response to requests.

A pod may have any number of init containers. They are executed sequentially and only after the last one completes with success, then the main container and all the other supporting containers are started in parallel.

#### Services
In Kuberentes, pods are ephemeral, meaning they can die at any time for all sort of reasons suchs as scaling up and down, failing container health checks and node failures. A pod IP is known only after it is scheduled and started on a node. A pod can be rescheduled to a different node if the current node fails. All that means the pod IP may change over the life of an application and there is no way to control the assignment. Also horizontal scaling means multiple pods providing the same service with different IP addresses, having each of them its own.

For these reasons, there is a need for another primitive which defines a logical set of pods and how to access them 
through a single IP address and port. The service is another simple but powerful abstraction that binds the service name to an IP address and port number in a permanent way. A service represents a named entry point for a piece of functionality provided by the set of pods it is bound to.

The set of pods targeted by a Service is usually determined by a label selector. For example, the following file describes a service for a set of pods running nginx web servers

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace:
  labels:
spec:
  selector:
    run: nginx
  ports:
  - protocol: TCP
    port: 8000
    targetPort: 80
  type: ClusterIP
```

Once the service is created, all pods matching the label selector ``run=nginx`` will be bound to this service. By inspecting the service

    kubectl describe service nginx

    Name:                   nginx
    Namespace:              default
    Labels:                 None
    Selector:               run=nginx
    Type:                   ClusterIP
    IP:                     10.32.0.24
    Port:                   <unset> 8000/TCP
    Endpoints:              10.38.0.34:80,10.38.0.35:80,10.38.0.36:80
    Session Affinity:       None

we can see the service IP and port. These will be our static entrypoint for the ``nginx`` service provided by a set of pods running the nginx server.

The service endpoints are a set of ``<IP:PORT>`` pairs where the incoming requests to the service are redirected. We can see that the endpoints are the sockets provided by the pods bound to the service. The endpoints are dynamically updated whenever the set of pods in a service changes.

#### Labels
Labels are a system to organize objects into groups. Labels are key-value pairs that are attached to each object.
To add a label to a pod, add a labels section under metadata in the pod definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx
...
```

Labels are also used as selector for services and controllers.

#### Annotations
In addition to labels, pods and other objects can also contain annotations. Annotations are also key-value pairs, so they are similar to labels, but they can’t be used to group objects the way labels can. While objects can be selected through label selectors, it is not possible to do the same with an annotation selector.

On the other hand, annotations can hold much larger pieces of information than labels. Certain annotations are automatically added to objects by Kubernetes, but others can be added by users.

Here an example of pod with annotation
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  annotations:
    readme: "before to run this pod, make sure you have a service account defined."
  namespace:
  labels:
    run: nginx
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

#### Controllers
Controllers ensure that a specified number of pod replicas are running at any one time. In other words, a controller makes sure that a homogeneous set of pods are always up and running. If there are too many pods, it will kill some. If there are too few, it will start more. Unlike manually created pods, the pods maintained by a controller are automatically replaced if they fail, get deleted, or terminated.

There are different types of controllers:

  * **Replica Set**
  * **Daemon Set**
  * **Stateful Set**

and other might be defined in the future.

A Replica Set controller consists of:

 * The number of replicas desired
 * The pod definition
 * The selector to bind the managed pod

A selector is a label assigned to the pods that are managed by the replica set. Labels are included in the pod definition that the replica set instantiates. The replica set uses the selector to determine how many instances of the pod are already running in order to adjust as needed.

For example, the followin file defines a replica set with three replicas

```yaml
apiVersion: extensions/v1beta1
kind: ReplicaSet
metadata:
  labels:
  namespace:
  name: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      run: nginx
  template:
    metadata:
      labels:
        run: nginx
    spec:
      containers:
      - image: nginx:1.12
        name: nginx
        ports:
        - containerPort: 80
          protocol: TCP
```

#### Namespaces
Kubernetes supports multiple virtual clusters backed by the same physical cluster. These virtual clusters are called namespaces. Within the same namespace, kubernetes objects name should be unique. Different objects in different namespaces may have the same name.

Kubernetes comes with two initial namespaces

  * default: the default namespace for objects with no other namespace
  * kube-system: the namespace for objects created by the kubernetes system

Here an example of namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myproject
```

The cluster admin can create additional namespaces, for example, a namespace for each group of users. Another option is to create a namespace for each deployment environment, for example: development, staging, and production.

### Predictable Demands
A predictable resource requirements for container based applications is important to make intelligent decisions for placing containers on the cluster for most efficient utilization. In an environment with shared resources among large number of processes with different priorities, the only way for a successful placement is by knowing the demands of every process in advance.

#### Resources consumption
When creating a pod, we can specify the amount of CPU and memory that a container requests and a limit on what it may consume. 

For example, the following pod manifest specifies the CPU and memory requests for its single container.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: request-pod
  namespace:
  labels:
spec:
  containers:
  - image: busybox:latest
    command: ["dd", "if=/dev/zero", "of=/dev/null"]
    name: busybox
    resources:
      requests:
        cpu: 200m
```

By specifying resource requests, we specify the minimum amount of resources the pod needs. However the pod above can take more than the requested CPU and memory we requested, according to the capacity and the actual load of the working node.

Each node has a certain amount of CPU and memory it can allocate to pods. When scheduling a pod, the scheduler will only consider nodes with enough unallocated resources to meet the pod requirements. If the amount of unallocated CPU or memory is less than what the pod requests, the scheduler will not consider the node, because the node can’t provide the minimum amount
required by the pod.

Please, note that we're not specifying the maximum amount of resources the pod can consume. If we want to limit the usage of resources, we have to limit the pod as in the following descriptor file

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: limited-pod
  namespace:
  labels:
spec:
  containers:
  - image: busybox:latest
    command: ["dd", "if=/dev/zero", "of=/dev/null"]
    name: busybox
    resources:
      requests:
        cpu: 200m
      limits:
        cpu: 200m
```

Both resource requests and limits are specified for each container individually, not for the entire pod. The pod resource requests and limits are the sum of the requests and limits of all the containers contained into the pod. 

#### Quotas
By working in a shared multi tenant platform, the cluster admin can also configure boundaries and control units to prevent users consuming all the resources of the platform. A resource quota provides constraints that limit aggregate resource consumption per namespace.

For example, use the configuration file to assign constraints to current namespace
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: project-quota
spec:
  hard:
    limits.memory: 4Gi
    limits.cpu: 1
```

Users create pods in the namespace, and the quota system tracks usage to ensure it does not exceed the hard resource limit defined in the quota. If creating or updating a pod violates the assigned quota, then the request will fail.

Please, note that when quota is enabled in a namespace for compute resources like cpu and memory, users must specify resources consumption, otherwise the quota system rejects pod creation. The reason is that, by default, a pod try to allocate all the CPU and memory available in the system. Since we have limited cpu and memory consumption, the quota system cannot honorate a request for pod creation crossing these limits and request will fail.

#### Limits
A single namespace may be used by more pods at same time. To avoid a single pod consumes all resource of a given namespace, Kubernetes introduces the limit range concept. The limit range limits the resources that a pod can consume by specifying the minimum, maximum and default resource consumption.

The following file defines limits for all containers running in the current namespace
```yaml
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

When the current namespace defines limits and a user tryes to create a pod with a resource consumption more than that limits, the scheduler will deny the request to create the pod.

### Dynamic Placement
A reasonably sized microservices based application will consist of multiple containers. Containers, often, have dependencies among themselves, dependencies to the host, and resource requirements. The resources available on a cluster also can vary
over time. The way we place containers also impacts the availability, the performances, and the capacity of the distributed systems.

In Kubernetes, assigning pods to nodes is done by the scheduler. Generally, the users leave the scheduler to do its job without constraints. However, it might be required introduce a sort of forcing to the scheduler in order to achieve a better resource usage or meet some application's requirements.

#### Node Selectors
Node selector is the first ans simplest form of scheduler forcing. For example, having a pod that needs for **GPU** (Graphical Processor Unit) to perform its work, we can force the scheduler to use only GPU-equipped nodes to run this kind of pod. This is achieved by labeling all the node GPU-equipped with a proper label, e.g ``gpu=true``, and use this label as node selector in the pod definition

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu
  namespace:
  labels:
    run: nginx
spec:
  nodeSelector:
    gpu: true
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

#### Node Affinity
The node affinity is a generalization of the node selector approach with a more expressive and flexible semantics than the node selector technique. Node affinity allows us to specify rules as either required or preferred: required rules must be met for a pod to be scheduled to a node, whereas preferred rules only imply preference for the matching the node.

For example, the following pod descriptor defines a node affinity with a required rule

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-node-affinity
  namespace:
  labels:
    app: nginx
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: datacenter
            operator: In
            values:
            - milano-dc-1
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

The rule above force the scheduler to place the pod only on nodes having a label set to ``datacenter=milano-dc-1``. However the rule does only affects pod scheduling and never causes a pod to be evicted from a node if such label is removed from the node. This is because we used the ``requiredDuringSchedulingIgnoredDuringExecution`` instead of the ``requiredDuringSchedulingRequiredDuringExecution``. In the latter case, removing the label from the node, the pod gets evicted from the node.

The following example, is a pod descriptor which defines a node affinity with a preferred set of rules:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-node-affinity
  namespace:
  labels:
    app: nginx
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: hypervisor
            operator: In
            values:
            - esxi
      - weight: 2
        preference:
          matchExpressions:
          - key: hypervisor
            operator: In
            values:
            - kvm
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

The rule above defines a set of preferred rules based on the value of the ``hypervisor=esxi|kvm`` and setting a preference weight (higest is the preferred one).

#### Pods Affinity
The node affinity rules are used to force which node a pod is scheduled to. But these rules only affect the affinity between a pod and a node, whereas sometimes we need to specify the affinity between pods themselves. In this case, the pod affinity technique is required. Having a multi services application made of a frontend and a backend service, does make sense to have the frontend pods running on the same worker node where the backend pods are running.

For example, the following descriptor defines a required pod affinity rule

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: wordpress
  namespace:
spec:
  replicas: 1
  selector:
    matchLabels:
      run: blog
  template:
    metadata:
      labels:
        run: blog
    spec:
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                - key: run
                  operator: In
                  values:
                  - "mariadb"
              topologyKey: kubernetes.io/hostname
      containers:
      - image: bitnami/wordpress:latest
        name: wordpress
        ports:
        - containerPort: 80
          protocol: TCP
        - containerPort: 443
          protocol: TCP
        env:
        - name: MARIADB_HOST
          value: mariadb
        - name: MARIADB_PORT
          value: '3306'
```

It will create a wordpress pod having a hard requirement to be deployed on the same node ``kubernetes.io/hostname`` as a pod running the database backend.

#### Colocation
Another option provided by the affinity function is to force some pods to run in the same rack, zone, or region instead of the same node. Kubernetes nodes can be grouped into racks, zones and regions, then using proper labels and label selectors, it is possible to require pods running on the same rack, zone, or region.

For example, the following descriptor defines pods with hard requirement to be deployed in the same availability zone

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  labels:
  namespace:
  name: nginx
spec:
  replicas: 9
  selector:
    matchLabels:
      run: nginx
  template:
    metadata:
      labels:
        run: nginx
    spec:
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: run
                operator: In
                values:
                  - nginx
            topologyKey: failure-domain.beta.kubernetes.io/zone
      containers:
      - image: nginx:latest
        name: nginx
        ports:
        - containerPort: 80
          protocol: TCP
      restartPolicy: Always
```

The pod affinity rule above says pods are scheduled onto nodes in the same availability zone specified by ``failure-domain.beta.kubernetes.io/zone``. Please, note we are not specifying on which zone but we are only requiring pods to be colocated on the same zone.

The pod affinity rules can be combined with node affinity rules to have a more grained control on the pods placement. For example, we can combine the pods affinity above with a node affinity rule to have colocation of pods on a given zone.

#### Failure domains
We have seen how to tell the scheduler to colocate pods on the same node, rack, zone or regions. In other cases, we want to have some pods running away each other, for example for balancing load on different availability zones, defining the so called *failure domains*. A failure domain is a single node, rack, zone or region that can fail at same time. For example, each availability zone can be defined as a single failure domain because of network issues. In case of network issues, all nodes in the same zone might remain unreachable. For this reason we can require to distribute pod replicas in different failure domains, i.e. zones in our example.

This is achieved with the anti-affinity rules. The following descriptor requires pods replicas to be scheduled on separate availability zones

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  labels:
  namespace:
  name: nginx
spec:
  replicas: 4
  selector:
    matchLabels:
      run: nginx
  template:
    metadata:
      labels:
        run: nginx
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: run
                  operator: In
                  values:
                    - nginx
              topologyKey: failure-domain.beta.kubernetes.io/zone
      containers:
      - image: nginx:latest
        imagePullPolicy: Always
        name: nginx
        ports:
        - containerPort: 80
          protocol: TCP
      restartPolicy: Always
```

#### Taints and Tolerations
While affinity and anti-affinity allow pods to choose nodes and or other pods, taints and tolerations allow the nodes to control which pods should or should not be scheduled on them.

A taint is a property of the node that prevents pods to be scheduled on that node unless the pod has a toleration for the taint. For example, we can use taints to prevent production nodes to never run not-production pods:

    kubectl taint node kubew03 node-type=production:NoSchedule

This means that no pods will be able to schedule onto the node unless it has a matching toleration for that taint.

The following descriptor defines a pod with toleration for the taint above

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace:
  labels:
spec:
  tolerations:
  - key: node-type
    operator: Equal
    value: "production"
    effect: NoSchedule
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

To remove taint from the node

    kubectl taint node kubew03 node-type:NoSchedule-

Taints on a node defines three different effects:

  1. **NoSchedule**: pod will not be scheduled on the node unless it tolerates the taint.
  2. **PreferNoSchedule**: scheduler will try to avoid the pod placed onto the node, but pod will be placed ont the node if not possible to place it somewhere else.
  3. **NoExecute**: unlike the previous effects that only affect scheduling, this also affects pods already running on the node. Pods that are already running on the node and do not tolerate the taint will be evicted from the node and no other pods will be placed on the node unless they tolerate the taint.

### Declarative Deployment
### Observable Interior
### Life Cycle Conformance

## Behavorial Patterns
Behavorial Patterns define various type of container behaviour:

* [Batch Jobs](#batch-jobs)
* [Scheduled Jobs](#scheduled-jobs)
* [Daemon Services](#daemon-services)
* [Singleton Services](#singleton-services)
* [Self Awareness](#self-awareness)

### Batch Jobs
### Scheduled Jobs
### Daemon Services
### Singleton Services
### Self Awareness

## Structural Patterns
Structural Patterns refer to how organize containers interaction:

* [Sidecar](#sidecar)
* [Initialiser](#initialiser)
* [Ambassador](#ambassador)
* [Adapter](#adapter)

### Sidecar
### Initialiser
### Ambassador
### Adapter

## Configuration Patterns
Configuration Patterns refer to how handle configurations in containers:

* [Environment Variables](#environment-variables)
* [Configuration Resources](#configuration-resources)
* [Configuration Templates](#configuration-templates)
* [Immutable Configurations](#immutable-configurations)

### Environment Variables
### Configuration Resources
### Configuration Templates
### Immutable Configurations
