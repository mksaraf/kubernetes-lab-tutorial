# User Management
In this section we are going to cover additional concepts related to the authentication, authorization and user management.

   * [Service Accounts](#service-accounts)
   * [Authentication](#authentication)
   * [Authorization](#authorization)
   * [Admission Control](#admission-control)

In kubernetes, users access the API server via HTTP(S) requests. When a request reaches the API, it goes through several stages:

  1. **Authentication**: who can access?
  2. **Authorization**: what can be accessed?
  3. **Admission Control**: cluster wide policy

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
Kubernetes uses different ways to authenticate users: certificates, tokens, passwords as long enhanced methods as OAuth. Multiple methods can be used at same time, depending on the use case. At least two methods:

  * tokens for service accounts
  * at least one of the following methods for user accounts
  
When multiple authenticator modules are enabled, the first module to successfully authenticate the request applies since the API server does not guarantee the order authenticators. See the official documentation for all details.

### Certificates
Client certificate authentication is enabled by passing the ``--client-ca-file`` option to API server. The file contains one or more certificates authorities to use to validate client certificates presented to the API server. When a client certificate is presented and verified, the common name field in the subject certificate is used as the user name for the request and the organization fields in the certificate can indicate the group memberships. To include multiple group memberships for a user, include multiple organization fields in the certificate.

For example, to create a certificate for an ``admin`` user belonging the the ``system:masters`` group create a signing request ``admin-csr.json`` file
```json
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
```
The group ``system:masters`` membership will give the admin user the power to act as cluster admin when the authorization is enabled.

Create the certificate

    cfssl gencert \
       -ca=ca.pem \
       -ca-key=ca-key.pem \
       -config=ca-config.json \
       -profile=custom \
       admin-csr.json | cfssljson -bare admin

This will produce the ``admin.pem`` certificate file containing the public key and the ``admin-key.pem`` file, containing the private key. Move the key and certificate, along with the Certificate Authority certificate ``ca.pem`` to the client proper location on the client machine and create the ``kubeconfig`` file to access via the ``kubectl`` client
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: ca.pem
    server: https://kubernetes:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    namespace: default
    user: admin
  name: default/kubernetes/admin
current-context: default/kubernetes/admin
kind: Config
preferences: {}
users:
- name: admin
  user:
    client-certificate: admin.pem
    client-key: admin-key.pem
    username: admin
```

### Tokens
Bearer token authentication is enabled by passing the ``--token-auth-file`` option to API server. The file contains one or more tokens to authenticate user requests presented to the API server. The token file is a csv file with a minimum of 3 columns: token, user name, user uid, followed by optional group names.

For example
```csv
aaaabbbbccccdddd000000000000000a,admin,10000,system:masters
aaabbbbccccdddd0000000000000000b,alice,10001
aaabbbbccccdddd0000000000000000c,joe,10002
```

Move on the client machine and create the ``kubeconfig`` file to access via the ``kubectl`` client
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: ca.pem
    server: https://kubernetes:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    namespace: default
    user: admin
  name: default/kubernetes/admin
current-context: default/kubernetes/admin
kind: Config
preferences: {}
users:
- name: admin
  user:
    token: aaaabbbbccccdddd000000000000000a
    username: admin
```

When using a token authentication fron an HTTP(S) client, put the token in the request header

    curl -k -H "Authorization:Bearer aaaabbbbccccdddd000000000000000a" https://kubernetes:6443

*Note: the token file cannot be changed without restarting API server.*

### Password
Basic password authentication is enabled by passing the ``--basic-auth-file`` option to API server. The password file is a csv file with a minimum of 3 columns: password, user name, user id and an optional fourth column containing group names. 

For example
```csv
Str0ngPa55word123!,admin,10000,system:masters
Str0ngPa55word456!,alice,10001
Str0ngPa55word789!,joe,10002
```

When using basic authentication from an http client, the API server expects an authorization header with a value of encoded user and password

    BASIC=$(echo -n 'admin:Str0ngPa55word123!' | base64)
    curl -k -H "Authorization:Basic "$BASIC https://kubernetes:443

*Note: the passwords file cannot be changed without restarting API server.*

### Other methods
Please, see the kubernetes documentation for other authentication methods. 





