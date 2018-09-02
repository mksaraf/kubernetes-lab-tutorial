# Cluster Monitoring
Kubernetes provides detailed information about applications and cluster resources usage. This information allows to evaluate the application’s performance and where bottlenecks can be removed to improve overall performance of the cluster.

In Kubernetes, application monitoring does not depend on a single monitoring solution. In this section, we're going to explore some of the monitoring tools currently available.

  * [Resources usage](#resources-usage)
  * [cAdvisor](#cadvisor)
  * [Metric Server](#metric-server)
  * [Pods Autoscaling](#pods-autoscaling)
  * [Nodes Autoscaling](#nodes-autoscaling)
 
## Resources usage
When creating a pod, we can specify the amount of CPU and memory that a container requests and a limit on what it may consume. 

The following pod manifest ``requests-pod.yaml`` specifies the CPU and memory requests for its single container.

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
  restartPolicy: Never
```

By specifying resource requests, we specify the minimum amount of resources the pod needs. However the pod above can take more than the requested CPU and memory we requested, according to the capacity and the actual load of the working node. Each node has a certain amount of CPU and memory it can allocate to pods. When scheduling a pod, the scheduler will only consider nodes with enough unallocated resources to meet the pod requirements. If the amount of unallocated CPU or memory is less than what the pod requests, the scheduler will not consider the node, because the node can’t provide the minimum amount
required by the pod.

Create the pod above

    kubectl apply -f requests-pod.yaml

Checking the resource usage

    kubectl exec requests-pod top

    Mem: 3469164K used, 2398380K free, 310084K shrd, 2072K buff, 2264708K cached
    CPU: 18.9% usr 36.5% sys  0.1% nic 43.9% idle  0.0% io  0.0% irq  0.3% sirq
    Load average: 1.57 0.73 0.54 3/642 8
      PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
        1     0 root     R     1236  0.0   1 50.0 dd if /dev/zero of /dev/null
        5     0 root     R     1244  0.0   1  0.0 top

we see the pod taking up to 50% of total of the node CPU. On a 2 core CPU node, this corresponds to 1 CPU and it's as espected because the ``dd`` command is single-thread and cannot take more than 1 CPU by design.

Please, note that we're not specifying the maximum amount of resources the pod can consume. If we want to limit the usage of resources, we have to limit the pod as in the following ``limited-pod.yaml`` descriptor file

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
  restartPolicy: Never
  terminationGracePeriodSeconds: 10
```

Create the pod

    kubectl apply -f limited-pod.yaml

Checking the resource usage

    kubectl exec limited-pod top

    Mem: 3458876K used, 2408668K free, 309892K shrd, 2072K buff, 2264840K cached
    CPU:  7.6% usr  8.5% sys  0.0% nic 83.5% idle  0.0% io  0.0% irq  0.2% sirq
    Load average: 1.97 1.14 0.74 6/621 12
      PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
        1     0 root     R     1236  0.0   0 10.5 dd if /dev/zero of /dev/null
        5     0 root     S     1244  0.0   0  0.0 top

We can see the pod taking 10% of the node CPU. On a 2 core CPU node, this corresponds to 200m of the single CPU.

Both resources requests and limits are specified for each container individually, not for the entire pod. The pod resource requests and limits are the sum of the requests and limits of all the containers contained into the pod. 

We can check the usage of the resources at node level by describing the node

    kubectl describe node kubew00

    ...

      Namespace            Name                 CPU Requests  CPU Limits  Memory Requests  Memory Limits
      ---------            ----                 ------------  ----------  ---------------  -------------
      default              limited-pod          200m (10%)    200m (5%)   0 (0%)           0 (0%)
      default              request-pod          200m (10%)    0 (0%)      0 (0%)           0 (0%)

    Allocated resources:

      Resource  Requests     Limits
      --------  --------     ------
      cpu       400m (20%)   200m (10%)
      memory    0 (0%)       0 (0%)


## cAdvisor
The resource usage is provided by the **cAdvisor** agent running into kubelet binary and exposed externally to the port 4194 on the worker node. This is an unsecure port and can be closed. If not closed, we can start a simple web UI of the cAdvisor agent by using a web browser. The cAdvisor auto-discovers all containers running on the node and collects CPU, memory, filesystem, and network usage statistics. It also provides the overall machine usage by analyzing the root container.

## Metric Server
The **Metric Server** is a kubernetes add-on running as pod in the cluster. It makes centrally accessible all the metrics collected by all the cAdvisor agents running on the worker nodes. Once installed, the metric server makes it possible to obtain resource usages for nodes and individual pods through the ``kubectl top`` command.

To see how much CPU and memory is being used on the worker nodes, run the command: 

    kubectl top nodes
    
    NAME          CPU(cores)   CPU%      MEMORY(bytes)   MEMORY%   
    kubew03       366m         18%       2170Mi          38%       
    kubew04       102m          6%       2170Mi          38%   
    kubew05       708m         40%       2170Mi          38%   

This shows the actual, current CPU and memory usage of all the pods running on all the nodes.

To see how much each individual pod is using, use the command:

    kubectl top pods

    NAME                    CPU(cores)   MEMORY(bytes)   
    curl                    0m           0Mi             
    limited-pod             200m         0Mi             
    request-pod             999m         0Mi        

To see resource usages across individual containers instead of pods, use the ``--containers`` option

    kubectl top pod limited-pod --containers

    POD           NAME      CPU(cores)   MEMORY(bytes)   
    limited-pod   busybox   200m         0Mi             

Metrics are also exposed as API by the kubernetes API server at ``http://cluseter.local/apis/metrics.k8s.io/v1beta1`` address.

### Installing the Metric Server
The purpose of the Metric Server is to provide a stable, versioned API that other kubernetes components can rely on. Metric Server is part of the so-called *core metrics pipeline* and it is installed as kubernetes add-on.

In order to setup the Metrics Server, we first need to configure the *aggregation layer* on the cluster. The aggregation layer is a feature of the API server, allowing other custom API servers to register themselves to the main kubernetes API server. This is accomplished by configuring the *kube-aggregator* on the main kubernetes API server. The aggregator is basically a proxy (embedded into the main API server) that forwards requests coming from clients to all the API servers, including the main one.

![](../img/aggregator.png?raw=true)

Configuring the aggregation layer involves setting a number of flags on the API Server

     --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
     --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
     --requestheader-allowed-names=front-proxy-client
     --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
     --requestheader-extra-headers-prefix=X-Remote-Extra-
     --requestheader-group-headers=X-Remote-Group
     --requestheader-username-headers=X-Remote-User
     --enable-aggregator-routing=true

using some additional certificates. See [here](https://github.com/kubernetes-incubator/apiserver-builder/blob/master/docs/concepts/auth.md) for details.

The Metric Server is one of the custom API server that can be configured with the aggregator. To install it, configure the API server to enable the aggregator and then deploy it in the ``kube-system`` namespace from the manifest files:

     kubectl apply -f auth-delegator.yaml
     kubectl apply -f auth-reader.yaml
     kubectl apply -f resource-reader.yaml
     kubectl apply -f metrics-apiservice.yaml
     kubectl apply -f metrics-server-sa.yaml
     kubectl apply -f metrics-server-deployment.yaml
     kubectl apply -f metrics-server-service.yaml

The metric server will be deployed as pod and exposed as an internal service.

    get deploy metrics-server

    NAME             DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
    metrics-server   1         1         1            1           2h

    kubectl get svc metrics-server

    NAME             TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)         AGE
    metrics-server   ClusterIP   10.32.0.19    <none>        443/TCP         2h

The Metric Server is the foundation for the pods autoscaling feature.

## Pods Autoscaling
Applications running in pods can be scaled out manually by increasing the replicas field of the Replica Set, Deploy, or Stateful Set. However, kubernetes can monitor the pods and scale them up automatically as soon as it detects an increase in the CPU usage or some other metric. To achieve this, we need to configure an autoscaler object. We can have multiple autoscalers, each one controlling a separated set of pods.

The pods autoscaling process is implemented as a control loop that can be split into three steps:

 1. Obtain metrics of all the pods managed by the scaled resource object.
 2. Calculate the number of pods required to bring the metrics close to a target value.
 3. Update the replicas field of the scaled resource.

The autoscaler controller doesn’t perform the collection of the pod metrics itself. Instead, it gets the metrics from the Metric Server through REST calls.

Once the autoscaler gathered all the metrics for the pods, it can use those metrics to return the number of replicas to bring the metrics close to the target.

When the autoscaler is configured to consider only a single metric, calculating the required replica count is simple: sum the metrics values of all the pods, divide that by the target value and then round it up to the next integer. For example, if we set the target value to be *50%* of requested CPU and we have 3 pods consuming, respectively, *60%*, *90%*, and *50%*, then the resulting number is *(60+90+50)/50=4* replicas.

The final step of the autoscaler is updating the desired replica count field on the resource object, e.g. the Deploy, and then letting it take care of spinning up additional pods or deleting excess ones.

The period of the autoscaler is controlled by the ``--horizontal-pod-autoscaler-sync-period`` flag of controller manager. The default value is 30 seconds. The delay between two scale up operations is controlled by using the flag  ``--horizontal-pod-autoscaler-upscale-delay``. The default value is 3 minutes. Similarly, the delay between two scale down operations is adjustible with flag  ``--horizontal-pod-autoscaler-downscale-delay``. The default value is 5 minutes. 

### Autoscaling based on CPU usage
The most common used metric for pods autoscaling is the node's CPU consumed by all the pods controlled by the autoscaler. Those values are collected from the Metric Server and evaluated as an average.

The target parameter used by the autoscaler to determine the number of replicas is the requested CPU specified by the pod descriptor.

In this section, we're going to configure the pods autoscaler for a set of nginx pods.

Define a deploy as in the following ``nginx-deploy.yaml`` descriptor file

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
  name: nginx
  namespace:
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
        resources:
          requests:
            cpu: 50m
          limits:
            cpu: 100m
```

We set the requests for *50m* CPU. This means that, considering a standard 2 CPUs node, each pod needs for the *2.5%* of node's CPU to be scheduled. Having set the desired state as for 3 replicas, make sure, overall, there is *7.5%* of node's CPU. Also we set *100m* CPU as hard limit for each pod. This means that the all 3 pods cannot eat more than *15%* of the node's CPU.

Create the deploy

    kubectl apply -f nginx-deploy.yaml

and check the pods CPU usage

    kubectl top pod

    NAME                    CPU(cores)   MEMORY(bytes)   
    nginx-945d64b6b-995tf   0m           1Mi             
    nginx-945d64b6b-b4sc6   0m           1Mi             
    nginx-945d64b6b-ncsnm   0m           1Mi         

Please, note that it takes a while for cAdvisor to get the CPU metrics and for Metric Server to collect them. Because we’re running three pods that are currently receiving no requests, we should expect their CPU usage should be close to zero.

Now we define an autoscaler as in the following ``nginx-hpa.yaml`` descriptor file

```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: nginx
  namespace:
  labels:
spec:
  maxReplicas: 9
  minReplicas: 1
  scaleTargetRef:
    apiVersion: extensions/v1beta1
    kind: Deployment
    name: nginx
  targetCPUUtilizationPercentage: 20
```

This creates an autoscaler object and sets the ``nginx`` deployment as the scaling target object. We’re setting the target CPU utilization to *20%* of the requested CPU, i.e. *10m* and specifying the minimum and maximum number of replicas. The autoscaler will constantly adjusting the number of replicas to keep the pod CPU utilization around *10m*, but it will never scale down to less than 1 or scale up to more than 9 replicas.

Create the pods autoscaler 

    kubectl apply -f nginx-hpa.yaml

and check it

    kubectl get hpa nginx

    NAME      REFERENCE          TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
    nginx     Deployment/nginx   0/20%      1         9         1          3s

Because all three pods are consuming an amount of CPU close to zero, we expect the autoscaler scale them to the minimum number of pods. Is soon scales the deploy to a single replica

    kubectl get deploy nginx

    NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
    nginx     1         1         1            1           10m

Remember, the autoscaler only adjusts the desired replica count on the deployment. Then the deployment takes care of updating the desired replica count on its replica set, which then causes the replica set to delete the two excess
pods, leaving only one pod running.

Now, we’ll start sending requests to the remaining pod, thereby increasing its CPU usage, and we should see the autoscaler in action by detecting this and starting up additional pods.

To send requests to the pods, we need to expose them as an internal service so we can send requests in a load balanced mode. Create a service as for the ``nginx-svc.yaml`` manifest file

    kubectl apply -f nginx-svc.yaml

Also we define a simple load generator pod as in the following ``load-generator.yaml`` file

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: load-generator
  namespace:
  labels:
spec:
  containers:
  - image: busybox:latest
    name: busybox
    command: ["/bin/sh", "-c", "while true; do wget -O - -q http://nginx; done"]
  terminationGracePeriodSeconds: 10
```

Create the load generator

    kubectl apply -f load-generator.yaml

As we start to sending requests to the pod, we'll se the metric jumping to *70m* that is more than the target value of 20% of the requested CPU. By simple math 20% of 50m is 10m.

### Autoscaling based on memory usage

### Autoscaling based on custom metrics
But one metric does not fit all use cases and for different kind of applications, the metric might vary. For example, for a message queue, the number of messages in waiting state might be the appropriate metric. For memory intensive applications, memory consumption might be that metric. If you have a business application which handles about 1000 transactions per second for a given capacity pod, then you might want to use that metric and scale out when the TPS in pod reach above 850.

So far we have only considered the scale-up part, but when the workload usage drops, there should be a way to scale down gracefully and without causing interruption to existing requests being processed.


## Nodes Autoscaling
