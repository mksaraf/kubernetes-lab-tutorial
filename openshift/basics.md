# Getting started with OpenShift
It is now time to create the **Hello World** application using some sample code. It is simple http server written in nodejs returning a greating message as contained into the MESSAGE env variable. The application is available as Docker image and the source code is [here](https://github.com/kalise/nodejs-web-app).

## Create a demo user
OpenShift platform supports a number of mechanisms for authentication. The simplest use case for testing purposes is htpasswd-based authentication. To start, we will need the ``htpasswd`` binary on the Master node

```
yum -y install httpd-tools
```

The OpenShift configuration is stored in a YAML file at ``/etc/origin/master/master-config.yaml``. During the installation procedure, Ansible was configured to enable the ``htpasswd`` based authentication, so that it should look like the following:

```yaml
...
identityProviders:
- challenge: true
  login: true
  name: htpasswd_auth
  provider:
    apiVersion: v1
    file: /etc/htpasswd
    kind: HTPasswdPasswordIdentityProvider
...
```
More information on these configuration settings can be found on the product documentation.

Create a standard user:
```
useradd demo
passwd demo
touch /etc/htpasswd
htpasswd -b /etc/htpasswd demo *********
```

Login to the OpenShift platform as demo user by the ``oc`` CLI command
```
oc login -u demo -p ********
Login successful.
You don't have any projects. You can try to create a new project, by running
oc new-project <projectname>
```

## Create a demo project
The OpenShift platform has the concept of "projects" to contain a number of different resources.

Create a demo project for our first application.

The default configuration for CLI operations currently is to be the ``system:admin`` passwordless user, which is allowed to create projects. Login as admin user:
```
oc login -u system:admin
Logged into "https://master.openshift.com:8443" as "system:admin" using existing credentials.
You have access to the following projects and can switch between them with 'oc project <projectname>':

  * default
    kube-system
    logging
    management-infra
    openshift
    openshift-infra

Using project "default".
```

We can use the admin OpenShift ``oc adm`` command to create a project, and assign an administrative user to it.

As the root system user on master:
```
oc adm new-project demo \
--display-name="OpenShift Demo" \
--description="This is the demo project with OpenShift" \
--admin=demo
```

This command creates a project:

 * with the id demo
 * with a display name
 * with a description
 * with an administrative user demo

```
oc get projects

NAME               DISPLAY NAME   STATUS
openshift                         Active
openshift-infra                   Active
default                           Active
demo                              Active
kube-system                       Active
logging                           Active
management-infra                  Active

oc get project demo

NAME      DISPLAY NAME     STATUS
demo      OpenShift Demo   Active
```

In OpenShift, a project is a Kubernetes namespace with additional annotations. Projects provide for easier multi tenancy than standard namespaces. Having stricter validation than namespaces, projects are actually indirectly created by the server by a request mechanism. Thus you do not need to give users the ability to create projects directly.

The project list is a special endpoint that determines what projects you should be able to see. This is not possible to express via RBAC authorizations, i.e. list namespaces means you can see all namespaces.

Now that we have a new project, login as demo user
```
su - demo 
oc login -u demo -p *********
Server [https://localhost:8443]:
...
Use insecure connections? (y/n): y
Login successful.
You have one project on this server: "demo"
Using project "demo".
```

The login process created a file called named ``~/.kube/config`` in the user home folder. This configuration file has an authorization token, some information about where our project lives:
```yaml
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://localhost:8443
  name: localhost:8443
contexts:
- context:
    cluster: localhost:8443
    namespace: demo
    user: demo/localhost:8443
  name: demo/localhost:8443/demo
current-context: demo/localhost:8443/demo
kind: Config
preferences: {}
users:
- name: demo/localhost:8443
  user:
    token: *********
```

## Create a pod
An application in OpenShift lives inside a pod. Here the file ``pod-hello-world.yaml`` containing the definition of our pod in yaml format:
```yaml
kind: Pod
apiVersion: v1
metadata:
  name: hello-pod
  labels:
    name: hello
spec:
  containers:
  - env:
    - name: MESSAGE
      value: "Hello OpenShift"
    name: hello
    image: docker.io/kalise/nodejs-web-app:latest
    ports:
    - containerPort: 8080
      protocol: TCP
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - mountPath: /var/log
      name: logs
    securityContext:
      privileged: false
      runAsUser: 1001250000
  restartPolicy: Always
  dnsPolicy: ClusterFirst
  volumes:
  - emptyDir: {}
    name: logs
  securityContext:
    fsGroup: 1001250000
```

As demo user, create the pod from the yaml file
```
oc create -f pod-hello-world.yaml
```

Check the status of the pod
```
oc get pods

NAME      READY     STATUS    RESTARTS   AGE
hello-pod 1/1       Running   0          1m

```

To verify that our application is really working, issue a curl to the pod's address and port:
```
curl 10.1.0.2:8080
```

## Create a service
Our simple Hello World application is a backed by a container inside a pod running on a single compute node. Pods can be added to or removed from a service arbitrarily while the service remains consistently available, enabling any client to refer the service by a consistent address. 

Define a service for our simple Hello World application in a ``service-hello-world.yaml`` file.

```yaml
kind: Service
apiVersion: v1
metadata:
  name: hello-world-service
  labels:
    name: hello
spec:
  selector:
    name: hello
  ports:
  - protocol: TCP
    port: 9000
    targetPort: 8080
```

As demo user, create the service

```
oc create -f service-hello-world.yaml
```

Check the status of the service
```
oc get service

NAME                  CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
hello-world-service   172.30.42.123   <none>        9000/TCP   5m
```

The service will act as an internal load balancer in order to proxy the connections it receives from the clients toward the pods bound to the service. The service also provide a name resolution for the associated pods. For example, in the case above, the hello pods can be reached by other pods in the same namespace by the name ``hello-world-service`` instead of the address:port ``172.30.42.123:9000``. This is very useful when we need to link different applications.

## Create a replica controller
A Replica Controller ensures that a specified number of pod *"replicas"* are running at any time. In other words, a Replica Controller makes sure that a pod or set of pods are always up and available. If there are too many pods, it will kill some; if there are too few, it will start more.

A Replica Controller configuration consists of:

 * The number of replicas desired
 * The pod definition
 * The selector to bind the managed pod

A selector is a label assigned to the pods that are managed by the replica controller. Labels are included in the pod definition that the replica controller instantiates. The replica controller uses the selector to determine how many instances of the pod are already running in order to adjust as needed.

In the ``rc-hello-world.yaml`` file, define a replica controller with replica 1.
```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: rc-hello
spec:
  replicas: 1
  selector:
    name: hello
  template:
    metadata:
      labels:
        name: hello
    spec:
      containers:
      - env:
        - name: MESSAGE
          value: "Hello OpenShift"
        name: hello
        image: docker.io/kalise/nodejs-web-app:latest
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        volumeMounts:
        - mountPath: /var/log
          name: logs
        securityContext:
          privileged: false
          runAsUser: 1001250000
      restartPolicy: Always
      dnsPolicy: ClusterFirst
      volumes:
      - emptyDir: {}
        name: logs
      securityContext:
        fsGroup: 1001250000
```

Create the Replica Controller
```
oc create -f rc-hello-world.yaml

oc get rc
NAME       DESIRED   CURRENT   READY     AGE
rc-hello   1         1         1         1m
```

We can see the pod just created
```
oc get pods

NAME             READY     STATUS    RESTARTS   AGE
rc-hello-ijc6g   1/1       Running   0          3m
```

When it comes to scale, there is a command called ``oc scale`` to get job done
```
oc scale rc rc-hello --replicas=2

oc get pods
NAME             READY     STATUS    RESTARTS   AGE
rc-hello-ijc6g   1/1       Running   0          6m
rc-hello-jnset   1/1       Running   0          9s
```

To scale down, just set the replicas
```
oc scale rc rc-hello --replicas=1

oc get pods
NAME             READY     STATUS    RESTARTS   AGE
rc-hello-ijc6g   1/1       Running   0          9m

oc scale rc rc-hello --replicas=0

oc get pods
No resources found.
```

## Create a Deployment
A Deployment provides declarative updates for pods and replicas. The Deployment object defines the strategy for transitioning between deployments of the same application.

In the ``deploy-hello-world.yaml`` file, define a deploy with Rolling Update strategy.
```yaml
kind: Deployment
metadata:
  generation: 1
  name: deploy-hello
  namespace:
spec:
  replicas: 3
  selector:
    matchLabels:
      name: hello
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: hello
    spec:
      containers:
      - env:
        - name: MESSAGE
          value: "Hello OpenShift"
        name: hello
        image: docker.io/kalise/nodejs-web-app:1.1
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        volumeMounts:
        - mountPath: /var/log
          name: logs
        securityContext:
          privileged: false
          runAsUser: 1001250000
      restartPolicy: Always
      dnsPolicy: ClusterFirst
      volumes:
      - emptyDir: {}
        name: logs
      securityContext:
        fsGroup: 1001250000
```

Create the Deployment

    oc create -f deploy-hello-world.yaml

    oc get deploy -o wide
    NAME           DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
    deploy-hello   3         3         3            3           14m

and check the pods created

    oc get pods 
    NAME                            READY     STATUS    RESTARTS   AGE
    deploy-hello-6564548567-4rtlg   1/1       Running   0          15m
    deploy-hello-6564548567-qfrn4   1/1       Running   0          6m
    deploy-hello-6564548567-tlsjx   1/1       Running   0          15m

We also can check the Replica Set created by the Deployment

    oc get rs -o wide
    NAME                     DESIRED CURRENT READY AGE CONTAINERS IMAGES                     SELECTOR
    deploy-hello-57db4fc656  3       3       3     2m  hello      kalise/nodejs-web-app:1.1  name=hello

To see the rolling update in action, modify the deploy to use a different version of the same image

    oc set image deploy deploy-hello hello=docker.io/kalise/nodejs-web-app:1.2
    deployment "deploy-hello" image updated

Now check the new Replica Set 

    oc get rs -o wide
    NAME                     DESIRED CURRENT READY AGE CONTAINERS IMAGES                     SELECTOR
    deploy-hello-57db4fc656  0       0       0     20m hello      kalise/nodejs-web-app:1.1  name=hello
    deploy-hello-68cdbc59f   3       3       3     3m  hello      kalise/nodejs-web-app:1.2  name=hello

and the new pods

    oc get pods
    NAME                           READY     STATUS    RESTARTS   AGE
    deploy-hello-68cdbc59f-gn44z   1/1       Running   0          5m
    deploy-hello-68cdbc59f-hqclv   1/1       Running   0          2m
    deploy-hello-68cdbc59f-rs8zc   1/1       Running   0          2m


## The Routing Layer
The OpenShift routing layer is how client traffic enters the OpenShift environment so that it can ultimately reach pods. In our Hello World example, the service abstraction defines a logical set of pods enabling clients to refer the service by a consistent address and port. However, our service is not reachable from external clients.

To get pods reachable from external clients we need for a Routing Layer. In a simplification of the process, the OpenShift Routing Layer consists in an instance of a pre-configured HAProxy running in a dedicated pod as well as the related services

The installation process installs a preconfigured router pod running on the master node. To see details, login as system admin
```
oc login -u system:admin
Logged into "https://master.openshift.com:8443" as "system:admin" using existing credentials.

oc project default
Now using project "default" on server "https://master.openshift.com:8443".

oc get pods
NAME                      READY     STATUS    RESTARTS   AGE
router-1-8pthc            1/1       Running   1          10d
...

oc get services
NAME              CLUSTER-IP       EXTERNAL-IP   PORT(S)                   AGE
router            172.30.201.143   <none>        80/TCP,443/TCP,1936/TCP   110d
...
```

### Expose the service
Please, note that the router is bound to ports 80 and 443 on the host interface. When the router receives a request for an FQDN that it knows about, it will proxy the request to a specific service and then to the running pod providing the service.

To get our router aware of the Hello World service, we need to create a route as ``route-hello-world.yaml`` file that instructs the router where to forward the requests. 
```yaml
kind: Route
apiVersion: v1
metadata:
  name: hello-route
  labels:
    name: hello
spec:
  host: hello-world.cloud.openshift.com
  to:
    name: hello-world-service
  tls:
    termination: edge
```
 
As demo user, login to the master and create the route
```
oc login -u demo -p demo123
Login successful.
You have one project on this server: "demo"
Using project "demo".

oc create -f route-hello-world.yaml

oc get route
NAME          HOST/PORT                         PATH      SERVICES              PORT      TERMINATION
hello-route   hello-world.cloud.openshift.com             hello-world-service   <all>     edge
```

Now our Hello World service is reachable from any client with its FQDN
```
curl https://hello-world.cloud.openshift.com -k
```

In the setup, we required a wildcard DNS entry to point at the master node ``*.cloud.openshift.com. 300 IN  A 10.10.10.19`` Our wildcard DNS entry points to the public IP address of the master. Since there is only the master in the infra region, we know we can point the wildcard DNS entry at the master and we'll be all set. Once the FQDN request reaches the router pod running on the master node, it will be forwarded to the pods on the compute nodes actually running the Hello World application.

The fowarding process is based on HAProxy configurations set by the route we defined before. To see the HAProxy configuration, login as root to the master node and inspect the router pod configuration
```
oc get pods
NAME                      READY     STATUS    RESTARTS   AGE
router-1-8pthc            1/1       Running   1          11d
...

oc rsh router-1-8pthc
sh-4.2$ pwd
/var/lib/haproxy/conf
sh-4.2$ ls -l haproxy.config
-rwxrwxrwx. 1 root root 10178 Jan 30 10:20 haproxy.config
sh-4.2$ cat haproxy.config
...
##-------------- app level backends ----------------
...
#server openshift_backend
  server 9945852405ae9517c 10.1.0.18:8080 check inter 5000ms cookie 9945852405ae9517c weight 100
  server 6283681187833cb3e 10.1.2.21:8080 check inter 5000ms cookie 6283681187833cb3e weight 100
```

## Projects administration
In OpenShift, projects are used to isolate resources from groups of developers. The platform user admin can give users access to certain projects, allow them to create their own project, and give them admin rights too. The user admin can set resource quotas and policies on a specific project.

As platfrom admin, login to the system and get the list of projects
```
oc login -u system:admin

oc get projects

NAME               DISPLAY NAME          STATUS
demo               OpenShift Demo        Active
kube-system                              Active
logging                                  Active
management-infra                         Active
openshift                                Active
openshift-infra                          Active
default                                  Active
[root@master ~]#
```

There are many projects in OpenShift, some are user projects like ``demo`` as we created before, the ``default`` project and other infrastructure projects. In this section, we'll focus on user projects.

## Project permissions
Create a new project and set the user ``sam`` as project administrator
```
oc adm new-project tomcat \
    --display-name="My New Cool Project" \
    --description="This is the coolest project in the town" \
    --admin=sam
```

Login as sam user and create a new pod in this project
```
oc login -u sam -p demo123

Server [https://localhost:8443]:
Login successful.

oc create -f pod-hello-world.yaml
pod "hello-pod" created

oc get pod
NAME        READY     STATUS    RESTARTS   AGE
hello-pod   1/1       Running   0          23s
```

As example of an administrative function, we want to let the user ``demo`` look at the ``tomcat`` project we just created. As system admin, set the tomcat project as current one and give to demo user the permission to view the tomcat project
```
oc project tomcat
Now using project "tomcat" on server "https://master.openshift.com:8443".

oc adm policy add-role-to-user view demo
```

Login as demo user, check the list of projects and set tomcat project as current project
```
oc login -u demo -p demo123

oc get project

NAME      DISPLAY NAME          STATUS
demo      OpenShift Demo        Active
tomcat    My New Cool Project   Active

oc project tomcat
Now using project "tomcat" on server "https://localhost:8443".

oc get pod
NAME        READY     STATUS    RESTARTS   AGE
hello-pod   1/1       Running   0          1m
```

However, demo user cannot make changes
```
oc delete pod hello-pod
Error from server: User "demo" cannot delete pods in project "tomcat"
```
The project admin (or the system admin) can give demo user the edit rights on tomcat project
```
oc project tomcat
Now using project "tomcat" on server "https://master.openshift.com:8443".

oc adm policy add-role-to-user edit demo
```

Finally, the demo user can make canges in tomcat project
```
oc delete pod hello-pod
pod "hello-pod" deleted

oc create -f pod-hello-world.yaml
pod "hello-pod" created
```

Also, the project admin (or the system admin) can give demo user the admin rights on tomcat project
```
oc adm policy add-role-to-user admin demo
```
