# Ingress
In kubernetes, user applications are made public by creating a service on a given port and a load balancer on top of the cluster for each application to expose. For example, a request for *https://myservice.domain.com:443* will be balanced across worker nodes and then routed to the related service exposed on a given port by the kube proxy. An external load balancer is required for each service to expose. This can get rather expensive especially when on a public cloud.

Ingress gives the cluster admin a different way to route requests to services by centralizing multiple services into a single external load balancer. An ingress is split up into two main pieces: the first is an Ingress Resource, which defines how you want requests routed to the backing services. The second is an Ingress Controller, which listen to the kubernetes API for Ingress Resource creation and then handle requests that match them. Ingress Controllers can technically be any system capable of reverse proxying, but the most common options are Nginx and HAProxy. As additional component, a default backend service can be used to handle all requests that are no service relates, eg. Not Fould (404) error page.

## Ingress Resource

## Ingress Controller

