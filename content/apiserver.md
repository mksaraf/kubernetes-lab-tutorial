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

We can also access the API Server from a pod by using its service account as in the following example.

Create an ephemeral pod from a ``curl`` image and login into

    kubectl run -it --rm curl --image=kalise/curl:latest /bin/sh

Oncle logged, find the service address and port of the API Server by checking the pod env variables

    / # env | grep KUBERNETES_SERVICE

    KUBERNETES_SERVICE_PORT=443
    KUBERNETES_SERVICE_HOST=10.32.0.1

To be authenticated by the API server, we need to use the service account token signed by the controller manager via the key specified ``--service-account-private-key-file`` option. This token is mounted as secret into each container and used by its service account

    / # TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

Once we have the token, we can access the API Server from within the pod

    / # curl https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/ --header "Authorization: Bearer $TOKEN" -k

Now we can browse the API Server.

## Exploring APIs Server 

## API Aggregation

## Custom Resources

## The Operator framework
