# Securing the cluster
Kubernetes supports **TLS** certificates on each of its components. When set up correctly, it will only allow components with a certificate signed by a specific **Certification Authority** to talk to each other. In general a single Certification Authority is enough to setup a secure kubernets cluster. However nothing prevents to use different Certification Authorities for different components. For example, a public Certification Authority can be used to authenticate the API server in public Internet while internal components, such as worker nodes can be authenticate by using a self signed certificate.

The Kubernetes two-way authentication requires each component to have two certificates: the Certification Authority certificate and the component certificate and a private key. In this tutorial, we are going to use a unique self signed Certification Authority to secure the following components: **etcd**, **kube-apiserver**, **kubelet**, and **kube-proxy**.

   * [Create TLS certificates](#create-tls-certificates)
   * [Securing etcd](#securing-etcd)
   * [Securing the master](#securing-the-master)
   * [Accessing the server](#accessing-the-server)   
   * [Securing the worker](#securing-the-worker)
   
*Note: in this tutorial we are assuming to setup a secure cluster from scratch. In case of a cluster already running, remove any configuration and data before to try to implement these instructions.*

## Create TLS certificates
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

### Create Certification Authority keys pair
Create a **Certificates** configuration file ``cert-config.json`` as following

```json
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "server-authentication": {
        "usages": ["signing", "key encipherment", "server auth"],
        "expiry": "8760h"
      },
      "client-authentication": {
        "usages": ["signing", "key encipherment", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
```

Create the configuration file ``ca-csr.json`` for the **Certification Authority** signing request

```json
{
  "CN": "Clastix.io CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "ST": "Italy",
      "L": "Milan"
    }
  ]
}
```

Generate a CA certificate and private key:

    cfssl gencert -initca ca-csr.json | cfssljson -bare ca

As result, we have following files

    ca-key.pem
    ca.pem

They are the key and the certificate of our self signed Certification Authority. Move the key and certificate to master node proper location ``/etc/kubernetes/pki``

    scp ca*.pem root@kubem00:/etc/kubernetes/pki

Move the certificate to all worker nodes in the proper location ``/etc/kubernetes/pki``

    for instance in kubew03 kubew04 kubew05; do
      scp ca.pem ${instance}:/etc/kubernetes/pki
    done

### Create server keys pair
The master node IP addresses and names will be included in the list of subject alternative content names for the server certificate. Create the configuration file ``server-csr.json`` for server certificate signing request

```json
{
  "CN": "apiserver",
  "hosts": [
    "127.0.0.1",
    "10.32.0.1",
    "10.32.0.10",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster.local",
    "kubernetes.clastix.io"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
```

We included public IP addresses and names as long as internal IP addresses of the master node and related names.

Create the server key pair

    cfssl gencert \
       -ca=ca.pem \
       -ca-key=ca-key.pem \
       -config=cert-config.json \
       -profile=server-authentication \
       server-csr.json | cfssljson -bare server

This will produce the ``server.pem`` certificate file containing the public key and the ``server-key.pem`` file, containing the private key. Just as reference, to verify that a certificate was issued by a specific CA, given that CA's certificate

    openssl x509 -in server.pem -noout -issuer -subject
      issuer= /C=IT/ST=Italy/L=Milan/CN=Clastix.io CA
      subject= /CN=apiserver
    
    openssl verify -verbose -CAfile ca.pem  server.pem
      server.pem: OK

Move the key and certificate to master node proper location ``/etc/kubernetes/pki``

    scp server*.pem root@kubem00:/etc/kubernetes/pki

### Create client keys pair
Since TLS authentication in kubernetes is a two way authentication between client and server, we create the client certificate and key. We are going to create a certificate for the admin cluster user. This user will be allowed to perform any admin operation on the cluster via kubectl command line client interface.

Create the ``admin-csr.json`` configuration file for the admin client.
```json
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
```

Create the admin client key and certificate

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=cert-config.json \
      -profile=client-authentication \
      admin-csr.json | cfssljson -bare admin

This will produce the ``admin.pem`` certificate file containing the public key and the ``admin-key.pem`` file, containing the private key.

Move the key and certificate, along with the Certificate Authority certificate to the client proper location ``~/.kube`` on the client admin node. *Note: this could be any machine*

    scp ca.pem root@kube-admin:~/.kube
    scp admin*.pem root@kube-admin:~/.kube

### Create kubelet keys pair
We need also to secure interaction between worker nodes and master node. Create the ``kubelet-csr.json`` configuration file for the kubelet component
```json
{
  "CN": "kubelet",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
```

Create the key and certificate

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=cert-config.json \
      -profile=client-authentication \
      kubelet-csr.json | cfssljson -bare kubelet

This will produce the ``kubelet.pem`` certificate file containing the public key and the ``kubelet-key.pem`` file, containing the private key.

Move the keys pair to all worker nodes in the proper location ``/var/lib/kubelet/pki``

    for instance in kubew03 kubew04 kubew05; do
      scp kubelet*.pem ${instance}:/var/lib/kubelet/pki
    done


### Create proxy keys pair
For the proxy component, create the ``kube-proxy-csr.json`` configuration file 
```json
{
  "CN": "kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
```

Create the key and certificate

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=cert-config.json \
      -profile=client-authentication \
      kube-proxy-csr.json | cfssljson -bare kube-proxy

This will produce the ``kube-proxy.pem`` certificate file containing the public key and the ``kube-proxy-key.pem`` file, containing the private key.

Move the keys pair to all worker nodes in the proper location ``/var/lib/kube-proxy/pki``

    for instance in kubew03 kubew04 kubew05; do
      scp kube-proxy*.pem ${instance}:/var/lib/kube-proxy/pki
    done

### Create kubelet client keys pair
We'll also secure the communication between the API server and kubelet when requests are initiated by the API server (i.e. when it acts as client) to the kubelet services listening on TCP port 10255 of the worker nodes. 

Create the ``kubelet-client-csr.json`` configuration file 
```json
{
  "CN": "kubelet-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
```

Create the key and certificate

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=cert-config.json \
      -profile=client-authentication \
      kubelet-client-csr.json | cfssljson -bare kubelet-client

This will produce the ``kubelet-client`` certificate file containing the public key and the ``kubelet-client-key.pem`` file, containing the private key.

Move the keys pair to the master node in the proper location ``/etc/kubernetes/pki``

    scp kubelet-client*.pem kubem00:/etc/kubernetes/pki

## Configure etcd
For now, we'll not secure the communication between etcd and APIs server because we assume the etcd is installed on the same master node where the api server is running. In case of API server and etcd instance running on different machines or in case of multiple etcd instances, we'll have to secure the etcd.

## Securing the master
In this section, we are going to secure the master node and its components.

### Configure the APIs server
Set the options in the ``/etc/systemd/system/kube-apiserver.service`` startup file

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
        --bind-address=0.0.0.0 \
        --service-cluster-ip-range=10.32.0.0/16 \
        --service-node-port-range=30000-32767 \
        --client-ca-file=/var/lib/kubernetes/ca.pem \
        --tls-cert-file=/var/lib/kubernetes/server.pem \
        --tls-private-key-file=/var/lib/kubernetes/server-key.pem \
        --etcd-cafile=/var/lib/kubernetes/ca.pem \
        --etcd-certfile=/var/lib/kubernetes/server.pem \
        --etcd-keyfile=/var/lib/kubernetes/server-key.pem \
        --service-account-key-file=/var/lib/kubernetes/ca.pem \
        --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
        --kubelet-client-certificate=/var/lib/kubernetes/server.pem \
        --kubelet-client-key=/var/lib/kubernetes/server-key.pem \
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

### Configure the controller manager
Having configured TLS on the APIs server, we need to configure other components to authenticate with the server. To configure the controller manager component to communicate securely with APIs server, set the required options in the ``/etc/systemd/system/kube-controller-manager.service`` startup file

    [Unit]
    Description=Kubernetes Controller Manager
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=network.target

    [Service]
    ExecStart=/usr/bin/kube-controller-manager \
      --address=127.0.0.1 \
      --cluster-cidr=10.38.0.0/16 \
      --cluster-name=kubernetes \
      --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \
      --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \
      --root-ca-file=/var/lib/kubernetes/ca.pem \
      --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \
      --master=http://127.0.0.1:8080 \
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

### Configure the scheduler
Finally, configure the sceduler by setting the required options in the ``/etc/systemd/system/kube-scheduler.service`` startup file

    [Unit]
    Description=Kubernetes Scheduler
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=network.target

    [Service]
    ExecStart=/usr/bin/kube-scheduler \
      --address=127.0.0.1 \
      --master=http://127.0.0.1:8080 \
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

## Accessing the server
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

## Securing the worker
In a kubernetes cluster, each worker node run both the kubelet and the proxy components. Since worker nodes can be placed on a remote location, we are going to secure the communication between these components and the APIs server.

### Configure the kubelet
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
    
### Configure the proxy
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
            --client-key=/var/lib/kube-proxy/kube-proxy-key.pem \
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
