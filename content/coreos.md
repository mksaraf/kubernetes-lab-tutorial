# Setup CoreOS Kubernetes
**Tectonic** by **CoreOS** is a Kubernetes ditribution based on **Container Linux**, a minimalistic Linux distribution well designed to run containers. In addition to vanilla Kubernetes, Tectonic comes with a Container Management Platform built on top of kubernetes.

In this section, we're going to setup a Kubernetes cluster on virtual machines using a PXE infrastructure. The same should be easly ported in a bare metal environment. Our cluster will be made of a single master node and three worker nodes:

  * core00.noverit.com (master)
  * core01.noverit.com (worker)
  * core02.noverit.com (worker)
  * core03.noverit.com (worker)

These are the minimum requirements for Container Linux machines:

 * 2 Core CPU
 * 8 GB RAM
 * 32 GB HDD
 * 1 Gb NIC

An additional machine with any Linux OS will be used as provisioner machine.

## Preflight
To setup a Tectonic cluster on virtual or bare metal nodes, we'll require the following items:

 * [Tectonic](https://coreos.com/tectonic) account license and secret
 * Bare metal or virtual machines with BIOS options set to boot from hard disk, first, and then network
 * PXE network boot environment with DHCP, TFTP, and DNS services
 * [Matchbox](https://github.com/coreos/matchbox) server that provisions Container Linux on the nodes
 * [Terraform](https://www.terraform.io/) that creates Container Linux profiles
 * SSH keypair to login into Container Linux nodes

### Tectonic license
Copy the account license ``tectonic-license.txt`` and secret ``config.json`` files you downloaded from the CoreOS web site to the provisioner machine.

### Bare metal or virtual machines
Configure the machines to boot from disk first and then from network via PXE boot. Take note of the MAC address of each machine.

### PXE network environment
Login to the provisioner machine and configure DHCP, TFTP, and DNS services to make machines bootable from PXE boot. You can go with a dnsmasq service implementing all the functions above as container.

Install and configure Docker on the provisioner machine

    yum install -y docker
    systemctl start docker
    systemctl enable docker

Run DHCP, TFTP, and DNS on the host network
```bash
docker run --cap-add=NET_ADMIN --net=host --name dnsmasq quay.io/coreos/dnsmasq -d \
  --dhcp-range=10.10.10.200,10.10.10.250 \
  --enable-tftp --tftp-root=/var/lib/tftpboot \
  --dhcp-match=set:bios,option:client-arch,0 \
  --dhcp-boot=tag:bios,undionly.kpxe \
  --dhcp-match=set:efi32,option:client-arch,6 \
  --dhcp-boot=tag:efi32,ipxe.efi \
  --dhcp-match=set:efibc,option:client-arch,7 \
  --dhcp-boot=tag:efibc,ipxe.efi \
  --dhcp-match=set:efi64,option:client-arch,9 \
  --dhcp-boot=tag:efi64,ipxe.efi \
  --dhcp-userclass=set:ipxe,iPXE \
  --dhcp-boot=tag:ipxe,http://matchbox.noverit.com:8080/boot.ipxe \
  --address=/matchbox.noverit.com/10.10.10.2 \
  --log-queries \
  --log-dhcp
```

Make sure the network space and addresses above match with your environment.

In some cases, you already have a DHCP and DNS servers in place. In that case, run a proxy-DHCP and TFTP service on the host network instead
```bash
docker run --cap-add=NET_ADMIN --net=host --name dnsmasq quay.io/coreos/dnsmasq -d \
  --dhcp-range=10.10.10.0,proxy,255.255.255.0 \
  --enable-tftp --tftp-root=/var/lib/tftpboot \
  --dhcp-userclass=set:ipxe,iPXE \
  --pxe-service=tag:#ipxe,x86PC,"PXE chainload to iPXE",undionly.kpxe \
  --pxe-service=tag:ipxe,x86PC,"iPXE",http://matchbox.noverit.com:8080/boot.ipxe \
  --log-queries \
  --log-dhcp  
```

In both cases, make sure no firewall is blocking DHCP, DNS and TFTP traffic on the host network.

### Matchbox
We're going to setup the Matchbox service on the provisioner machine. Matchbox is a service for network booting and provisioning machines to create CoreOS Container Linux clusters.

Download the latest matchbox to the provisioner machine

     MATCHBOX=v0.7.0
     wget https://https://github.com/coreos/matchbox/releases/download/$MATCHBOX/matchbox-$MATCHBOX-linux-amd64.tar.gz

and untar it and install on the appropriate path

    tar xzvf matchbox-$MATCHBOX-linux-amd64.tar.gz
    cd matchbox-$MATCHBOX-linux-amd64
    cp matchbox /usr/local/bin

The matchbox service should be run by a non-root user with access to the matchbox ``/var/lib/matchbox`` data directory 

useradd -U matchbox
mkdir -p /var/lib/matchbox/assets
chown -R matchbox:matchbox /var/lib/matchbox
cp contrib/systemd/matchbox-local.service /etc/systemd/system/matchbox.service

Customize matchbox system file as following:

    [Unit]
    Description=CoreOS matchbox Server
    Documentation=https://github.com/coreos/matchbox

    [Service]
    User=matchbox
    Group=matchbox
    Environment="MATCHBOX_ADDRESS=0.0.0.0:8080"
    Environment="MATCHBOX_LOG_LEVEL=debug"
    Environment="MATCHBOX_RPC_ADDRESS=0.0.0.0:8081"
    ExecStart=/usr/local/bin/matchbox

    # systemd.exec
    ProtectHome=yes
    ProtectSystem=full

    [Install]
    WantedBy=multi-user.target

The Matchbox RPC APIs allow clients to create and update resources in Matchbox through a secure channel. TLS credentials are needed for client authentication. Please note, that PXE booting machines use the HTTP APIs and do not use credentials.

Create a self-signed Certification Authority and a keys pair

    export SAN=DNS.1:matchbox.noverit.com,DNS.2=matchbox,IP:10.10.10.2
    ./scripts/cert-gen

The above will produce the following

    ls -l 
    -rw-r--r-- 1 root root 1814 Apr 11 09:51 ca.crt
    -rw-r--r-- 1 root root 1679 Apr 11 09:51 server.crt
    -rw-r--r-- 1 root root 1679 Apr 11 09:51 server.key
    -rw-r--r-- 1 root root 1578 Apr 11 09:52 client.crt
    -rw-r--r-- 1 root root 1679 Apr 11 09:52 client.key

Copy the server credentials to the matchbox default location

    mkdir -p /etc/matchbox
    cp ca.crt server.crt server.key /etc/matchbox

Copy the client credentials to the home location of the current user

    mkdir -p ~/.matchbox
    cp client.crt client.key ca.crt ~/.matchbox/

Start, enable, and verify the matchbox service

    systemctl daemon-reload 
    systemctl start matchbox
    systemctl enable matchbox
    systemctl status matchbox

Make sure the matchbox service is reachable by name

    nslookup matchbox.noverit.com

Verify the service can be reacheble by clients

    curl http://matchbox.noverit.com:8080    
    openssl s_client -connect matchbox.noverit.com:8081 -CAfile ca.crt -cert client.crt -key client.key

Download the Container Linux OS stable image to the matchbox ``/var/lib/matchbox`` data directory

    COREOS=1688.5.3
    ./scripts/get-coreos stable $COREOS /var/lib/matchbox/assets
    tree /var/lib/matchbox/assets
    /var/lib/matchbox/assets
    `-- coreos
        `-- 1688.5.3
            |-- CoreOS_Image_Signing_Key.asc
            |-- coreos_production_image.bin.bz2
            |-- coreos_production_image.bin.bz2.sig
            |-- coreos_production_pxe_image.cpio.gz
            |-- coreos_production_pxe_image.cpio.gz.sig
            |-- coreos_production_pxe.vmlinuz
            |-- coreos_production_pxe.vmlinuz.sig
            `-- version.txt

and verify the images are accessible from clients

    curl http://matchbox.noverit.com:8080/assets/coreos/$COREOS/

