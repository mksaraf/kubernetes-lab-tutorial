# Batch Processes
In this section we are going to explore kubernetes support for batch processing.

   * [Jobs](#jobs)
   * [Cron Jobs](#cron-jobs)
  
## Jobs
In kubernetes, a **Job** is an abstraction for create batch processes. A job creates one or more pods and ensures that a given number of them successfully complete. When all pod complete, the job itself is complete. 

For example, the ``hello-job.yaml`` file defines a set of 16 pods each one printing a simple greating message on the standard output. In our case, up to 4 pods can be executed in parallel 
```yaml
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
```

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

There are three ways to use jobs:

   1. *Single Jobs*
   2. *Parallel Jobs*
   3. *Work Queue Jobs*
    
For single jobs, only one pod is started unless it fails and the job completes when pod completes successfully. To create a single job, leave both the options ``completions`` and ``parallelism`` unset or set both them to 1.

For parallel jobs, with a fixed completion count, set the ``completions`` option to the number of desired pods. The ``parallelism`` option specifies the number of pods to run in parallel.

For work queue jobs, leave the the ``completions`` option unset while set the ``parallelism`` option to the dsidered number of pods to run in parallel. 

## Cron Jobs
In kubernetes, a **Cron Job** is a time based managed job. A cron job runs a job periodically on a given schedule, written in standard unix cron format.

For example, the ``date-cronjob.yaml`` file defines a cron job to print, every minute, the current date and time on the standard output
apiVersion: batch/v1beta1
```yaml
kind: CronJob
metadata:
  name: currentdate
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: date
            image: busybox
            imagePullPolicy: IfNotPresent
            args:
            - /bin/sh
            - -c
            - echo "Current date is"; date
          restartPolicy: OnFailure
```

Create the cron job

    kubectl create -f date-cronjob.yaml

and check the pod it creates

    kubectl get pods -o wide -a
    NAME                           READY     STATUS      RESTARTS   AGE       IP            NODE
    currentdate-1508917200-j8vl9   0/1       Completed   0          2m        10.38.3.127   kubew03
    currentdate-1508917260-qg9zn   1/1       Running     0          1m        10.38.5.98    kubew05

Every minute, a new pod is created. When the pod completes, its parent job completes and a new job is scheduled

    kubectl get jobs -o wide
    NAME                     DESIRED   SUCCESSFUL   AGE       CONTAINERS   IMAGES    SELECTOR
    currentdate-1508917200   1         1            2m        date         busybox   
    currentdate-1508917260   1         1            1m        date         busybox  
    currentdate-1508917320   1         1            31s       date         busybox   

    kubectl get cronjob
    NAME          SCHEDULE      SUSPEND   ACTIVE    LAST SCHEDULE   AGE
    currentdate   */1 * * * *   False     1         Wed, 25 Oct 2017 09:46:00 +0200
