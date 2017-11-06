# Setup a Kubernetes Cluster
This tutorial refers to a cluster of nodes (virtual, physical or a mix of both) running CentOS 7 Operating System. We'll set Kubernetes components as system processes managed by systemd.

   * [Requirements](#requirements)
   * [Install binaries](#install-binaries)
   * [Create TLS certificates](#create-tls-certificates)
   * [Configure etcd](#configure-etcd)
   * [Configure the Control Plane](#configure-the-control-plane)
   * [Configure the clients](#configure-the-clients)
   * [Configure the Compute Plane](#configure-the-compute-plane)
   * [Define the Network Routes](#define-the-network-routes)
   * [Configure DNS service](#configure-dns-service)

## Requirements
Our initial cluster will be made of 1 Master node and 3 Workers nodes. All machines can be virtual or physical or a mix of both. Minimum hardware requirements are: 1 vCPUs, 2GB of RAM, 16GB HDD for OS. All machines will be installed with a minimal Linux CentOS 7. Firewall and Selinux will be disabled. An NTP server is installed and running on all machines. On worker nodes, Docker is installed with a Device Mapper on a separate 10GB HDD. Internet access.

Here the hostnames:

   * *kubem00* a.k.a *kubernetes* (master)
   * *kubew03* (worker)
   * *kubew04* (worker)
   * *kubew05* (worker)

Make sure to enable DNS resolution for the above hostnames or set the ``/etc/hosts`` file on all the machines.

Here the releases we'll use during this tutorial

    ETCD=v3.2.8
    KUBERNETES=v1.8.2
    DOCKER=v1.12.6
    CNI=v0.6.0

## Install binaries
On the master node, get etcd and kubernetes

    wget https://github.com/coreos/etcd/releases/download/$ETCD/etcd-$ETCD-linux-amd64.tar.gz
    wget https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES/bin/linux/amd64/kube-apiserver
    wget https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES/bin/linux/amd64/kube-controller-manager
    wget https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES/bin/linux/amd64/kube-scheduler
    wget https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES/bin/linux/amd64/kubectl

estract and install

    tar -xvf etcd-$ETCD-linux-amd64.tar.gz
    chown -R root:root etcd-$ETCD-linux-amd64 && mv etcd-$ETCD-linux-amd64/etcd* /usr/bin/
    chmod +x kube-apiserver && mv kube-apiserver /usr/bin/
    chmod +x kube-controller-manager && mv kube-controller-manager /usr/bin/
    chmod +x kube-scheduler && mv kube-scheduler /usr/bin/
    chmod +x kubectl && mv kubectl /usr/local/bin/kubectl

On all the worker nodes, get kubernetes and the network plugins

    wget https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES/bin/linux/amd64/kubelet
    wget https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES/bin/linux/amd64/kube-proxy
    wget https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES/bin/linux/amd64/kubectl
    wget https://github.com/containernetworking/plugins/releases/download/$CNI/cni-plugins-amd64-$CNI.tgz 

Estract and install

    chmod +x kubelet && mv kubelet /usr/bin/
    chmod +x kube-proxy && mv kube-proxy /usr/bin/
    chmod +x kubectl && mv kubectl /usr/local/bin/kubectl
    mkdir -p /etc/cni/bin && tar -xvf cni-plugins-amd64-$CNI.tgz -C /etc/cni/bin

On all the worker nodes, install docker

    yum -y install docker

## Create TLS certificates
Kubernetes supports **TLS** certificates on each of its components. When set up correctly, it will only allow components with a certificate signed by a specific **Certification Authority** to talk to each other. In general a single Certification Authority is enough to setup a secure kubernets cluster. However nothing prevents to use different Certification Authorities for different components. For example, a public Certification Authority can be used to authenticate the API server in public Internet while internal components, such as worker nodes can be authenticate by using a self signed certificate.

In this tutorial, we are going to use a unique self signed Certification Authority.
   
*Note: in this tutorial we are assuming to setup a secure cluster from scratch. In case of a cluster already running, remove any configuration and data before to try to implement these instructions.*

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
      scp kubelet.pem kubelet-key.pem ${instance}:/var/lib/kubelet/pki
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

### Create kubelet clients keys pair
We'll also secure the communication between the API server and kubelet when requests are initiated by the API server, i.e. when it acts as client of kubelet services listening on the worker nodes. 

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

### Create service accounts keys pair
Unlike every other TLS key that kubernetes supports, the service account key doesn’t require to be signed by a Certification Authority and, therfore, it does not need for certificates. 

Just generate a service account key with

    openssl genrsa -out sa.key 2048

and move it to the master node in the proper location

    scp sa.key kubem00:/etc/kubernetes/pki

## Configure etcd
In this section, we'll install a single instance of etcd running on the same machine of the API server. For this reason, we'll not secure the communication between etcd and APIs server because of this assumption.

On the master node, create the etcd data directory

    mkdir -p /var/lib/etcd

Before launching and enabling the etcd service, set options in the ``/etc/systemd/system/etcd.service`` startup file

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
      --initial-advertise-peer-urls http://127.0.0.1:2380 \
      --listen-peer-urls http://127.0.0.1:2380 \
      --listen-client-urls http://127.0.0.1:2379 \
      --advertise-client-urls http://127.0.0.1:2379 \
      --initial-cluster-token etcd-cluster-token \
      --initial-cluster kubem00=http://127.0.0.1:2380 \
      --initial-cluster-state new \
      --data-dir=/var/lib/etcd \
      --debug=false

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

## Configure the Control Plane
In this section, we are going to configure the Control Plane on the master node.

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
      --etcd-servers=http://127.0.0.1:2379 \
      --advertise-address=0.0.0.0 \
      --allow-privileged=true \
      --insecure-bind-address=127.0.0.1 \
      --insecure-port=8080 \
      --bind-address=0.0.0.0 \
      --secure-port=6443 \
      --service-cluster-ip-range=10.32.0.0/16 \
      --service-node-port-range=30000-32767 \
      --client-ca-file=/etc/kubernetes/pki/ca.pem \
      --tls-cert-file=/etc/kubernetes/pki/server.pem \
      --tls-private-key-file=/etc/kubernetes/pki/server-key.pem \
      --service-account-key-file=/etc/kubernetes/pki/sa.key \
      --kubelet-client-certificate=/etc/kubernetes/pki/kubelet-client.pem \
      --kubelet-client-key=/etc/kubernetes/pki/kubelet-client-key.pem \
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
      --master=http://127.0.0.1:8080 \
      --service-cluster-ip-range=10.32.0.0/16 \
      --service-account-private-key-file=/etc/kubernetes/pki/sa.key \
      --root-ca-file=/etc/kubernetes/pki/ca.pem \
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

## Configure the clients
We just configured TLS on the APIs server. So, any interaction with it will require authentication. Kubernetes supports different types of authentication, please, refer to the documentation for details. In this section, we are going to use the **X.509** certificates based authentication.

All the users, including the cluster admin, have to authenticate against the APIs server before to access it. For now, we are not going to configure any authorization, so once a user is authenticated, he is enabled to operate on the cluster.

To enable the ``kubectl`` command cli, login to the client admin machine where the cli is installed and create the context authentication file

    mkdir ~/.kube && cd ~/.kube

    kubectl config set-credentials admin \
            --username=admin \
            --client-certificate=client.pem \
            --client-key=client-key.pem

    kubectl config set-cluster kubernetes \
            --server=https://kubernetes:6443 \
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
    server: https://kubernetes:6443
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

## Configure the Compute Plane
In a kubernetes cluster, each worker node runs the container engine, the network plugins, the kubelet, and the proxy components.

### Disable swap
Starting from Kubernetes 1.8, the nodes running kubelet have to be swap disabled. The assigned swap memory can be disabled by using swapoff command. You can list all currently mounted and active swap partition by a following command:

    cat /proc/swaps
    Filename                                Type            Size    Used    Priority
    /dev/dm-0                               partition       1679356 600     -1

To temporarely switch off swap use the following command

    swapoff -a

    cat /proc/swaps
    Filename                                Type            Size    Used    Priority

To defenively disable swap, modify the fstab file by commenting the swap mounting

    /dev/mapper/os-root     /                         xfs     defaults        1 1
    UUID=49e78f32-2e92-4acd-9b8b-ef41b13c3a7d /boot   xfs     defaults        1 2
    # /dev/mapper/os-swap     swap                    swap    defaults        0 0

### Configure the containers engine
There are a number of ways to customize the Docker daemon flags and environment variables. The recommended way from Docker web site is to use the platform-independent ``/etc/docker/daemon.json`` file instead of the systemd unit file. This file is available on all the Linux distributions

```json
{
 "debug": true,
 "storage-driver": "devicemapper",
 "iptables": false,
 "ip-masq": false
}
```

On CentOS systems, the suggested storage mapper is the Device Mapper.

Also, since Kubernetes uses a different network model than Docker, we need to prevent Docker to use NAT/IP Table rewriting, as for its default settings. For this reason, we disable the IP Table and NAT options in Docker daemon.

Start and enable the docker service

    systemctl start docker
    systemctl enable docker
    systemctl status docker

As usual, Docker will create the default ``docker0`` bridge network interface

    ifconfig docker0
    docker0: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
            inet 172.17.0.1  netmask 255.255.0.0  broadcast 0.0.0.0
            ether 02:42:c3:64:b4:7f  txqueuelen 0  (Ethernet)

However, we're not going to use it since Kubernetes networking is based on the **CNI** Container Network Interface.

### Setup the network plugin
In this tutorial we are not going to provision any overlay networks for containers networking. Instead we'll rely on the simpler routing networking between the nodes. That means we need to add some static routes to our hosts.

First, make sure the IP forwarding kernel option and is enabled on all worker nodes

    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.conf
    
Since we are going to use Linux bridge for node networking, make sure that packets traversing the Linux bridge are sent to iptables for processing

    echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
    
Load the ``br_netfilter`` kernel module and make sure it is loaded at system startup

    modprobe br_netfilter
    echo br_netfilter > /etc/modules-load.d/bridge.conf
    
Load the above kernel settings and restart the network service on all the worker nodes

    sysctl -p /etc/sysctl.conf
    systemctl restart network

The IP address space for containers will be allocated from the ``10.38.0.0/16`` cluster range assigned to each Kubernetes worker through the node registration process. Based on the above configuration each worker will be set with a 24-bit subnet

    * kubew03 10.38.3.0/24
    * kubew04 10.38.4.0/24
    * kubew05 10.38.5.0/24

Then configure the CNI networking according to the subnets above

    mkdir -p /etc/cni/config
    
    vi /etc/cni/config/bridge.conf
    {
        "cniVersion": "0.3.1",
        "name": "bridge",
        "type": "bridge",
        "bridge": "cni0",
        "isGateway": true,
        "ipMasq": true,
        "ipam": {
            "type": "host-local",
            "ranges": [
              [{"subnet": "10.38.3.0/24"}]
            ],
            "routes": [{"dst": "0.0.0.0/0"}]
        }
    }
    
    vi /etc/cni/config/loopback.conf
    {
        "cniVersion": "0.3.1",
        "type": "loopback"
    }

Make the same for all worker nodes paying attention to set the correct subnet for each node.

On the first cluster activation, the above configurations will create on the worker node a bridge interface ``cni0`` having the IP address as ``10.38.3.1/24``. All containers running on that worker node, will get an IP in the above subnet having that bridge interface as default gateway.


### Configure the kubelet
For each worker node in the cluster, configure the kubelet by setting the required options in the ``/etc/systemd/system/kubelet.service`` startup file

    [Unit]
    Description=Kubernetes Kubelet Server
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=docker.service
    Requires=docker.service

    [Service]
    ExecStart=/usr/bin/kubelet \
      --allow-privileged=true \
      --cluster-dns=10.32.0.10 \
      --cluster-domain=cluster.local \
      --container-runtime=docker \
      --cgroup-driver=systemd \
      --serialize-image-pulls=false \
      --register-node=true \
      --network-plugin=cni \
      --cni-bin-dir=/etc/cni/bin \
      --cni-conf-dir=/etc/cni/config \
      --kubeconfig=/var/lib/kubelet/kubeconfig \
      --anonymous-auth=false \
      --client-ca-file=/etc/kubernetes/pki/ca.pem \
      --v=2

    Restart=on-failure

    [Install]
    WantedBy=multi-user.target


As a client of the APIs server, the kubelet requires its own ``kubeconfig`` context authentication file. The context file for kubelet ``/var/lib/kubelet/kubeconfig`` should look like this

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/ca.pem
    server: https://kubernetes:6443
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
    client-certificate: /var/lib/kubelet/pki/kubelet.pem
    client-key: /var/lib/kubelet/pki/kubelet-key.pem
```

Start and enable the kubelet service

    systemctl daemon-reload
    systemctl start kubelet
    systemctl enable kubelet
    systemctl status kubelet    
    
### Configure the proxy
Lastly, configure the proxy by setting the required options in the ``/etc/systemd/system/kube-proxy.service`` startup file

    [Unit]
    Description=Kubernetes Kube-Proxy Server
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=network.target

    [Service]
    ExecStart=/usr/bin/kube-proxy \
      --cluster-cidr=10.38.0.0/16 \
      --proxy-mode=iptables \
      --kubeconfig=/var/lib/kube-proxy/kubeconfig \
      --v=2

    Restart=on-failure
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target


As a client of the APIs server, the kube-proxy requires its own ``kubeconfig`` context authentication file. The context file for proxy ``/var/lib/kube-proxy/kubeconfig`` should look like this

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/ca.pem
    server: https://kubernetes:6443
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
    client-certificate: /var/lib/kube-proxy/pki/kube-proxy.pem
    client-key: /var/lib/kube-proxy/pki/kube-proxy-key.pem
```

Start and enable the service

    systemctl daemon-reload
    systemctl start kube-proxy
    systemctl enable kube-proxy
    systemctl status kube-proxy

## Define the Network Routes
The cluster should be now running. Check to make sure the cluster can see the nodes, by querying the master

    kubectl get nodes
    
    NAME      STATUS    AGE       VERSION
    kubew03   Ready     12m       v1.8.2
    kubew04   Ready     1m        v1.8.2
    kubew05   Ready     1m        v1.8.2

Now that each worker node is online we need to add routes to make sure that containers running on different machines can talk to each other. On the master node, given ``eth0`` the cluster network interface, create the script file ``/etc/sysconfig/network-scripts/route-eth0`` for adding permanent static routes containing the following

    # The pod network 10.38.3.0/24 is reachable through the worker node kubew03
    10.38.3.0/24 via 10.10.10.83
    
    # The pod network 10.38.4.0/24 is reachable through the worker node kubew04
    10.38.4.0/24 via 10.10.10.84
    
    # The pod network 10.38.2.0/24 is reachable through the worker node kubew05
    10.38.5.0/24 via 10.10.10.85

*Make sure to use the IP address as gateway and not the hostname!*

Restart the network service and check the master routing table

    systemctl restart network
    
    netstat -nr
    Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
    0.0.0.0         10.10.10.1      0.0.0.0         UG        0 0          0 eth0
    10.10.10.0      0.0.0.0         255.255.255.0   U         0 0          0 eth0
    10.38.3.0       10.10.10.83     255.255.255.0   UG        0 0          0 eth0
    10.38.4.0       10.10.10.84     255.255.255.0   UG        0 0          0 eth0
    10.38.5.0       10.10.10.85     255.255.255.0   UG        0 0          0 eth0

On all the worker nodes, create a similar script file. For example, on the worker ``kubew03``, create the file ``/etc/sysconfig/network-scripts/route-eth0`` containing the following

    # The pod network 10.38.4.0/24 is reachable through the worker node kubew04
    10.38.4.0/24 via 10.10.10.84
    
    # The pod network 10.38.5.0/24 is reachable through the worker node kubew05
    10.38.5.0/24 via 10.10.10.85

Restart the network service and check the master routing table

    systemctl restart network
    
    netstat -nr
    Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
    0.0.0.0         10.10.10.1      0.0.0.0         UG        0 0          0 eth0
    10.10.10.0      0.0.0.0         255.255.255.0   U         0 0          0 eth0
    10.38.4.0       10.10.10.84     255.255.255.0   UG        0 0          0 eth0
    10.38.5.0       10.10.10.85     255.255.255.0   UG        0 0          0 eth0
    172.17.0.0      0.0.0.0         255.255.0.0     U         0 0          0 docker0

Repeat the steps for all workers paying attention to set the routes correctly.

## Configure DNS service
To enable service name discovery in our kubernetes cluster, we need to configure an embedded DNS service. To do so, we need to deploy DNS pod and service having configured kubelet to resolve all DNS queries from this local DNS service.

Login to the master node and download the DNS template ``kube-dns.yaml`` from [here](https://github.com/kalise/Kubernetes-Lab-Tutorial/blob/master/examples/addons/kube-dns.yaml)

This template defines a Replica Controller and a DNS service. The controller defines three containers running on the same pod: a DNS server, a dnsmasq for caching, and a sidecar container for health and liveness probe:
```yaml
...
    spec:
      containers:
      - name: kubedns
...
      - name: dnsmasq
...
      - name: sidecar
```

Make sure the file above has the cluster IP address parameter ``clusterIP: 10.32.0.10`` as we have specified in ``--cluster-dns`` option of the kubelet startup configuration 
```yaml
...
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
...
spec:
  clusterIP: 10.32.0.10
...
```

Create the DNS setup from the template

    kubectl create -f kube-dns.yaml

and check if it works in the dedicated namespace

    kubectl get svc -n kube-system
    NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
    kube-dns   ClusterIP   10.32.0.10   <none>        53/UDP,53/TCP   1m


To test if it works, create a file named ``busybox.yaml`` with the following contents:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: default
spec:
  containers:
  - image: busybox
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
    name: busybox
  restartPolicy: Always
```

Then create a pod using this file

    kubectl create -f busybox.yaml
    
wait for pod is running and validate that DNS is working by resolving the kubernetes service

    kubectl exec -ti busybox -- nslookup kubernetes.default.svc.cluster.local
    
    Server:    10.32.0.10
    Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local
    Name:      kubernetes.default.svc.cluster.local
    Address 1: 10.32.0.1 kubernetes.default.svc.cluster.local

Take a look inside the ``resolv.conf file`` of the busybox container
    
    kubectl exec busybox cat /etc/resolv.conf
    nameserver 10.32.0.10
    search kube-system.svc.cluster.local svc.cluster.local cluster.local clastix.io
    options ndots:5

Each time a new service starts on the cluster, it will register with the DNS letting all the pods to reach the new service.
