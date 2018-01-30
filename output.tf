output "heketi_url" {
  value = "http://${element(vsphere_virtual_machine.gluster.*.default_ip_address, 0)}:8080"
}
