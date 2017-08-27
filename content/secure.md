# Securing the cluster
Kubernetes supports **TLS** certificates on each of its components. When set up correctly, it will only allow components with a certificate signed by a specific **Certification Authority** to talk to each other. In general a single Certification Authority is enough to setup a secure kubernets cluster. However nothing prevents to use different Certification Authorities for different components. For example, a public Certification Authority can be used to authenticate the API server in public Internet while internal components, such as worker nodes can be authenticate by using a self signed certificate.

The Kubernetes two-way authentication requires each component to have two certificates: the Certification Authority certificate and the component certificate and a private key. In this tutorial, we are going to use a unique self signed Certification Authority to secure the following components:

  * etcd
  * kube-apiserver
  * kubectl
  * kubelet
  * kube-proxy

We are not going to secure the controller manager and the scheduler since we suppose they run tied togheter to the api server on the same master node. 

## Create Certification Authority certificate and key
On any Linux machine install OpenSSL, create a folder where store certificates and keys

    openssl version
    OpenSSL 1.0.1e-fips 11 Feb 2013
    
    mkdir -p ./docker-pki
    cd ./docker-pki
    
To speedup things, in this lab, we'll use the **CloudFlare** TLS toolkit for helping us in TLS certificates creation. Details on this tool and how to use it are [here](https://github.com/cloudflare/cfssl).

Install the tool

    wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
    wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

    chmod +x cfssl_linux-amd64
    chmod +x cfssljson_linux-amd64

    mv cfssl_linux-amd64 /usr/local/bin/cfssl
    mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

Create a **Certification Authority** configuration file ``ca-config.json`` as following

```json
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "custom": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
```

Create the configuration file ``ca-csr.json`` for the **Certification Authority** signing request

```json
{
  "CN": "NoverIT",
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "C": "IT",
      "ST": "Italy",
      "L": "Milan",
      "O": "My Own Certification Authority"
    }
  ]
}
```

Generate a CA certificate and private key:

    cfssl gencert -initca ca-csr.json | cfssljson -bare ca

As result, we have following files

    ca-key.pem
    ca.pem

They are the key and the certificate of our self signed Certification Authority. Take this files in a secure place.

## Create server certificate and key
The master node IP addresses and names will be included in the list of subject alternative content names for the server certificate. Create the configuration file ``server-csr.json`` for server certificate signing request

```json
{
  "CN": "kubernetes",
  "hosts": [
    "10.10.10.80",
    "kubem00",
    "127.0.0.1",
    "localhost",
    "10.32.0.1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 4096
  }
}
```

We included public IP addresses and names as long as internal IP addresses of the master node and related names. If we have a cluster of master nodes, we have to add addresses and names for each of the master nodes.

Create the key pair

    cfssl gencert \
       -ca=ca.pem \
       -ca-key=ca-key.pem \
       -config=ca-config.json \
       -profile=custom \
       server-csr.json | cfssljson -bare server

This will produce the ``server.pem`` certificate file containing the public key and the ``server-key.pem`` file, containing the private key.

Move the key and certificate, along with the Certificate Authority certificate to the master node proper location ``/var/lib/kubernetes``

    scp ca.pem root@kubem00:/var/lib/kubernetes
    scp server*.pem root@kubem00:/var/lib/kubernetes

## Create client certificate and key
Since TLS authentication in kubernetes is a two way authentication between client and server, we create the client certificate and key to authenticate users to access the APIs server. We are going to create a certificate for the admin cluster user. This user will be allowed to perform any admin operation on the cluster via kubectl command line client interface.

Create the ``client-csr.json`` configuration file for the admin client.
```json
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 4096
  }
}
```

Create the admin client key and certificate

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -profile=custom \
      client-csr.json | cfssljson -bare client

This will produce the ``client.pem`` certificate file containing the public key and the ``client-key.pem`` file, containing the private key.

Move the key and certificate, along with the Certificate Authority certificate to the client proper location ``~/.kube`` on the client admin node. *Note: this could be any machine*

    scp ca.pem root@kube-admin:~/.kube
    scp client*.pem root@kube-admin:~/.kube

## Create kubelet certificates and key
We need also to secure interaction between worker nodes (kubelet) and master node (APIs server). Create the ``kubelet03-csr.json`` configuration file for each worker node
```json
{
  "CN": "kubew03",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 4096
  }
}
```

Create the admin client key and certificate

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -profile=custom \
      kubelet03-csr.json | cfssljson -bare kubelet03

This will produce the ``kubelet03.pem`` certificate file containing the public key and the ``kubelet03-key.pem`` file, containing the private key.

Move the key and certificate, along with the Certificate Authority certificate to the kubelet proper location ``/var/lib/kubelet`` on the worker node

    scp ca.pem root@kubew03:/var/lib/kubelet
    scp kubelet03*.pem root@kubew03:/var/lib/kubelet

Repeat the step above for each worker node we want to add to the cluster.




