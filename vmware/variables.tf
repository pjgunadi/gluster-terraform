variable vsphere_user {
    description = "vCenter user"
}
variable vsphere_password {
    description = "vCenter password"
}
variable vsphere_server {
    description = "vCenter server"
}
variable datacenter {
    description = "vCenter Datacenter"
}
variable datastore {
    description = "vCenter Datastore"
    type = "list"
    default = ["v3700_vol3_datastore", "v3700_vol4_datastore", "v3700_vol5_datastore"]
}
variable resource_pool {
    description = "vCenter Cluster/Resource pool"
}
variable network {
    description = "vCenter Network"
    default = "VM Network"
}
variable osfamily {
    description = "Operating System"
    default = "ubuntu"
}
variable template {
    description = "VM Template"
    type = "map"
    default = {
        "redhat"="rhel74_base"
        "ubuntu"="ubuntu1604_base"
    }
}
variable ssh_user {
    description = "VM Username"
}
variable ssh_password {
    description = "VM Password"
}
variable vm_domain {
    description = "VM Domain"
}
variable timezone {
    description = "Time Zone"
    default = "Asia/Singapore"
}
variable dns_list {
    description = "DNS List"
    type = "list"
}
variable "instance_prefix" {
    default = "zr"
}
variable "gluster" {
  type = "map"
  default = {
    nodes       = "3"
    name        = "gluster"
    cpu_cores   = "2"
    data_disk   = "100" // GB
    memory      = "2048"
    ipaddresses = "192.168.66.94,192.168.66.95,192.168.66.96"
    netmask     = "21"
    gateway     = "192.168.64.1"
  }
}
