# Batch Processing
In this section we are going to explore kubernetes support for batch processing.

   * [Jobs](#jobs)
   * [Cron Jobs](#cron-jobs)
  
## Jobs
In kubernetes, a **Job** is an obstraction for create batch processes. A job creates one or more pods and ensures that a given number of them successfully complete. When all pod complete, the job itself is complete. 

For example, the hello-job.yaml file defines a set of 16 pods each one printing a simple greating message on the standard output. In our case, up to 4 pods can be executed in parallel 

apiVersion: batch/v1
kind: Job
metadata:
  name: simplejob
spec:
  completions: 16
  parallelism: 4
  template:
    metadata:
      name: hello
    spec:
      containers:
      - name: hello
        image: busybox
        imagePullPolicy: IfNotPresent
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        args:
        - /bin/sh
        - -c
        - echo Hello from $(POD_NAME)
      restartPolicy: OnFailure

Create the job

      kubectl create -f hello-job.yaml

and check the pods it creates

kubectl get pods -o wide -a
NAME                           READY     STATUS              RESTARTS   AGE       IP           NODE
simplejob-4729j                0/1       Completed           0          14m       10.38.3.83   kubew03
simplejob-5rsbt                0/1       Completed           0          14m       10.38.5.60   kubew05
simplejob-78jkn                0/1       Completed           0          15m       10.38.4.53   kubew04
simplejob-78jhx                0/1       Completed           0          15m       10.38.4.51   kubew04
simplejob-469wk                0/1       ContainerCreating   0          3s        <none>       kubew03
simplejob-9gnfp                0/1       ContainerCreating   0          3s        <none>       kubew03
simplejob-wrpzp                0/1       ContainerCreating   0          3s        <none>       kubew05
simplejob-xw5qz                0/1       ContainerCreating   0          3s        <none>       kubew05

After printing the message, each pod completes.

Check the job status

kubectl get jobs -o wide
NAME           DESIRED   SUCCESSFUL   AGE       CONTAINERS   IMAGES    SELECTOR
simplejob      16         4           2m        hello        busybox 

Deleting a job will remove all the pods it created

    kubectl delete job simplejob
    kubectl get pods -o wide -a

There are 


## Cron Jobs
