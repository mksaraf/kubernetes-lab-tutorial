# Ceph setup
In this section of the guide, we're going to setup a Ceph cluster to be used as for storage backend in Kubernetes. Our setup is made of three nodes:

   * ceph00 with IP 10.10.10.90
   * ceph01 with IP 10.10.10.91
   * ceph02 with IP 10.10.10.92

each of one exposing three row devices: ``/dev/sdb``, ``/dev/sdc`` and ``/dev/sdd`` of 16GB. So in total, we'll have 144GB of raw disk space.


