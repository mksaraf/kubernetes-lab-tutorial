# Securing the cluster
Kubernetes supports **TLS** certificates on each of its components. When set up correctly, it will only allow components with a certificate signed by a specific **Certification Authority** to talk to each other. In general a single Certification Authority is enough to setup a secure kubernets cluster. However nothing prevents to use different Certification Authorities for different components. For example, a public Certification Authority can be used to authenticate the API server in public Internet while internal components, such as worker nodes can be authenticate by using a self signed certificate.

The Kubernetes two-way authentication requires each component to have two certificates: the Certification Authority certificate and the component certificate and a private key. In this tutorial, we are going to use a unique self signed Certification Authority to secure the following components:

  * etcd
  * kube-apiserver
  * kubelet
  * kube-proxy

*Note: in this tutorial we are assuming to setup a secure cluster from scratch. In case of a cluster already running, remove any configuration and data before to try to implement these instructions.*

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

## Create kubelet certificate and key
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

## Create proxy certificate and key

## Securing etcd
We are going to secure the communication between etcd and APIs server. For simplicity, we assume the etcd is installed on the same master node where api server will run.

Create the etcd directory data

    mkdir /var/lib/etcd

Copy the server certificate and key along with the Certification Authority certificate in a dedicatd directory

    mkdir /etc/etcd
    cp /var/lib/kubernetes/ca.pem /etc/etcd
    cp /var/lib/kubernetes/server*.pem /etc/etcd

Set etcd options in the ``/etc/systemd/system/etcd.service`` startup file

    [Unit]
    Description=etcd
    Documentation=https://github.com/coreos
    After=network.target
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=notify
    ExecStart=/usr/bin/etcd \
      --name kubem00 \
      --cert-file=/etc/etcd/server.pem \
      --key-file=/etc/etcd/server-key.pem \
      --peer-cert-file=/etc/etcd/server.pem \
      --peer-key-file=/etc/etcd/server-key.pem \
      --trusted-ca-file=/etc/etcd/ca.pem \
      --peer-trusted-ca-file=/etc/etcd/ca.pem \
      --peer-client-cert-auth \
      --client-cert-auth \
      --initial-advertise-peer-urls https://10.10.10.80:2380 \
      --listen-peer-urls https://10.10.10.80:2380 \
      --listen-client-urls https://10.10.10.80:2379,http://127.0.0.1:2379 \
      --advertise-client-urls https://10.10.10.80:2379 \
      --initial-cluster-token etcd-cluster-token \
      --initial-cluster kubem00=https://10.10.10.80:2380 \
      --initial-cluster-state new \
      --data-dir=/var/lib/etcd
    
    Restart=on-failure
    RestartSec=5
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target

Start and enable the service

    systemctl daemon-reload
    systemctl start etcd
    systemctl enable etcd
    systemctl status etcd

To query the etcd, use the ``etcdctl`` command utlity. Since we configured TLS on etcd, any client needs to present a certificate to be authenticad by the etcd service. Create an env file ``etcdctl-v2.rc`` to access etcd by using API v2 

    cat etcdctl-v2.rc

    export PS1='[\W(etcdctl-v2)]\$ '
    unset  ETCDCTL_API
    export ETCDCTL_CA_FILE=/etc/etcd/ca.pem
    export ETCDCTL_CERT_FILE=/etc/etcd/server.pem
    export ETCDCTL_KEY_FILE=/etc/etcd/server-key.pem

    source etcdctl-v2.rc

    etcdctl --endpoints=https://10.10.10.80:2379 member list

    1857fba22cc98a20: name=kubem00
    peerURLs=https://10.10.10.80:2380
    clientURLs=https://10.10.10.80:2379
    isLeader=true

or an env file ``etcdctl-v3.rc`` to access etcd by using API v3

    cat etcdctl-v3.rc

    export PS1='[\W(etcdctl-v3)]\$ '
    export ETCDCTL_API=3
    export ETCDCTL_CACERT=/etc/etcd/ca.pem
    export ETCDCTL_CERT=/etc/etcd/server.pem
    export ETCDCTL_KEY=/etc/etcd/server-key.pem
    export ENDPOINTS=10.10.10.80:2379

    source etcdctl-v3.rc

    etcdctl --endpoints=https://10.10.10.80:2379 member list
    1857fba22cc98a20, started, kubem00, https://10.10.10.80:2380, https://10.10.10.80:2379

