# Pods Security Context Constraints
Besides allowing the pod to use the Linux namespaces, other security-related features can also be configured on the pod and its container through the security context. The pod ``securityContext`` properties, which can be specified under the pod spec directly or inside the spec of individual containers.

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
  name: nginx
  namespace:
  labels:
spec:
  securityContext: {}
  containers:
  - name: mynginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

Create this pod

    kubectl create -f pod-default-scc.yaml
    pod "nginx" created
    
and see what user and group ID the container is running as, and which groups it belongs to. We can see this by running the ``id`` command inside the container

    kubectl exec -it nginx id
    uid=0(root) gid=0(root) groups=0(root)

This container is running as user ID (uid) 0, which is root, and group ID (gid) 0 (also root). It’s also a member of multiple other groups. Note that the user the container runs as is specified in the container image. In
a Dockerfile, this is done using the ``USER`` directive. If omitted, the container always runs as root.
