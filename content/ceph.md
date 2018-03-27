# Ceph setup
In this section of the guide, we're going to setup a Ceph cluster to be used as for storage backend in Kubernetes. Our setup is made of three CentOS nodes:

   * ceph00 with IP 10.10.10.90
   * ceph01 with IP 10.10.10.91
   * ceph02 with IP 10.10.10.92

each of one exposing three row devices: ``/dev/sdb``, ``/dev/sdc`` and ``/dev/sdd`` of 16GB. So in total, we'll have 144GB of raw disk space.

All Ceph nodes are provided by a frontend network interface (public) used by Ceph clients to connect the storage cluster and a backend network interface (cluster) used by Ceph nodes for cluster formation and peering. 

## Install Ceph
As installation tool, we're going to use the ``ceph-deploy`` package. Use a separate admin machine where to install the ``ceph-deploy`` tool.

On the admin machine, enable the Ceph repository and install

    yum update 
    yum install ceph-deploy

On the ceph machines, enable the Ceph repository and install the requirements

    yum update
    yum install -y ntp openssh-server

On all machines, creae a dedicated ``cephdeploy`` user with sudo priviledges

    useradd cephdeploy
    passwd cephdeploy
    echo "cephdeploy ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephdeploy
    sudo chmod 0440 /etc/sudoers.d/cephdeploy

and enable passwordless SSH to all ceph nodes. The ``ceph-deploy`` tool will not prompt for a password, so you must generate SSH keys on the admin node and distribute the public key to each Ceph node.

On the admin machine, login as ``cephdeploy`` user and generate the key

    ssh-keygen

and copy it to each Ceph node

for host in \
    ceph00 ceph01 ceph02; \
do ssh-copy-id -i ~/.ssh/id_rsa.pub $host; \
done

Modify the ``~/.ssh/config`` file of the admin node so that the ``ceph-deploy`` tool can log in to Ceph nodes without requiring to specify the username

    Host ceph00
       Hostname ceph00
       User cephdeploy
    Host ceph01
       Hostname ceph01
       User cephdeploy
    Host ceph02
       Hostname ceph02
       User cephdeploy

## Create the Ceph cluster
From the admin machine, login as ``cephdeploy`` user and install Ceph on the nodes

    ceph-deploy new ceph00 ceph01 ceph02

The tool should output a ``ceph.conf`` file in the current directory.

Edit the config file and add the public and cluster networks

    [global]
    fsid = 56520790-675b-4cb0-9d7b-f53ae0cc7b25
    mon_initial_members = ceph00, ceph01, ceph02
    mon_host = 10.10.10.90,10.10.10.91,10.10.10.92
    auth_cluster_required = cephx
    auth_service_required = cephx
    auth_client_required = cephx
    public network = 10.10.10.0/24
    cluster network = 192.168.2.0/24

Now, install the Ceph packages

    ceph-deploy install ceph00 ceph01 ceph02

Deploy the initial monitors and gather the keys

    ceph-deploy mon create-initial

Check the output of the tool in the current directory

    ls -lrt
    total 288
    -rw------- 1 cephdeploy cephdeploy     73 Mar 26 17:01 ceph.mon.keyring
    -rw-rw-r-- 1 cephdeploy cephdeploy    298 Mar 26 17:05 ceph.conf
    -rw------- 1 cephdeploy cephdeploy    129 Mar 26 17:10 ceph.client.admin.keyring
    -rw------- 1 cephdeploy cephdeploy    113 Mar 26 17:10 ceph.bootstrap-mds.keyring
    -rw------- 1 cephdeploy cephdeploy    113 Mar 26 17:10 ceph.bootstrap-osd.keyring
    -rw------- 1 cephdeploy cephdeploy    113 Mar 26 17:10 ceph.bootstrap-rgw.keyring
    -rw-rw-r-- 1 cephdeploy cephdeploy 269548 Mar 26 17:39 ceph-deploy-ceph.log

Copy the configuration file and the admin key to your admin node and your Ceph nodes so that you can use the ceph CLI without having to specify the monitor address and the key

    ceph-deploy admin ceph00 ceph01 ceph02

Add the OSDs daemons on all the Ceph nodes

    ceph-deploy osd create ceph00:/dev/sdb ceph00:/dev/sdc ceph00:/dev/sdd
    ceph-deploy osd create ceph01:/dev/sdb ceph01:/dev/sdc ceph01:/dev/sdd
    ceph-deploy osd create ceph02:/dev/sdb ceph02:/dev/sdc ceph02:/dev/sdd

Login to one of the ceph node and check the cluster’s health

    ceph health

Your cluster should report ``HEALTH_OK``.

View a more complete cluster status with

    ceph -s

If at any point you run into trouble and you want to start over, purge the Ceph packages, erase all its data and all configuration.

From the admin node, as ``cephdeploy`` user

    ceph-deploy purge ceph00 ceph01 ceph02
    ceph-deploy purgedata ceph00 ceph01 ceph02
    ceph-deploy forgetkeys
    rm ./ceph.*

Start over.

