# The APIs Server
The API Server is the central touch point for a Kubernetes cluster that is accessed by all users. The API server implements a RESTful API over HTTP(S), it performs all API operations and is responsible for storing API objects into a persistent storage backend, i.e. the etcd kay-value distributed database.

## Accessing the APIs Server
There are many ways to access the API server through its RESTful interface. In this section, we'll see few.

### Accessing through a proxy
To make easy to explore the API server run the ``kubectl`` tool in proxy mode to expose an unauthenticated API server on ``localhost:8080`` using the following command:

    kubectl proxy --port=8080 &

Then you can explore the API with ``curl``, ``wget``, or a browser.

    curl http://localhost:8080/api/

### Accessing with a bearer token
Alternately, without the proxy, we need first to get a bearer token

    SECRET=$(kubectl get secrets | grep ^default | cut -f1 -d ' ')
    TOKEN=$(kubectl describe secret $SECRET | grep -E '^token' | cut -f2 -d':' | tr -d " ")

and then access the API Server on its listening port, i.e, ``apiserver:8443`` by default:

    curl https://apiserver:8443/api/ --header "Authorization: Bearer $TOKEN" -k

### Accessing with a certificate
To access as a specific user, we can use his own key-pair certificates. For example, to access as cluster admin, we need to have access to his certificates: ``admin-key.pem`` and ``admin.pem`` as well as the certification authority ``ca.pem``

    curl --key admin-key.pem \
         --cert admin.pem \
         --cacert ca.pem \
         https://apiserver:8443/api/ 

To simplify the usage of the ``curl`` command with certificates, create a configuration file ``curlrc`` as following

    $ cat .curlrc
    
    --key admin-key.pem
    --cert admin.pem
    --cacert ca.pem 

Now we can access the API server as

    curl --config curlrc https://apiserver:8443/api/ 

### Accessing from an application
We can also access the API Server from an application running in a pod by using its service account as in the following example.

Create an ephemeral pod from a ``curl`` image and login into

    kubectl run -it --rm curl --image=kalise/curl:latest /bin/sh

Oncle logged, find the service address and port of the API Server by checking the pod env variables

    / # env | grep KUBERNETES_SERVICE

    KUBERNETES_SERVICE_PORT=443
    KUBERNETES_SERVICE_HOST=10.32.0.1

To be authenticated by the API server, we need to use the service account token signed by the controller manager via the key specified ``--service-account-private-key-file`` option. This token is mounted as secret into each container and used by its service account

    / # TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

Once we have the token, we can access the API Server from within the pod

    / # curl https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/ \
             --header "Authorization: Bearer $TOKEN" -k

Now we can explore the API Server.

## Exploring the APIs Server
All Kubernetes requests begin with the the core APIs prefix ``/api/`` or with the grouped APIs prefix ``/apis/``. The two different sets of paths are primarily historical: API Groups did not originally exist in the Kubernetes API, so the original or core objects like Pods and Services are maintained under the core APIs without an API group. Subsequently, APIs have generally been added under API groups, so they follow the ``/apis/<api-group>/`` path.

For example, to get the list of pods

    curl http://127.0.0.1:8080/api/v1/pods

or services

    curl http://127.0.0.1:8080/api/v1/services

they are part of the core APIs.

The Deployment object is part of the app API group and it is found here

    http://127.0.0.1:8080/apis/apps/v1/deployments

An additional classification of resource paths is whether or not the resource is namespaced.

Here are the components of the two different paths for namespaced resource types

    http://<server>:<port>/api/v1/namespaces/<namespace>/<resource-type>/<resource>
    http://<server>:<port>/apis/<api-group>/<api-version>/namespaces/<namespace>/<resource-type>/<resource>

Here are the components of the two different paths for no namespaced resource types

    http://<server>:<port>/api/v1/<resource-type>/<resource>
    http://<server>:<port>/apis/<api-group>/<api-version>/<resource-type>/<resource>

For example, to get all the pods running in the ``kube-system`` namespace

    curl http://127.0.0.1:8080/api/v1/namespaces/kube-system/pods
    
To get a specific pod in the default namespace

    http://127.0.0.1:8080/api/v1/namespaces/default/pods/nginx

To get all the nodes

    curl http://127.0.0.1:8080/api/v1/nodes

because the node resource type is not namespaced.

Another grouping is based on the version of the API. For the core APIs group ``/api/`` there is only one, i.e. the ``/api/v1/`` where for the other APIs group there are many, e.g. ``/apis/<api-group>/v1``, ``/apis/<api-group>/v1beta1``, ``/apis/<api-group>/v1alpha1``, depending on the stability of the resource implementation. A particular release of Kubernetes may support multiple different versions: alpha, beta and GA for a given resource type.

In addition to the resource types themselves, there is much interesting information in the API object that describes the API itself, the so-called meta API object. For example, getting the core APIs 

    curl http://127.0.0.1:8080/api/v1/

check for the pods object

```json
    {
      "name": "pods",
      "singularName": "",
      "namespaced": true,
      "kind": "Pod",
      "verbs": [
        "create",
        "delete",
        "deletecollection",
        "get",
        "list",
        "patch",
        "update",
        "watch"
      ],
      "shortNames": [
        "po"
      ],
      "categories": [
        "all"
      ]
    }
```

Looking at this object, the ``name`` field provides the name of this resource. The ``namespaced`` field in the object description indicates if the object is namespaced or not. The ``Kind`` field provides the string that is present in the API object’s JSON representation to indicate what kind of object it is. The ``verbs`` field indicates what kind of actions can be taken on that object. The pods object contains all of the possible verbs: create, delete, get, list, and so on.

The watch verb indicates that we can establish a watch for the resource. A watch is long running operation which provides notifications about changes to the object.

