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

Make sure the network space and addresses above match with your environment. In some cases, you already have a DHCP and DNS servers in place. In that case, run a proxy-DHCP and TFTP service on the host network
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

Make sure no firewall is blocking DHCP, DNS and TFTP traffic on the host network.





