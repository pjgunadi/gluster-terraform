
variable ssh_user {
    default = "root"
}
variable ssh_password {
    default = ""
}
variable ssh_key {
    default = ""
}
variable gluster_size {
    default = 3
}
variable gluster_ips {
    type = list
}
variable device_name {
    default = "/dev/sdb"
}
variable heketi_ip {
    default = ""
}