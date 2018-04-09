# Getting started with OpenShift
It is now time to create the **Hello World** application using some sample code. It is simple http server written in nodejs returning a greating message as contained into the MESSAGE env variable. The application is available as Docker image and the source code is [here](https://github.com/kalise/nodejs-web-app).

## Create a demo user
OpenShift platform supports a number of mechanisms for authentication. The simplest use case for testing purposes is htpasswd-based authentication. To start, we will need the ``htpasswd`` binary on the Master node

```
[root@master ~]# yum -y install httpd-tools
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
[root@master ~]# useradd demo
[root@master ~]# passwd demo
[root@master ~]# touch /etc/htpasswd
[root@master ~]# htpasswd -b /etc/htpasswd demo *********
```

Login to the OpenShift platform as demo user by the ``oc`` CLI command
```
[root@master ~]# oc login -u demo -p ********
Login successful.
You don't have any projects. You can try to create a new project, by running
oc new-project <projectname>
```

## Create a demo project
The OpenShift platform has the concept of "projects" to contain a number of different resources. We'll explore what this means in more details throughout the rest of the tutorial. Create a demo project for our first application.

The default configuration for CLI operations currently is to be the ``system:admin`` passwordless user, which is allowed to create projects. Login as admin user:
```
[root@master ~]# oc login -u system:admin
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

We can use the admin OpenShift ``oadm`` command to create a project, and assign an administrative user to it.

As the root system user on master:
```
oadm new-project demo \
--display-name="OpenShift Demo" \
--description="This is the first demo project with OpenShift" \
--admin=demo
```

This command creates a project:

 * with the id demo
 * with a display name
 * with a description
 * with an administrative user demo

```
[root@master ~]# oc get projects
NAME               DISPLAY NAME   STATUS
openshift                         Active
openshift-infra                   Active
default                           Active
demo                              Active
kube-system                       Active
logging                           Active
management-infra                  Active

[root@master ~]# oc get project demo
NAME      DISPLAY NAME     STATUS
demo      OpenShift Demo   Active

[root@master ~]# oc describe project demo
Name:                   demo
Namespace:              <none>
Created:                8 seconds ago
Labels:                 <none>
Annotations:            openshift.io/description=This is the first demo project with OpenShift
                        openshift.io/display-name=OpenShift Demo
Display Name:           OpenShift Demo
Description:            This is the first demo project with OpenShift
Status:                 Active
Node Selector:          <none>
Quota:                  <none>
Resource limits:        <none>
```

Now that we have a new project, login as demo user
```
[root@master ~]# su - demo 
[demo@master ~]$ oc login -u demo -p *********
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
An application in OpenShift live inside an entity called **"pod"**. Here the file ``pod-hello-world.yaml`` containing the definition of our pod in yaml format:
```yaml
---
kind: Pod
apiVersion: v1
metadata:
  name: hello-pod
  creationTimestamp:
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
    terminationMessagePath: "/dev/termination-log"
    imagePullPolicy: IfNotPresent
    securityContext:
      privileged: false
  restartPolicy: Always
  dnsPolicy: ClusterFirst
  serviceAccount: ''
status: {}
```

As demo user, create the pod from the yaml file
```
[demo@master ~]$ oc create -f pod-hello-world.yaml
pod "hello-pod" created
```

Check the status of the pod
```
[demo@master ~]$ oc get pods
NAME      READY     STATUS    RESTARTS   AGE
hello-pod 1/1       Running   0          1m

[demo@master ~]$ oc describe pod hello-pod
Name:                   hello-pod
Namespace:              demo
Security Policy:        restricted
Node:                   nodeb.openshift.com/10.10.10.17
Start Time:             Sat, 28 Jan 2017 12:36:29 +0100
Labels:                 name=hello
Status:                 Running
IP:                     10.1.0.2
Controllers:            <none>
Containers:
  hello:
    Container ID:       docker://8d4dc403d6597c2d2ccafeb45f684e37e789fcd32b43f35704a70e59cfdb2d24
    Image:              openshift/hello-openshift:latest
    Image ID:           docker-pullable://docker.io/openshift/hello-openshift
    Port:               8080/TCP
    State:              Running
      Started:          Sat, 28 Jan 2017 12:38:08 +0100
    Ready:              True
    Restart Count:      0
    Volume Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-56m1i (ro)
    Environment Variables:      <none>

Conditions:
...
Volumes:
...
QoS Class:      BestEffort
Tolerations:    <none>
Events:
...
```

To verify that our application is really working, issue a curl to the pod's address and port:
```
[demo@master ~]$ curl 10.1.0.2:8080
Hello OpenShift!
```

Login to the node where our pod is running, i.e. ``nodeb.openshift.com/10.10.10.17`` and check the containers running on that host

```
[root@nodeb ~]# docker ps
CONTAINER ID   IMAGE                                    COMMAND       CREATED          STATUS      PORTS  NAMES
8d4dc403d659   docker.io/kalise/nodejs-web-app:latest   "npm start"   12 minutes ago   Up 12 min   ...    ...
f867f09e8639   openshift3/ose-pod:v3.4.0.39             "/pod"        12 minutes ago   Up 12 min   ...    ...
```
Our application is running inside the first container from the ``docker.io/kalise/nodejs-web-app:latest`` image. The second container from the ``openshift3/ose-pod`` container exists because of the way network namespacing works in OpenShift.

Finally, delete the pod
```
[demo@master ~]$ oc delete pod hello-pod
pod "hello-pod" deleted
```

## Create a service
Our simple Hello World application is a backed by a container inside a pod running on a single compute node. The OpenShift platform introduces the concept of **"service"**. A service in OpenShift is an abstraction which defines a logical set of pods. Pods can be added to or removed from a service arbitrarily while the service remains consistently available, enabling any client to refer the service by a consistent address:port couple. 

Define a service for our simple Hello World application in a ``service-hello-world.yaml`` file.
```yaml
---
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
The above service is associated to our previous Hello World pod. Pay attention to the service selector field. It tells OpenShift that all pods with the label ``hello`` are associated to this service, and should have traffic distributed amongst them. In other words, the service provides an abstraction layer, and is the input point to reach all of the pods. 

As demo user, create the service
```
[demo@master ~]$ oc create -f service-hello-world.yaml
service "hello-world-service" created
pod "hello-pod" created
```

Check the status of the service
```
[demo@master ~]$ oc get service
NAME                  CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
hello-world-service   172.30.42.123   <none>        9000/TCP   5m

[demo@master ~]$ oc describe service hello-world-service
Name:                   hello-world-service
Namespace:              demo
Labels:                 name=hello
Selector:               name=hello
Type:                   ClusterIP
IP:                     172.30.42.123
Port:                   <unset> 9000/TCP
Endpoints:              <none>
Session Affinity:       None
No events.
```

Pods can be added to the service arbitrarily. Make sure that the selector label ``hello`` is in the definition yaml file of any pod we would to bind to the service.
```
[demo@master ~]$ oc create -f pod-hello-world.yaml
pod "hello-pod" created

[demo@master ~]$ oc create -f pod1-hello-world.yaml
pod "hello-pod1" created

[demo@master ~]$ oc describe service hello-world-service
Name:                   hello-world-service
Namespace:              demo
Labels:                 name=hello
Selector:               name=hello
Type:                   ClusterIP
IP:                     172.30.42.123
Port:                   <unset> 9000/TCP
Endpoints:              10.1.0.11:8080,10.1.2.11:8080
Session Affinity:       None
No events.
```

The service will act as an internal load balancer in order to proxy the connections it receives from the clients toward the pods bound to the service. We can check if the service is reaching our application
```
[demo@master ~]$ curl 172.30.42.123:9000
Hello OpenShift!
```

The service also provide a name resolution for the associated pods. For example, in the case above, the hello pods can be reached by other pods in the same namespace by the name ``hello-world-service`` instead of the address:port ``172.30.42.123:9000``. This is very useful when we need to link different applications.

## Create a replica controller
Manually created pods as we made above are not replaced if they get failed, deleted or terminated for some reason. To make things more robust, OpenShift introduces the **Replica Controller** abstraction. A Replica Controller ensures that a specified number of pod *"replicas"* are running at any time. In other words, a Replica Controller makes sure that a pod or set of pods are always up and available. If there are too many pods, it will kill some; if there are too few, it will start more.

A Replica Controller configuration consists of:

 * The number of replicas desired
 * The pod definition
 * The selector to bind the managed pod

A selector is a label assigned to the pods that are managed by the replica controller. Labels are included in the pod definition that the replica controller instantiates. The replica controller uses the selector to determine how many instances of the pod are already running in order to adjust as needed.

In the ``rc-hello-world.yaml`` file, define a replica controller with replica 1.
```yaml
---
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
      creationTimestamp:
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
        terminationMessagePath: "/dev/termination-log"
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: false
        livenessProbe:
          tcpSocket:
            port: 8080
          timeoutSeconds: 1
          initialDelaySeconds: 10
      restartPolicy: Always
      dnsPolicy: ClusterFirst
      serviceAccount: ''
      nodeSelector:
        region: primary
```

Create a Replica Controller
```
[demo@master ~]$ oc create -f rc-hello-world.yaml
replicationcontroller "rc-hello" created

[demo@master ~]$ oc get rc
NAME       DESIRED   CURRENT   READY     AGE
rc-hello   1         1         1         1m

[demo@master ~]$ oc describe rc rc-hello
Name:           rc-hello
Namespace:      demo
Image(s):       docker.io/kalise/nodejs-web-app:latest
Selector:       name=hello
Labels:         name=hello
Replicas:       1 current / 1 desired
Pods Status:    1 Running / 0 Waiting / 0 Succeeded / 0 Failed
No volumes.
Events:
```

We can see the pod just created
```
[demo@master ~]$ oc get pods
NAME             READY     STATUS    RESTARTS   AGE
rc-hello-ijc6g   1/1       Running   0          3m
```

When it comes to scale, there is a command called ``oc scale`` to get job done
```
[demo@master ~]$ oc scale rc rc-hello --replicas=2
replicationcontroller "rc-hello" scaled

[demo@master ~]$ oc get pods
NAME             READY     STATUS    RESTARTS   AGE
rc-hello-ijc6g   1/1       Running   0          6m
rc-hello-jnset   1/1       Running   0          9s
```

To scale down, just set the replicas
```
[demo@master ~]$ oc scale rc rc-hello --replicas=1
replicationcontroller "rc-hello" scaled

[demo@master ~]$ oc get pods
NAME             READY     STATUS    RESTARTS   AGE
rc-hello-ijc6g   1/1       Running   0          9m

[demo@master ~]$ oc scale rc rc-hello --replicas=0
replicationcontroller "rc-hello" scaled

[demo@master ~]$ oc get pods
No resources found.
```

Please note that the Replica Controller does not autoscale. This job is done by a metering service by piloting the Replica Controller, based on memory and cpu load or other criteria.

## The Routing Layer
The OpenShift routing layer is how client traffic enters the OpenShift environment so that it can ultimately reach pods. In our Hello World example, the service abstraction defines a logical set of pods enabling clients to refer the service by a consistent address and port. Howewer, our service is not reachable from external clients.

To get pods reachable from external clients we need for a Routing Layer. In a simplification of the process, the OpenShift Routing Layer consists in an instance of a pre-configured HAProxy running in a dedicated pod as well as the related services

Strarting from latest OpenShift release, the installation process install a preconfigured router pod running on the master node. To see details, login as system admin
```
[root@master ~]# oc login -u system:admin
Logged into "https://master.openshift.com:8443" as "system:admin" using existing credentials.

[root@master ~]# oc project default
Now using project "default" on server "https://master.openshift.com:8443".

[root@master ~]# oc get pods
NAME                      READY     STATUS    RESTARTS   AGE
router-1-8pthc            1/1       Running   1          10d
...

[root@master ~]# oc get services
NAME              CLUSTER-IP       EXTERNAL-IP   PORT(S)                   AGE
router            172.30.201.143   <none>        80/TCP,443/TCP,1936/TCP   110d
...
```

Describe the router pod, and see that it is running on the master node
```
[root@master ~]# oc describe pod router-1-8pthc
Name:                   router-1-8pthc
Namespace:              default
Security Policy:        hostnetwork
Node:                   master.openshift.com/10.10.10.19
Start Time:             Thu, 19 Jan 2017 16:22:13 +0100
Labels:                 deployment=router-1
                        deploymentconfig=router
                        router=router
Status:                 Running
IP:                     10.10.10.19
Controllers:            ReplicationController/router-1
Containers:
  router:
    Container ID:       docker://ae58e353155ef37042baa
    Image:              openshift3/ose-haproxy-router:v3.3.0.34
    Image ID:           docker://sha256:bd71278b612ca8
    Ports:              80/TCP, 443/TCP, 1936/TCP
    Requests:
      cpu:              100m
      memory:           256Mi
    State:              Running
...
```

### Expose the service
Please, note that the router is bound to ports 80 and 443 on the host interface. When the router receives a request for an FQDN that it knows about, it will proxy the request to a specific service and then to the running pod providing the service.

To get our router aware of the Hello World service, we need to create a route as ``route-hello-world.yaml`` file that instructs the router where to forward the requests. 
```yaml
---
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
[demo@master ~]$ oc login -u demo -p demo123
Login successful.
You have one project on this server: "demo"
Using project "demo".

[demo@master ~]$ oc create -f route-hello-world.yaml
route "hello-route" created

[demo@master ~]$ oc get route
NAME          HOST/PORT                         PATH      SERVICES              PORT      TERMINATION
hello-route   hello-world.cloud.openshift.com             hello-world-service   <all>     edge
```

Now our Hello World service is reachable from any client with its FQDN
```
[root@master]# curl https://hello-world.cloud.openshift.com -k
Hello OpenShift!
```

In the setup, we required a wildcard DNS entry to point at the master node ``*.cloud.openshift.com. 300 IN  A 10.10.10.19`` Our wildcard DNS entry points to the public IP address of the master. Since there is only the master in the infra region, we know we can point the wildcard DNS entry at the master and we'll be all set. Once the FQDN request reaches the router pod running on the master node, it will be forwarded to the pods on the compute nodes actually running the Hello World application.

The fowarding process is based on HAProxy configurations set by the route we defined before. To see the HAProxy configuration, login as root to the master node and inspect the router pod configuration
```
[root@master ~]# oc get pods
NAME                      READY     STATUS    RESTARTS   AGE
router-1-8pthc            1/1       Running   1          11d
...
[root@master ~]# oc rsh router-1-8pthc
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
[root@master ~]# oc login -u system:admin

[root@master ~]# oc get projects
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
[root@master ~]# oadm new-project tomcat \
    --display-name="My New Cool Project" \
    --description="This is the coolest project in the town" \
    --admin=sam
Created project tomcat
```

Login as sam user and create a new pod in this project
```
[root@master ~]# su - sam
[sam@master ~]$ oc login -u sam -p demo123
Server [https://localhost:8443]:
Login successful.
You have one project on this server: "tomcat"
Using project "tomcat".
Welcome! See 'oc help' to get started.
[sam@master ~]$

[sam@master ~]$ oc create -f pod-hello-world.yaml
pod "hello-pod" created

[sam@master ~]$ oc get pod
NAME        READY     STATUS    RESTARTS   AGE
hello-pod   1/1       Running   0          23s
```

As example of an administrative function, we want to let the user ``demo`` look at the ``tomcat`` project we just created. As system admin, set the tomcat project as current one and give to demo user the permission to view the tomcat project
```
[root@master ~]# oc project tomcat
Now using project "tomcat" on server "https://master.openshift.com:8443".

[root@master ~]# oadm policy add-role-to-user view demo
```

Login as demo user, check the list of projects and set tomcat project as current project
```
[demo@master ~]$ oc login -u demo -p demo123

[demo@master ~]$ oc get project
NAME      DISPLAY NAME          STATUS
demo      OpenShift Demo        Active
tomcat    My New Cool Project   Active

[demo@master ~]$ oc project tomcat
Now using project "tomcat" on server "https://localhost:8443".

[demo@master ~]$ oc get pod
NAME        READY     STATUS    RESTARTS   AGE
hello-pod   1/1       Running   0          1m
```

However, demo user cannot make changes
```
[demo@master ~]$ oc delete pod hello-pod
Error from server: User "demo" cannot delete pods in project "tomcat"
```

Howewer, the project admin (or the system admin) can give demo user the edit rights on tomcat project
```
[root@master ~]# oc project tomcat
Now using project "tomcat" on server "https://master.openshift.com:8443".

[root@master ~]# oadm policy add-role-to-user edit demo
```

Finally, the demo user can make canges in tomcat project
```
[demo@master ~]$ oc delete pod hello-pod
pod "hello-pod" deleted
[demo@master ~]$ oc create -f pod-hello-world.yaml
pod "hello-pod" created
```

Also, the project admin (or the system admin) can give demo user the admin rights on tomcat project
```
[root@master ~]# oadm policy add-role-to-user admin demo
```
