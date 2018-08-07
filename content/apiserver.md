# The APIs Server
The API Server is the central touch point for a Kubernetes cluster that is accessed by all users. The API server implements a RESTful API over HTTP(S), it performs all API operations and is responsible for storing API objects into a persistent storage backend, i.e. the etcd kay-value distributed database.

## Accessing the APIs Server
To make easy to explore the API server through its RESTful interface, run the ``kubectl`` tool in proxy mode to expose an unauthenticated API server on ``localhost:8080`` using the following command:

    kubectl proxy --port=8080 &

Then you can explore the API with ``curl``, ``wget``, or a browser.

    curl http://localhost:8080/api/

Alternately, without the proxy, we need first to get the bearer token

    SECRET=$(kubectl get secrets | grep ^default | cut -f1 -d ' ')
    TOKEN=$(kubectl describe secret $SECRET | grep -E '^token' | cut -f2 -d':' | tr -d " ")

and then access the API Server on its listening port, i.e, ``apiserver:8443`` by default:

    curl https://apiserver:8443/api/ --header "Authorization: Bearer $TOKEN" -k

We can also access the API Server from a pod by using its service account




### Accessing from client

### Accessing from appplication

### Accessing from proxy

## Exploring APIs Server 

## API Aggregation

## Custom Resources

## The Operator framework
