# High Availability Control Plane
For running services without interruption it’s not only the apps that need to be up all the time, but also the Kubernetes Control Plane components. In this section, we’ll configure the control plane to achieve high availability with multiple master nodes. Here the hostnames and addresses:

  * *kubem00* (master) 10.10.10.80
  * *kubem01* (master) 10.10.10.81
  * *kubem02* (master) 10.10.10.82

Make sure to enable DNS resolution for the above hostnames. 

To make kubernetes control plane high available, we need to run multiple instances of:

  * *etcd*
  * *APIs Server*
  * *Controller Manager*
  * *Scheduler*
  
On top of the master nodes, we'll setup a load balancer in order to distribute the requests to all masters. Configure the *kubernetes* hostname to be resolved with the load balancer address. We'll use this name in our configuration files without specifying for a particular hostname.

## Configuring multiple etcd instances

## Configuring multiple APIs servers

## Configuring multiple Controller Managers

## Configuring multiple Schedulers

## Configuring the Load Balancer






