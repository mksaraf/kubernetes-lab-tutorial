# Ingress
In kubernetes, user applications are made public by creating a service on a given port and a load balancer on top of the cluster for each application to expose. For example, a request for *myservice.mysite.com* will be balanced across worker nodes and then routed to the related service exposed on a given port by the kube proxy. An external load balancer is required for each service to expose. This can get rather expensive especially when on a public cloud.

Ingress gives the cluster admin a different way to route requests to services by centralizing multiple services into a single external load balancer. An ingress is split up into two main pieces: the first is an **Ingress Resource**, which defines how you want requests routed to the backing services. The second is an **Ingress Controller**, which listen to the kubernetes API for Ingress Resource creation and then handle requests that match them. Ingress Controllers can technically be any system capable of reverse proxying, but the most common options are Nginx and HAProxy. As additional component, a **Default Backend** service can be used to handle all requests that are no service relates, eg. *Not Found (404)* error page.

## Ingress Resource
An ingress resource is a kubernetes abstraction to handle requests, for example to *web.mysite.com* and *blog.mysite.com* and then route them to the kubernetes services named website and blog respectively.

A file definition ``mysite-ingress.yaml`` for the Ingress resource above looks like the following

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: noverit.com
spec:
  rules:
  - host: web.noverit.com
    http:
      paths:
      - path: /
        backend:
          serviceName: website
          servicePort: 80

  - host: blog.noverit.com
    http:
      paths:
      - path: /
        backend:
          serviceName: blog
          servicePort: 80
```

Before to create an Ingress, define a simple web server application listening on http port, as in the following ``mysite.yaml`` configuration file

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: mysite
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: mysite
    spec:
      containers:
      - name: mysite
        image: gcr.io/google_containers/echoserver:1.8
        ports:
        - containerPort: 80
```

Create the application as replica controller
```bash
kubectl create -f mysite.yaml
```

Then define two different internal services pointing to the same application above, as in the ``mysite-svc.yaml`` configuration file
```yaml
apiVersion: v1
kind: Service
metadata:
  name: website
  labels:
    app: website
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: website
  selector:
    app: mysite

---
apiVersion: v1
kind: Service
metadata:
  name: blog
  labels:
    app: blog
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: blog
  selector:
    app: mysite
```

Please, note the services above are defined as type of ``ClusterIP`` and then they are not exposed to the external. This is required since the Ingress will configure the cluster to route requests to the services without passing through the kube proxy. 

Create the services
```bash
kubectl create -f mysite-svc.yaml
```

Create the ingress
```bash
kubectl create -f mysite-ingress.yaml
```

Check and inspect the ingress
```bash
kubectl get ingress -o wide
NAME          HOSTS                              ADDRESS   PORTS     AGE
noverit.com   web.noverit.com,blog.noverit.com             80        24m
```

However, an Ingress resource on it’s own does not do anything. An Ingress Controller is required to route requests to the service.

## Ingress Controller
The Ingress Controller is the component that routes the requests to the services. It is listening to the kubernetes API for an ingress creation and then handle requests. Ingress Controllers can technically be any system capable of reverse proxying, but the most common options are Nginx and HAProxy.

Before to create an Ingress Controller, we are going to create a default backend service for the Ingress Controller itself. This backend service will reply to all requests that are not related to our services, for example requests for unknown url.

### Default Backend
Create the backend and related service from the file ``ingress-default-backend.yaml`` available [here](../examples/ingress-default-backend.yaml)
```bash
kubectl create -f ingress-default-backend.yaml
```

The template above, will create a replica controller and the related internal service in the ``kube-system`` namespace.
```bash
kubectl get all -l run=ingress-default-backend
NAME                               READY     STATUS    RESTARTS   AGE
po/ingress-default-backend-hd5pv   1/1       Running   0          1m

NAME                         DESIRED   CURRENT   READY     AGE
rc/ingress-default-backend   1         1         1         1m

NAME                          CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
svc/ingress-default-backend   10.32.156.148   <none>        8080/TCP   1m
```

Please, note that the ingress default backend service is an internal service ``type: ClusterIP`` and therefore, it is not exposed.

### HAProxy as Ingress Controller
THe HAProxy is capable to act as reverse proxy to route requests from an external load balancer directly to the pods providing the service. To configure an HAProxy Ingress Controller, create first an HAProxy deploy form the ``haproxy-ingress-controller-deploy.yaml`` available [here](../examples/haproxy-ingress-controller-deploy.yaml) and then the related service from the file ``haproxy-ingress-controller-svc.yaml`` available [here](../examples/haproxy-ingress-controller-svc.yaml).

Assuming we want to handle TLS requests, the Ingress Controller needs to have a default TLS certificate. This will be used for requests where is not specified TLS certificate. Assuming we have a certificate and key, ``tsl.crt`` and ``tsl.key``, respectively, create a secrets as follow
```bash
kubectl -n kube-system create secret tls tls-certificate --key tls.key --cert tls.crt
```

