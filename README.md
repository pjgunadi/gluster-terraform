# Terraform Template for Gluster and Heketi Deployment in VMware vSphere

## Before you start
Install your VMware cluster environment

## Summary
This terraform template perform the following tasks:
- Provision VMs for Gluster Storage.
- Install Heketi on the first VM

## Input
| Variable      | Description    | Sample Value |
| ------------- | -------------- | ------------ |
| vsphere_server| vCenter Server | 192.168.1.1  |
| vsphere_user  | vCenter User   | admin |
| vsphere_password | vCenter Password | xxxxx |
| datacenter | vSphere Datacenter Name | dc01 |
| datastore | vSphere Datastore | datastore01 |
| resource_pool | vSphere Cluster Resource Pool | cluster1/Resources |
| network | vSphere Cluster Network | VM Network |
| osfamily | Operating System | ubuntu |
| template | Image Template | ubuntu_base_image |
| ssh_user | Login user to Image Template | admin |
| ssh_password | Login password to ICP Template | xxxxx |
| vm_domain | Server Domain | domain.com |
| timezone | Timezone | Asia/Singapore |
| dns_list | DNS List | ["192.168.1.53","192.168.1.54"] |
| instance_prefix | VM Instance Prefix | zr |
| gluster | Gluster nodes information | *see default values in variables.tf* |

## Deployment step from Terraform CLI
1. Clone this repository: `git clone https://github.com/pjgunadi/gluster-terraform.git`
2. [Download terraform](https://www.terraform.io/) if you don't have one
3. Create terraform variable file with your input value e.g. `terraform.tfvars`
4. Apply terraform template
```
terraform init
terraform plan
terraform apply
```
## Limitations
- The template currently available only for Ubuntu. You can modify the script files in `scripts/` for other linux flavor