## Securing the server
We are going to secure the APIs server on the master node. Set the options in the ``/etc/systemd/system/kube-apiserver.service`` startup file
      [Unit]
      Description=Kubernetes API Server
      Documentation=https://github.com/GoogleCloudPlatform/kubernetes
      After=network.target
      After=etcd.service

      [Service]
      Type=notify
      ExecStart=/usr/bin/kube-apiserver \
        --admission-control=NamespaceLifecycle,ServiceAccount,LimitRanger,DefaultStorageClass,ResourceQuota \
        --anonymous-auth=false \
        --etcd-servers=http://10.10.10.80:2379 \
        --advertise-address=10.10.10.80 \
        --allow-privileged=true \
        --audit-log-maxage=30 \
        --audit-log-maxbackup=3 \
        --audit-log-maxsize=100 \
        --audit-log-path=/var/lib/audit.log \
        --enable-swagger-ui=true \
        --event-ttl=1h \
        --insecure-bind-address=0.0.0.0 \
        --bind-address=0.0.0.0 \
        --service-cluster-ip-range=10.32.0.0/16 \
        --service-node-port-range=30000-32767 \
        --client-ca-file=/var/lib/kubernetes/ca.pem \
        --tls-cert-file=/var/lib/kubernetes/server.pem \
        --tls-private-key-file=/var/lib/kubernetes/server-key.pem \
        --etcd-cafile=/var/lib/kubernetes/ca.pem \
        --etcd-certfile=/var/lib/kubernetes/server.pem \
        --etcd-keyfile=/var/lib/kubernetes/server-key.pem \
        --kubelet-https=true \
        --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
        --kubelet-client-certificate=/var/lib/kubernetes/server.pem \
        --kubelet-client-key=/var/lib/kubernetes/server-key.pem \
        --service-account-key-file=/var/lib/kubernetes/ca-key.pem \
        --v=2

      Restart=on-failure
      RestartSec=5
      LimitNOFILE=65536

      [Install]
      WantedBy=multi-user.target

Start and enable the service

    systemctl daemon-reload
    systemctl start kube-apiserver
    systemctl enable kube-apiserver
    systemctl status kube-apiserver

Having configured TLS on the APIs server, we need to adapt other master components to authenticate with the server. To configure the controller manager component to communicate with APIs server, set the required options in the ``/etc/systemd/system/kube-controller-manager.service`` startup file

    [Unit]
    Description=Kubernetes Controller Manager
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=network.target

    [Service]
    ExecStart=/usr/bin/kube-controller-manager \
      --address=0.0.0.0 \
      --allocate-node-cidrs=true \
      --cluster-cidr=10.38.0.0/16 \
      --cluster-name=kubernetes \
      --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \
      --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \
      --root-ca-file=/var/lib/kubernetes/ca.pem \
      --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \
      --master=http://10.10.10.80:8080 \
      --leader-elect=true \
      --service-cluster-ip-range=10.32.0.0/16 \
      --v=2

    Restart=on-failure
    RestartSec=5
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target

Start and enable the service

    systemctl daemon-reload
    systemctl start kube-controller-manager
    systemctl enable kube-controller-manager
    systemctl status kube-controller-manager

Finally, set the required options in the ``/etc/systemd/system/kube-scheduler.service`` startup file

    [Unit]
    Description=Kubernetes Scheduler
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=network.target

    [Service]
    ExecStart=/usr/bin/kube-scheduler \
      --master=http://10.10.10.80:8080 \
      --v=2
    Restart=on-failure
    RestartSec=5
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target

Start and enable the service

    systemctl daemon-reload
    systemctl start kube-scheduler
    systemctl enable kube-scheduler
    systemctl status kube-scheduler

## Accessing the APIs server

## Securing worker nodes