Create the deploy and the service 
```bash
kubectl create -f haproxy-ingress-controller-deploy.yaml
kubectl create -f haproxy-ingress-controller-svc.yaml
```

The templates above, will create a deploy and the related service in the ``kube-system`` namespace.
```bash
kubectl get all -l run=haproxy-ingress-controller
NAME                                             READY     STATUS    RESTARTS   AGE
po/haproxy-ingress-controller-4130110709-2lzbv   1/1       Running   0          19s

NAME                             CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
svc/haproxy-ingress-controller   10.32.245.104   <nodes>       80:30080/TCP..   4h

NAME                                DESIRED   CURRENT   UP-TO-DATE   AVAILABLE  AGE
deploy/haproxy-ingress-controller   1         1         1            1          4h

NAME                                       DESIRED   CURRENT   READY            AGE
rs/haproxy-ingress-controller-4130110709   1         1         1                4h
```

Please, note that the ingress controller service is exposed service ``type: NodePort`` and therefore, it is accessible through the kube proxy.

Having created the Ingress resource, the Ingress Controller is now able to forward requests from the kube proxy directly to the pods running your application
```bash
curl -i kubew03:30080 -H 'Host: web.noverit.com'

HTTP/1.1 200 OK
Date: Mon, 25 Sep 2017 00:11:37 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Server: echoserver
```

And
```bash
curl -i kubew03:30080 -H 'Host: web.noverit.com'

HTTP/1.1 200 OK
Date: Mon, 25 Sep 2017 00:13:27 GMT
Content-Type: text/plain
Transfer-Encoding: chunked
Server: echoserver
```

Unknown requests will be redirected to the default backend service
```bash
curl -i kubew03:30080 -H 'Host: foo.noverit.com'

HTTP/1.1 404 Not Found
Date: Mon, 25 Sep 2017 00:14:43 GMT
Content-Length: 21
Content-Type: text/plain; charset=utf-8
default backend - 404
```

An Ingress Controller can be deployed also as Daemon Set resulting an HAProxy instance for each worker node in the cluster. The daemon set definition file ``haproxy-ingress-controller-daemonset.yaml`` can be found [here](../examples/haproxy-ingress-controller-daemonset.yaml). Remove the deploy and create the daemon set in the ``kube-system`` namespace
```bash
kubectl delete deploy haproxy-ingress-controller

kubectl create -f haproxy-ingress-controller-daemonset.yaml

kubectl get pods -l run=haproxy-ingress-controller -o wide
NAME                               READY     STATUS    RESTARTS   AGE       IP           NODE
haproxy-ingress-controller-7qjjf   1/1       Running   0          38s       10.38.3.49   kubew03
haproxy-ingress-controller-c3nd9   1/1       Running   0          38s       10.38.5.36   kubew05
haproxy-ingress-controller-nf1xj   1/1       Running   0          38s       10.38.4.53   kubew04
```

### NGINX as Ingress Controller
The Nginx webserver is also able to run as Inngress Controller for kubernetes services. To configure an Nginx Ingress Controller, create first an an nginx deploy form the ``nginx-ingress-controller-deploy.yaml`` available [here](../examples/nginx-ingress-controller-deploy.yaml) and then the related service from the file ``nginx-ingress-controller-svc.yaml`` available [here](../examples/nginx-ingress-controller-svc.yaml).

### TLS Termination
An Ingress Controller is able to terminate secure TLS sessions and redirect requests to insecure HTTP applications running on the cluster. To configure TLS termination for user application, create a secret with certification and key in the user namespace pay attention to the **Common Name** used for the service.

For the web service
```
openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout web-tls.key \
    -out web-tls.crt \
    -subj "/CN=web.noverit.com"

kubectl create secret tls web-tls-secret --cert=web-tls.crt --key=web-tls.key
```

And for the blog service
```
openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout blog-tls.key \
    -out blog-tls.crt \
    -subj "/CN=blog.noverit.com"

kubectl create secret tls blog-tls-secret --cert=blog-tls.crt --key=blog-tls.key
```

Create a configuration file ``mysite-ingress-tls.yaml`` as ingress for TLS termination
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: noverit.com
spec:
  tls:
  - hosts:
    - web.noverit.com
    secretName: web-tls-secret
  - hosts:
    - blog.noverit.com
    secretName: blog-tls-secret
  rules:
  - host: web.noverit.com
    http:
      paths:
      - path: /
        backend:
          serviceName: website
          servicePort: 80

  - host: blog.noverit.com
    http:
      paths:
      - path: /
        backend:
          serviceName: blog
          servicePort: 80
```

Create the ingress in the user namespace
```
kubectl create -f mysite-ingress-tls.yaml
```

