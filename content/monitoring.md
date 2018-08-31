# Monitoring the cluster
Kubernetes provides detailed information about applications and cluster resources usage. This information allows to evaluate the application’s performance and where bottlenecks can be removed to improve overall performance of the cluster.

In Kubernetes, application monitoring does not depend on a single monitoring solution. In this section, we're going to explore some of the monitoring tools currently available.

  * [Resources usage]()
  * [cAdvisor]()
  * [Metric Server]()
  * [Autoscaling]()
  * [Prometheus]()
 
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

We're not specifying the maximum amount of resources the pod can consume.

Checking the resource usage

    kubectl exec requests-pod top

    Mem: 3469164K used, 2398380K free, 310084K shrd, 2072K buff, 2264708K cached
    CPU: 18.9% usr 36.5% sys  0.1% nic 43.9% idle  0.0% io  0.0% irq  0.3% sirq
    Load average: 1.57 0.73 0.54 3/642 8
      PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
        1     0 root     R     1236  0.0   1 50.0 dd if /dev/zero of /dev/null
        5     0 root     R     1244  0.0   1  0.0 top

we see the pod taking up to 50% of total of the node CPU. On a 2 core CPU node, this corresponds to a single CPU and it's as espected because the ``dd`` command is single-thread and cannot take more than one CPU by design.

If we want to limit the usage of resources, we have to limit the pod as in the following ``limited-pod.yaml`` descriptor file

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
The resource usage is provided by the **cAdvisor** agent running into kubelet binary and exposed externally to the port 4194 on the worker node. This is an unsecure port and can be closed. If not closed, we can start a simple UI on the cAdvisor agent. The cAdvisor auto-discovers all containers running on the node and collects CPU, memory, filesystem, and network usage statistics; it cAdvisor also provides the overall machine usage by analyzing the root container. Gathering those statistics centrally for the whole cluster requires to run an additional component.

## Metric Server
The **Metric Server** is an additional component running as pod in the cluster, making centrally accessible all the metrics colled by any cAdvisor agent running on each node. 



## Autoscaling
