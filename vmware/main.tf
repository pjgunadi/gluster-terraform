provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "${var.datacenter}"
}

data "vsphere_datastore" "datastore" {
  count         = "${length(var.datastore)}"
  name          = "${element(var.datastore,count.index)}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.network}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${lookup(var.template,var.osfamily)}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"

  provisioner "local-exec" {
    command = "cat > heketi_key <<EOL\n${tls_private_key.ssh.private_key_pem}\nEOL"
  }
}
//gluster
resource "vsphere_virtual_machine" "gluster" {
  lifecycle {
    ignore_changes = ["disk.0","disk.1"]                                                                                                       
  }

  count            = "${var.gluster["nodes"]}"
  name             = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.gluster["name"]),count.index + 1) }"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${element(data.vsphere_datastore.datastore.*.id, ( count.index ) % length(var.datastore))}"

  num_cpus = "${var.gluster["cpu_cores"]}"
  memory   = "${var.gluster["memory"]}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "${format("%s-%s-%01d.vmdk", lower(var.instance_prefix), lower(var.gluster["name"]),count.index + 1) }"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  disk {
    label             = "${format("%s-%s-%01d_1.vmdk", lower(var.instance_prefix), lower(var.gluster["name"]),count.index + 1) }"
    size             = "${var.gluster["data_disk"]}"
    unit_number      = 1
    eagerly_scrub    = false
    thin_provisioned = false
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.gluster["name"]),count.index + 1) }"
        domain    = "${var.vm_domain}"
        time_zone = "${var.timezone}"
      }

      network_interface {
        ipv4_address = "${trimspace(element(split(",",var.gluster["ipaddresses"]),count.index))}"
        ipv4_netmask = "${var.gluster["netmask"]}"
      }

      ipv4_gateway = "${var.gluster["gateway"]}"
      dns_server_list = "${var.dns_list}"
    }
  }
	
connection {
    type = "ssh"
    user = "${var.ssh_user}"
    password = "${var.ssh_password}"
  }
 
  provisioner "file" {
    content = "${count.index == 0 ? tls_private_key.ssh.private_key_pem : "none"}"
    destination = "${count.index == 0 ? "~/heketi_key" : "/dev/null" }"
  }

  provisioner "file" {
    content = "${count.index == 0 ? file("scripts/createheketi.sh") : "none"}"
    destination = "${count.index == 0 ? "/tmp/createheketi.sh" : "/dev/null" }"
  }

  provisioner "file" {
    source = "scripts/creategluster.sh"
    destination = "/tmp/creategluster.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo ${var.ssh_password} | sudo -S echo",
      "echo \"${var.ssh_user} ALL=(ALL) NOPASSWD:ALL\" | sudo tee /etc/sudoers.d/${var.ssh_user}",
      "sudo sed -i /^127.0.1.1.*$/d /etc/hosts",
      "[ ! -d $HOME/.ssh ] && mkdir $HOME/.ssh && chmod 700 $HOME/.ssh",
      "echo \"${tls_private_key.ssh.public_key_openssh}\" | tee -a $HOME/.ssh/authorized_keys && chmod 600 $HOME/.ssh/authorized_keys",
      "sudo mkdir /root/.ssh && sudo chmod 700 /root/.ssh",
      "echo \"${tls_private_key.ssh.public_key_openssh}\" | sudo tee -a /root/.ssh/authorized_keys && sudo chmod 600 /root/.ssh/authorized_keys",
      "[ -f ~/heketi_key ] && sudo mkdir -p /etc/heketi && sudo mv ~/heketi_key /etc/heketi/ && sudo chmod 600 /etc/heketi/heketi_key",
      "chmod +x /tmp/creategluster.sh && sudo /tmp/creategluster.sh",
      "[ -f /tmp/createheketi.sh ] && chmod +x /tmp/createheketi.sh && sudo /tmp/createheketi.sh",
      "echo Installation of Gluster is Completed"
    ]
  }
}

resource "null_resource" "create_cluster" {
  connection {
    host = "${vsphere_virtual_machine.gluster.0.default_ip_address}"
    user = "${var.ssh_user}"
    #password = "${var.ssh_password}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo heketi-cli cluster create | tee /tmp/create_cluster.log"
    ]
  }

}

data "template_file" "create_node_script" {
  count      = "${var.gluster["nodes"]}"
  template = "${file("scripts/create_node.tpl")}"
  vars {
    nodeip = "${element(vsphere_virtual_machine.gluster.*.default_ip_address, count.index)}"
    nodefile = "${format("/tmp/nodeid-%01d.txt", count.index + 1) }"
  }
}

resource "null_resource" "create_node" {
  depends_on = ["null_resource.create_cluster"]
  count      = "${var.gluster["nodes"]}"
  connection {
    host = "${vsphere_virtual_machine.gluster.0.default_ip_address}"
    user = "${var.ssh_user}"
    #password = "${var.ssh_password}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
  }

  provisioner "file" {
    content = "${element(data.template_file.create_node_script.*.rendered, count.index)}"
    destination = "/tmp/createnode-${count.index}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createnode-${count.index}.sh && sudo /tmp/createnode-${count.index}.sh"
    ]
  }

}

