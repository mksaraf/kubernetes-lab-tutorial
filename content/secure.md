# Securing the cluster
Kubernetes supports **TLS** certificates on each of its components. When set up correctly, it will only allow components with a certificate signed by a specific **Certification Authority** to talk to each other. In general a single Certification Authority is enough to setup a secure kubernets cluster. However nothing prevents to use different Certification Authorities for different components. For example, a public Certification Authority can be used to authenticate the API server in public Internet while internal components, such as worker nodes can be authenticate by using a self signed certificate.

The Kubernetes two-way authentication requires each component to have two certificates: the Certification Authority certificate and the component certificate and a private key. In this tutorial, we are going to use a unique self signed Certification Authority to secure the following components: **etcd**, **kube-apiserver**, **kubelet**, and **kube-proxy**.

   * [Create Certification Authority keys pair](#create-certification-authority-keys-pair)
   * [Create server keys pair](#create-server-keys-pair)
   * [Create client keys pair](#create-client-keys-pair)
   * [Create kubelet keys pair](#create-kubelet-keys-pair)
   * [Create proxy keys pair](#create-proxy-keys-pair)
   * [Securing the server](#securing-the-server)
   * [Configure the controller manager](#configure-the-controller-manager)
   * [Configure the scheduler](#configure-the-scheduler)
   * [Accessing the APIs server from client](#accessing-the-apis-server-from-client)   
   * [Securing the kubelet](#securing-the-kubelet)
   * [Securing the proxy](#securing-the-proxy)
   * [Enable Service Accounts](#enable-service-accounts)
   * [Complete the setup](#complete-the-setup)
   
*Note: in this tutorial we are assuming to setup a secure cluster from scratch. In case of a cluster already running, remove any configuration and data before to try to implement these instructions.*

## Create Certification Authority keys pair
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

## Create server keys pair
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

## Create client keys pair
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

## Create kubelet keys pair
We need also to secure interaction between worker nodes and master node. Create the ``kubelet-csr.json`` configuration file for the kubelet component
```json
{
  "CN": "kubelet",
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
      kubelet-csr.json | cfssljson -bare kubelet

This will produce the ``kubelet.pem`` certificate file containing the public key and the ``kubelet-key.pem`` file, containing the private key.

Move the key and certificate, along with the Certificate Authority certificate to the kubelet proper location ``/var/lib/kubelet`` on the worker node

    scp ca.pem root@kubew03:/var/lib/kubernetes
    scp kubelet*.pem root@kubew03:/var/lib/kubelet

Repeat the step above for each worker node we want to add to the cluster.

## Create proxy keys pair
For the proxy component, create the ``kube-proxy-csr.json`` configuration file 
```json
{
  "CN": "kube-proxy",
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
      kube-proxy-csr.json | cfssljson -bare kube-proxy

This will produce the ``kube-proxy.pem`` certificate file containing the public key and the ``kube-proxy-key.pem`` file, containing the private key.

Move the key and certificate, along with the Certificate Authority certificate to the kube-proxy proper location ``/var/lib/kube-proxy`` on the worker node

    scp ca.pem root@kubew03:/var/lib/kubernetes
    scp kube-proxy*.pem root@kubew03:/var/lib/kube-proxy

Repeat the step above for each worker node we want to add to the cluster.

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
        --etcd-servers=https://10.10.10.80:2379 \
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
        --service-account-key-file=/var/lib/kubernetes/ca-key.pem \
        --v=2

      Restart=on-failure
      RestartSec=5
      LimitNOFILE=65536

      [Install]
      WantedBy=multi-user.target
      
      # --kubelet-https=true \
      # --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
      # --kubelet-client-certificate=/var/lib/kubernetes/server.pem \
      # --kubelet-client-key=/var/lib/kubernetes/server-key.pem \

Start and enable the service

    systemctl daemon-reload
    systemctl start kube-apiserver
    systemctl enable kube-apiserver
    systemctl status kube-apiserver

## Configure the controller manager
Having configured TLS on the APIs server, we need to configure other components to authenticate with the server. To configure the controller manager component to communicate securely with APIs server, set the required options in the ``/etc/systemd/system/kube-controller-manager.service`` startup file

    [Unit]
    Description=Kubernetes Controller Manager
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=network.target

    [Service]
    ExecStart=/usr/bin/kube-controller-manager \
      --address=0.0.0.0 \
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

## Configure the scheduler
Finally, configure the sceduler by setting the required options in the ``/etc/systemd/system/kube-scheduler.service`` startup file

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

## Accessing the APIs server from client
We just configured TLS on the APIs server. So, any interaction with it will require authentication. Kubernetes supports different types of authentication, please, refer to the documentation for details. In this section, we are going to use the **X.509** certificates based authentication.

All the users, including the cluster admin, have to authenticate against the APIs server before to access it. For now, we are not going to configure any authorization, so once a user is authenticated, he is enabled to operate on the cluster.

To enable the ``kubectl`` command cli, login to the client admin machine where the cli is installed and create the context authentication file

    cd ~/.kube

    ls -l
    total 24
    -rw-r--r-- 1 root root 2061 Aug 13 19:37 ca.pem
    -rw------- 1 root root 3243 Aug 27 10:27 client-key.pem
    -rw-r--r-- 1 root root 1976 Aug 27 10:27 client.pem

    kubectl config set-credentials admin \
            --username=admin \
            --client-certificate=client.pem \
            --client-key=client-key.pem

    kubectl config set-cluster kubernetes \
            --server=https://10.10.10.80:6443 \
            --certificate-authority=ca.pem

    kubectl config set-context default/kubernetes/admin \
            --cluster=kubernetes \
            --namespace=default \
            --user=admin

    kubectl config use-context default/kubernetes/admin
    Switched to context "default/kubernetes/admin".

The context file ``~/.kube/config`` should look like this

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: ca.pem
    server: https://10.10.10.80:6443
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
    client-certificate: client.pem
    client-key: client-key.pem
    username: admin
```

Now it is possible to query and operate with the cluster in a secure way

    kubectl get cs
    NAME                 STATUS    MESSAGE              ERROR
    controller-manager   Healthy   ok
    scheduler            Healthy   ok
    etcd-0               Healthy   {"health": "true"}

## Securing the kubelet
In a kubernetes cluster, each worker node run both the kubelet and the proxy components. Since worker nodes can be placed on a remote location, we are going to secure the communication between these components and the APIs server.

First, configure docker on worker node as reported [here](../content/setup.md#configure-docker) and then configure the network plugins as reported [here](../content/setup.md#setup-the-cni-network-plugins).

Login to the worker node and configure the kubelet by setting the required options in the ``/etc/systemd/system/kubelet.service`` startup file

    [Unit]
    Description=Kubernetes Kubelet
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=docker.service
    Requires=docker.service

    [Service]
    ExecStart=/usr/bin/kubelet \
      --api-servers=https://10.10.10.80:6443 \
      --allow-privileged=true \
      --cgroup-driver=systemd \
      --cluster-dns=10.32.0.10 \
      --cluster-domain=cluster.local \
      --container-runtime=docker \
      --serialize-image-pulls=false \
      --register-node=true \
      --network-plugin=cni \
      --cni-bin-dir=/etc/cni/bin \
      --cni-conf-dir=/etc/cni/config \
      --kubeconfig=/var/lib/kubelet/kubeconfig \
      --v=2
    Restart=on-failure
    RestartSec=5

    [Install]
    WantedBy=multi-user.target

As a client of the APIs server, the kubelet requires its own ``kubeconfig`` context authentication file

    cd /var/lib/kubelet
    
    kubectl config set-credentials kubelet \
            --username=kubelet \
            --client-certificate=/var/lib/kubelet/kubelet.pem \
            --client-key=/var/lib/kubelet/kubelet-key.pem \
            --kubeconfig=kubeconfig

    kubectl config set-cluster kubernetes \
            --server=https://10.10.10.80:6443 \
            --certificate-authority=/var/lib/kubernetes/ca.pem \
            --kubeconfig=kubeconfig

    kubectl config set-context default \
            --cluster=kubernetes \
            --user=kubelet \
            --kubeconfig=kubeconfig
    
    kubectl config use-context default --kubeconfig=kubeconfig

The context file ``kubeconfig`` should look like this

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/ca.pem
    server: https://10.10.10.80:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: kubelet
  user:
    client-certificate: /var/lib/kubelet/kubelet.pem
    client-key: /var/lib/kubelet/kubelet-key.pem
```

Start and enable the kubelet service

    systemctl daemon-reload
    systemctl start kubelet
    systemctl enable kubelet
    systemctl status kubelet    
    
## Securing the proxy
Lastly, configure the proxy by setting the required options in the ``/etc/systemd/system/kube-proxy.service`` startup file

    [Unit]
    Description=Kubernetes Kube Proxy
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes

    [Service]
    ExecStart=/usr/bin/kube-proxy \
      --cluster-cidr=10.38.0.0/16 \
      --masquerade-all=true \
      --kubeconfig=/var/lib/kube-proxy/kubeconfig \
      --proxy-mode=iptables \
      --v=2
    Restart=on-failure
    RestartSec=5

    [Install]
    WantedBy=multi-user.target

As a client of the APIs server, the kube-proxy requires its own ``kubeconfig`` context authentication file

    cd /var/lib/kube-proxy
    
    kubectl config set-credentials kube-proxy \
            --username=kube-proxy \
            --client-certificate=/var/lib/kube-proxy/kube-proxy.pem \
            --client-key=/var/lib/kube-proxy/kube-proxy.pem-key.pem \
            --kubeconfig=kubeconfig

    kubectl config set-cluster kubernetes \
            --server=https://10.10.10.80:6443 \
            --certificate-authority=/var/lib/kubernetes/ca.pem \
            --kubeconfig=kubeconfig

    kubectl config set-context default \
            --cluster=kubernetes \
            --user=kube-proxy \
            --kubeconfig=kubeconfig
            
    kubectl config use-context default --kubeconfig=kubeconfig

The context file ``kubeconfig`` should look like this

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/ca.pem
    server: https://10.10.10.80:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kube-proxy
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: kube-proxy
  user:
    client-certificate: /var/lib/kube-proxy/kube-proxy.pem
    client-key: /var/lib/kube-proxy/kube-proxy-key.pem
```

Start and enable the service

    systemctl daemon-reload
    systemctl start kube-proxy
    systemctl enable kube-proxy
    systemctl status kube-proxy

## Service Accounts
T.B.D

## Complete the setup
Now configure the network routes as reported [here](../content/setup.md#define-the-containers-network-routes).

The cluster should be now running. Check to make sure the cluster can see the nodes, by logging to the master

    kubectl get nodes
    NAME      STATUS    AGE       VERSION
    kubew03   Ready     12m       v1.7.0
    kubew04   Ready     1m        v1.7.0
    kubew05   Ready     1m        v1.7.0

To complete the setup, install the DNS service on the cluster as reported [here](../content/setup.md#configure-dns-service).