For example, to watch notifications from pods we can add the query parameter ``?watch=true`` to an API server request

    curl http://127.0.0.1:8080/api/v1/namespaces/default/pods?watch=true

The API server switches into watch mode, and it leaves the connection between client and server open.

The data returned by the API server is no longer just the API object, it is a different object which contains both the type of the change, e.g. created, modified, deleted, as well as the API object itself. In this way a client can watch and observe all changes to that object, or set of objects instead of polling at some interval for possible updates, which introduces load and latency.

## API Aggregation
The aggregation layer allows Kubernetes to be extended with additional APIs, beyond what is offered by default. It enables installing additional Kubernetes-style APIs in the cluster. These can either be pre-built, existing 3rd party solutions, such as a service-catalog, or user-created APIs servers. They can either run as pods in the same kubernetes cluster or run as standalone services.

For example, the metric-server is deployed as stand-alone APIs service running as pod in kube-system namespace

    kubectl get pods -n kube-system
    NAME                              READY     STATUS    RESTARTS   AGE
    kube-dns-598d7bf7d4-bn9pq         3/3       Running   0          17d
    metrics-server-86bd9d7667-mx9jp   1/1       Running   0          10d

## Custom Resources
Kubernetes APIs server can be extended by defining custom resources. To define a new resource type, we need to post a **Custom Resource Definition** object or **CRD** to the APIs server. The CRD object is the description of the custom resource type. Once the CRD is posted, we can then create instances of the custom resource by posting JSON or YAML manifests to the API server, the same we do with any other Kubernetes resource.

In this section, we want to allow users of kubernetes cluster to run static websites as easily as possible, without having to deal with pods, services, and other Kubernetes resources. What we want to achieve is for users to create objects of type Website that contain nothing more than the website’s name and the source Git repository from which the website’s
files should be obtained.

When a user creates an instance of the Website resource, we want the cluster to spin up a new webserver deployment, a volume pointing to the Git reposistory, a configmap and expose it to the external through a service.

To make Kubernetew aware of a new custom resource type, we need to create the related CRD as in the following ``website-crd.yaml`` definition file

```yaml
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  # name must match the spec fields below, and be in the form: <plural>.<group>
  name: websites.kubeo.clastix.io
spec:
  # either Namespaced or Cluster
  scope: Namespaced
  # group name to use for REST API: /apis/<group>/<version>
  group: kubeo.clastix.io
  # multiple versions of the same API can be served at same type
  versions:
    - name: v1
      served: true
      storage: true
    - name: v1beta1
      served: true
      storage: false      
    - name: v1alfa2
      served: false
      storage: false
  names:
    kind: Website
    singular: website
    plural: websites
    shortNames:
    - ws
  subresources:
    status:
    scale:
      specReplicasPath: .spec.replicas
      statusReplicasPath: .status.replicas
  validation:
    # openAPIV3Schema is the schema for validating custom objects.
    openAPIV3Schema:
      properties:
        spec:
          properties:
            gitRepo:
              type: string
            serviceType:
              type: string
            configType:
              type: string
            replicas:
              type: integer
              minimum: 0
              maximum: 9
  additionalPrinterColumns:
    - name: podReplicas
      type: integer
      description: The number of pods running
      JSONPath: .spec.replicas
    - name: ServiceType
      type: string
      description: How the website is exposed to the external
      JSONPath: .spec.serviceType
    - name: gitRepo
      type: string
      description: The Git repo where config files are stored
      JSONPath: .spec.gitRepo
    - name: ConfigType
      type: string
      description: How configurations are passed to pods
      JSONPath: .spec.configType      
    - name: Age
      type: date
      description: Creation timestamp
      JSONPath: .metadata.creationTimestamp
```

Create the resource definition

    kubectl apply -f website-crd.yaml

Custom Resources Definitions are no namespaced objects and can be retrieved as any other kubernetes object

    kubectl get crd

    NAME                        CREATED AT
    websites.kubeo.clastix.io   2018-08-09T14:17:58Z

After we post the descriptor to Kubernetes, it will allow us to create any number of instances of the custom Website resource. For example, create a new website as in the following ``website.yaml`` descriptor file

```
apiVersion: "kubeo.clastix.io/v1"
kind: Website
metadata:
  namespace:
  name: kubia01
  labels:
spec:
  replicas: 3
  serviceType: LoadBalancer
  gitRepo: https://github.com/kalise/kubia.git
  configType: ConfigMap
```

Create a new website

    kubectl apply -f website.yaml

The custom resources can be retrieved as any other kubernetes default object

    kubectl get websites
    NAME      PODREPLICAS   SERVICETYPE    GITREPO                               CONFIGTYPE   AGE
    kubia01   3             LoadBalancer   https://github.com/kalise/kubia.git   ConfigMap    5m

According to its semantic, a custom resource can be scaled. In our case we can scale up to 9 pod replicas since the hard limits we set inthe custom resouce definition


    kubectl scale website kubia01 --replicas=9

    kubectl get websites

    NAME      PODREPLICAS   SERVICETYPE    GITREPO                               CONFIGTYPE   AGE
    kubia01   9             LoadBalancer   https://github.com/kalise/kubia.git   ConfigMap    8m

However, creating a CRD so that users can create objects of the new type is unuseful if those objects don’t make something tangible happening in the cluster. In our case, the website we just created, only is an object stored into etcd and it is not running anything.

To make this an useful feature, each custom resource definition needs an associated controller, i.e. an active component doing something on the worker nodes, basing on the custom objects, the same way that all the core Kubernetes resources have an associated controller.

Writing a new controller for custom resources is not an easy task, unless we use some special frameworks built for this scope. 

## The Operator framework
