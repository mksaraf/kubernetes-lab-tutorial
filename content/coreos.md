# Setup CoreOS Kubernetes
**Tectonic** by **CoreOS** is a Kubernetes ditribution based on **Container Linux**, a minimalistic Linux distribution well designed to run containers. In addition to vanilla Kubernetes, Tectonic comes with a Container Management Platform built on top of kubernetes.

In this section, we're going to setup a Kubernetes cluster on virtual machines using a PXE infrastructure. The same should be easly ported in a bare metal environment. Our cluster will be made of a single master node and three worker nodes:

  * core00.noverit.com (master)
  * core01.noverit.com (worker)
  * core02.noverit.com (worker)
  * core03.noverit.com (worker)

## Requirements



