# Pods Security Context
Besides allowing the pod to use the Linux namespaces, other security-related features can also be configured on the pod and its container through the security context. The ``securityContext`` properties can be specified under the pod spec directly or inside the spec of individual containers.

Configuring the security context allows you to do:

  * Specify the user ID under which the process in the container will run
  * Prevent the container from running as root
  * Give the container full access to the worker node kernel (priviledged mode)
  * Configure fine grained privileges by adding or dropping capabilities to the container
  * Set SELinux options to the container
  * Prevent the process inside the container from writing to the filesystem

We start by creating a pod with default security context options so we can see how it behaves compared to pods with a custom security context. Start a test pod from the ``pod-default-scc.yaml`` descriptor file having the default security context

```yaml

apiVersion: v1
kind: Pod
metadata:
  name: pod-default-scc
  namespace:
  labels:
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["/bin/sleep", "3600"]
    securityContext: {}
```

Create this pod

    kubectl create -f pod-default-scc.yaml
    
and see what user and group ID the container is running as, and which groups it belongs to. We can see this by running the ``id`` command inside the container

    kubectl exec -it pod-default-scc id
    uid=0(root) gid=0(root)

This container is running as user ID (uid) 0, which is root, and group ID (gid) 0 which is also root. It’s also a member of multiple other groups.

Note: *the user the container runs as is specified in the container image. In a Dockerfile, this is done using the ``USER`` directive. If omitted, the container always runs as root.*

In the next examples, we'll set the security context of an individual container. Several of these options can also be set at the pod level: they serve as a default for all the pod’s containers but can be overridden at the container level.

## Run a pod as a specified user
To run a pod under a different user id than that is specified into the container image, we’ll need to set the pod’s security context to run as a different user as shown in the ``pod-as-user-guest.yaml`` descriptor file 

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-as-user-guest
  namespace:
  labels:
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["/bin/sleep", "3600"]
    securityContext:
      runAsUser: 405
```

Create the pod and see the user id

    kubectl create -f pod-as-user-guest.yaml

    kubectl exec -it pod-as-user-guest id
    uid=405 gid=0(root)

## Preventing a container from running as root
When we want to prevent a container from running as root, we can force the security context of the pod where container is in. See the following ``pod-as-no-root.yaml`` descriptor file

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-as-no-root
  namespace:
  labels:
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["/bin/sleep", "3600"]
    securityContext:
      runAsNonRoot: true
```

If we try to run this pod, the pod is started but the container is not running because we deny container running as root.

## Running pods in privileged mode
Sometimes pods need to do everything that the node they’re running on can do, such as use protected system devices or other kernel features, which aren’t accessible to regular containers. An example of such a pod is the ``kube-proxy`` pod, which needs to modify the worker’s iptables rules to make kubernetes services work.

To get full access to the node’s kernel, the pod’s container need to run in privileged mode as in the ``pod-privileged-mode.yaml`` descriptor file

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-priviliged-mode
  namespace:
  labels:
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["/bin/sleep", "3600"]
    securityContext:
      privileged: true
```

Start the pod above and check if the pod is able to list the host devices

    kubectl create -f pod-privileged-mode.yaml
 
    kubectl exec -it pod-priviliged-mode -- ls /dev/sda
    /dev/sda
    
Start a pod with default security context and check the same    
    
    kubectl create -f pod-default-scc.yaml
    
    kubectl exec -it pod-default-scc -- ls /dev
    ls: /dev/sda: No such file or directory

The privileged pod sees all the host devices where a standard pod does not.

## Adding kernel capabilities to a container
Old UNIX implementations only distinguished between privileged and unprivileged processes, but Linux supports a much more
fine grained permission system through kernel capabilities. Instead of making a container privileged and giving it unlimited permissions, a much safer method is to give it access only to the kernel features it really requires.

For example, a container usually isn’t allowed to change the system time. Check this by trying to set the time in a pod with defaults

    kubectl exec -it pod-default-scc -- date +%T -s "12:00:00"
    date: can't set date: Operation not permitted

To allow the container to change the system time, add a capability called ``CAP_SYS_TIME`` to the container’s capabilities list, as shown in the following ``pod-with-settime-cap.yaml`` descriptor file

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-settime-cap
  namespace:
  labels:
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["/bin/sleep", "3600"]
    securityContext:
      capabilities:
        add:
        - SYS_TIME
```

Start the pod above and change the time of the worker node where the pod is running

    kubectl create -f pod-with-settime-cap.yaml
    
    kubectl exec -it pod-with-settime-cap -- date +%T -s "12:00:00"
    
    kubectl exec -it pod-with-settime-cap -- date
    Fri Jun  8 12:00:32 UTC 2018


## Dropping capabilities from a container
We can also drop capabilities that may otherwise be available to the container. For example, the default capabilities include the ``CAP_CHOWN`` capability, which allows container to change the ownership of files in its filesystem.

    kubectl exec -it pod-default-scc -- touch /tmp/myfile
    
    kubectl exec -it pod-default-scc -- chown 405 /tmp/myfile
    
    kubectl exec -it pod-default-scc -- ls -l /tmp
    -rw-r--r--  1 405  root 0 Jun  8 12:30 myfile

To prevent the container from doing that, drop the ``CHOWN`` capability as shown in the following ``pod-drop-chown-cap.yaml`` descriptor file

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-drop-chown-cap
  namespace:
  labels:
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["/bin/sleep", "3600"]
    securityContext:
      capabilities:
        drop:
        - CHOWN
```

Start the pod above and check the capability

    kubectl create -f pod-drop-chown-cap.yaml

    kubectl exec -it pod-drop-chown-cap -- touch /tmp/myfile
    
    kubectl exec -it pod-drop-chown-cap -- chown 405 /tmp/myfile
    chown: /tmp/myfile: Operation not permitted
    command terminated with exit code 1
    
    kubectl exec -it pod-drop-chown-cap -- ls -l /tmp/myfile
    -rw-r--r--    1 root root 0 Jun  8 12:40 /tmp/myfile

A list of supported capabilities can be displayed with the ``capsh --print`` command.


## Preventing container from writing to the filesystem
In this example, we want to prevent the the container from writing to its filesystem, and only allow it to write to mounted volumes. 

Create a pod as in the following ``pod-with-readonly-filesystem.yaml`` descriptor file

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-readonly-filesystem
  namespace:
  labels:
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["/bin/sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: myvolume
      mountPath: /volume
      readOnly: false
  volumes:
  - name: myvolume
    emptyDir:
```

Create a pod from the file above

    kubectl create -f pod-with-readonly-filesystem.yaml

The container inside the pod is running as root, which has write permissions to all the filesystem, but trying to write a file there is failing

    kubectl exec -it pod-with-readonly-filesystem -- touch /tmp/myfile
    touch: /tmp/myfile: Read-only file system
    command terminated with exit code 1

On the other end, the same container is able to write on the mounted volume

    kubectl exec -it pod-with-readonly-filesystem -- touch /volume/myfile

    kubectl exec -it pod-with-readonly-filesystem -- ls -l /volume/myfile
    -rw-r--r--    1 root     root             0 Jun  8 12:47 /volume/myfile
