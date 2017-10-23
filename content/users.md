# User Management
In this section we are going to cover additional concepts related to the authentication, authorization and user management.

   * [Service Accounts](#service-accounts)
   * [Authentication](#authentication)
   * [Authorization](#authorization)

## Service Accounts
In kubernetes we have two kind of users:

  1. **Service Accounts**: used for applications running in pods that need to contact the apiserver. 
  2. **User Accounts**: used for humans or machines
  
User accounts are global, i.e. user names must be unique across all namespaces of a cluster while service accounts are namespaced. Each namespace has a default service account automatically created by kubernetes. 

Access the master node and query for the service accounts

    kubectl get sa --all-namespaces
    NAMESPACE     NAME                 SECRETS   AGE
    default       default              1         3d
    kube-public   default              1         3d
    kube-system   default              1         3d
    project       default              1         3d

Each pod running in the cluster is forced to use the default service account if no one is specified in the pod configuration file. This job is ensured by the ``--admission-control=ServiceAccount`` set in the API server. For example, create an nginx pod and inspect it

    kubectl create -f nginx-pod.yaml
    kubectl get pod nginx -o yaml
    
We can see the default service account assigned to the pod and mounted as a secret volume containing the token for authenticate the pod against the API server
```
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: project
spec:
  containers:
  - image: nginx:latest
    name: mynginx
...
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: default-token-xr7kb
      readOnly: true
...
  serviceAccount: default
  serviceAccountName: default
...
  volumes:
  - name: default-token-xr7kb
    secret:
      defaultMode: 420
      secretName: default-token-xr7kb
```

If we want to use custom service account we have to create it as in the ``nginx-sa.yaml`` configuration file
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx
  namespace:
```

and use it in the ``nginx-pod-sa.yaml`` configuration file
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod-sa
  namespace:
  labels:
spec:
  containers:
  - name: mynginx
    image: nginx:latest
    ports:
    - containerPort: 80
  serviceAccount: nginx
```

Inspecting the service account just created above
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx
  namespace: project
  selfLink: /api/v1/namespaces/project/serviceaccounts/nginx
  uid:
secrets:
- name: nginx-token-9dx47
```

we see that a service account token has automatically been created 

    kubectl get secrets
    NAME                  TYPE                                  DATA      AGE
    default-token-xr7kb   kubernetes.io/service-account-token   3         3d
    nginx-token-9dx47     kubernetes.io/service-account-token   3         22m

Service accounts are tied to a set of credentials stored as secrets which are mounted into pods allowing in cluster processes to authenticate the service account against the API server.

To achieve token creation for service accounts, we have to pass a private key file to the controller-manager via the ``--service-account-private-key-file`` option to sign generated service account tokens. Similarly, we have to pass the corresponding public key to the API server using the ``--service-account-key-file`` option.

*Please, note that each time the public and private certificate keys change, we have to delete the service accounts, including the default service account for each namespace.*

Service accounts are useful when the pod needs to access the API server. For example, the following ``nodejs-pod-namespace.yaml`` definition file implements an API call to read the pod namespace and put it into a pod env variable
```yaml

apiVersion: v1
kind: Pod
metadata:
  name: nodejs-web-app
  namespace:
  labels:
    app:nodejs
spec:
  containers:
  - name: nodejs
    image: kalise/nodejs-web-app:latest
    ports:
    - containerPort: 8080
    env:
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: MESSAGE
      value: "Hello $(POD_NAMESPACE)"
  serviceAccount: default
```

Create the pod above and access the pod

    kubectl create -f nodejs-pod-namespace.yaml

    kubectl get pod -l app=nodejs -o wide
    NAME             READY     STATUS    RESTARTS   AGE       IP          NODE
    nodejs-web-app   1/1       Running   0          13m       10.38.4.9   kubew04

    curl 10.38.4.9:8080
    <html><head></head><body>Hello project from 10.38.4.9</body></html>

we get an answer from the pod being in the namespace name ``project``.

## Authentication



