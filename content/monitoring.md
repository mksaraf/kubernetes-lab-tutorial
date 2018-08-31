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
        memory: 10Mi
  restartPolicy: Never
```

By specifying resource requests, we specify the minimum amount of resources the pod needs. However the pod above can take more than the requested CPU and memory we requested, according to the capacity and the actual load of the working node. Each node has a certain amount of CPU and memory it can allocate to pods. When scheduling a pod, the scheduler will only consider nodes with enough unallocated resources to meet the pod requirements. If the amount of unallocated CPU or memory is less than what the pod requests, the scheduler will not consider the node, because the node can’t provide the minimum amount
required by the pod.

Create the pod above

    kubectl apply -f requests-pod.yaml

We're not specifying the maximum amount of resources the pod can consume.

Checking the resource usage

    kubectl exec requests-pod top

    Mem: 1288116K used, 760368K free, 9196K shrd, 25748K buff, 814840K cached
    CPU: 9.1% usr 42.1% sys 0.0% nic 48.4% idle 0.0% io 0.0% irq 0.2% sirq
    Load average: 0.79 0.52 0.29 2/481 10
    PID PPID USER STAT VSZ %VSZ CPU %CPU COMMAND
    1 0 root R 1192 0.0 1 50.0 dd if /dev/zero of /dev/null
    7 0 root R 1200 0.0 0 0.0 top

we see the pod taking up to 50% of total CPU of the node. On a 2 core CPU node, this corresponds to a single CPU and it's as espected because the ``dd`` command is single-thread and cannot take more than one CPU by design.

If we want to limit the usage of resources, we have to limit the pod.





They’re specified for each container individually, not for the pod. The pod resource requests and limits are the sum of the requests and limits of all its containers. 


## cAdvisor



## Metric Server




## Autoscaling
