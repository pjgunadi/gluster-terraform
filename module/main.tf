resource "tls_private_key" "heketikey" {
  algorithm = "RSA"

  provisioner "local-exec" {
    command = "cat > heketi_key <<EOL\n${tls_private_key.heketikey.private_key_pem}\nEOL"
  }
}

resource "null_resource" "create_gluster" {
  count = "${var.gluster_size}"

  connection {
      host = "${element(var.gluster_ips, count.index)}"
      user = "${var.ssh_user}"
      private_key = "${var.ssh_key}"
  }
 
  provisioner "file" {
    source = "${path.module}/scripts/creategluster.sh"
    destination = "/tmp/creategluster.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /root/.ssh && sudo chmod 700 /root/.ssh",
      "echo \"${tls_private_key.ssh.public_key_openssh}\" | sudo tee -a /root/.ssh/authorized_keys && sudo chmod 600 /root/.ssh/authorized_keys",
      "chmod +x /tmp/creategluster.sh && sudo /tmp/creategluster.sh",
      "echo Installation of Gluster is Completed"
    ]
  }
}

resource "null_resource" "create_heketi" {
  depends_on = ["null_resource.create_gluster"]
  count = "${var.heketi_ip == "" ? 0 : 1}"

  connection {
    host = "${var.heketi_ip}"
    user = "${var.ssh_user}"
    #password = "${var.ssh_password}"
    private_key = "${var.ssh_key}"
  }

  provisioner "file" {
    content = "${tls_private_key.heketikey.private_key_pem}"
    destination = "~/heketi_key"
  }

  provisioner "file" {
    source = "${path.module}/scripts/createheketi.sh"
    destination = "/tmp/createheketi.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "[ -f ~/heketi_key ] && sudo mkdir -p /etc/heketi && sudo mv ~/heketi_key /etc/heketi/ && sudo chmod 600 /etc/heketi/heketi_key",
      "[ -f /tmp/createheketi.sh ] && chmod +x /tmp/createheketi.sh && sudo /tmp/createheketi.sh",
      "sudo heketi-cli cluster create | tee /tmp/create_cluster.log"
    ]
  }

}

data "template_file" "create_node_script" {
  count      = "${var.gluster_size}"
  template = "${file("${path.module}/scripts/create_node.tpl")}"
  vars {
    nodeip = "${element(var.gluster_ips, count.index)}"
    nodefile = "${format("/tmp/nodeid-%01d.txt", count.index + 1) }"
    device_name = "${var.device_name}"
  }
}

resource "null_resource" "create_node" {
  depends_on = ["null_resource.create_gluster","null_resource.create_heketi"]
  count      = "${var.gluster_size}"
  connection {
    host = "${var.heketi_ip}"
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

