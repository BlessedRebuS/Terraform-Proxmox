# Terraform-Proxmox

Provision your Proxmox instances with [Telmate Terraform provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs).

## Prerequisites
1) A Proxmox instance running with root access
2) A specific Proxmox role for Terraform and a custom Terraform User
3) Terraform installed on your machine

To add the roles, as explained on the Terraform provider:
```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt"
pveum user add terraform-prov@pve --password <password>
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```
Depending on your choice, the API Connection can be done by password
```bash
export PM_USER="terraform-prov@pve"
export PM_PASS="password"
```
or by token (suggested)
```bash
export PM_API_TOKEN_ID="terraform-prov@pve!mytoken"
export PM_API_TOKEN_SECRET="afcd8f45-acc1-4d0f-bb12-a70b0777ec11"
```
To connect the Proxmox instance it is also mandatory to specify the **pm_api_url** in the Terraform files

```bash
pm_api_url = "https://<YOUR-PROXMOX-ADDRESS>:8006/api2/json"
```

---
## Terraform

In the file `lxc_main.tf` there is a template for provisioning LXC Containers. 
The variables are specified in the file `variables.tf`.

It is also useful to create a `terraform.tfvars` file that has the definitions of the used variables. If the terraform.tfvars is not present, the variables will be asked by the Terraform terminal.


The terraform.tfvars file must have the following format

```terraform
pm_api_url      = "http://192.168.1.22:8006/api2/json"
node            = "node1"
hostname        = "terraform-deploy"
ostemplate      = "HDD-Data:vztmpl/ubuntu-20.04-standard_20.04-1_amd64.tar.gz"
pool_name       = "CT"
unprivileged    = false
memory          = "1024"
cores           = "2"
start           = true
storage         = "HDD-Data"
storage_size    = "8G"
nic_name        = "eth0"
bridge_name     = "vmbr0"
gateway_address = "192.168.1.1"
ipv4_address    = "192.168.1.210/24"
```

## Connection
The `local-exec` provisioner generates the ssh keys to connect to the created instance. It creates a new **pem** key with the name **terraform-key-pair.pem**.
```terraform
  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.dev_key.private_key_pem}' > ./'${var.generated_key_name}'.pem
      chmod 400 ./'${var.generated_key_name}'.pem
    EOT
  }
```
If the connection is done through Proxmox interface, the root password is printed in the terminal by the following block
```terraform
output "password" {
  value = nonsensitive(random_password.password.result)
  sensitive = false
}
```

## Mounting volumes

### Bind mount
Volume mounts can require more or less privileges in the Proxmox environment. The following example is a [bind mount](https://unix.stackexchange.com/questions/198590/what-is-a-bind-mount) that from the storage `HDD-Data` mounts internally in the container at the location `/sharedstorage` the directory of the volume located at `/mnt/pve/HDD-Shared/shared` in the Proxmox node. This mount is shared between the node and all the containers that implement it.
Due to a Proxmox bug it is required to be authenticated with the Username and Password of the root@pam account. Having a token authorization here cause an error 403 permission denied, because only the root@pam user can operate at a very low privilege like a bind mounting volumes.
```terraform
  mountpoint {
    key     = "100"
    slot    = 0
    storage = "HDD-Data"
    mp      = "/sharedstorage"
    volume  = "/mnt/pve/HDD-Shared/shared"
    size    = "12G"
    shared  = true
  }
```

### Device mount
This mount point is used to "mirror" the mount point in the Proxmox environment inside the containers. This setup mounts the device `/dev/sda` of the Proxmox node at `/mnt/container/device-mount-point` in the container. It requires root@pam privileges.
```terraform
  mountpoint {
    key     = "100"
    slot    = 0
    storage = "/dev/sda"
    volume  = "/dev/sda"
    mp      = "/mnt/container/device-mount-point"
    size    = "32G"
  }
```

### Storage mount
It is used when additional capacity is required in the container. In this case it adds 32G of storage in a folder located at `/mnt/container/device-mount-point` from the Disk `HDD-Data`. This mount doesn't require additional privileges.
```terraform
  mountpoint {
    key     = "100"
    slot    = 0
    storage = "HDD-Data"
    mp      = "/mnt/container/device-mount-point"
    size    = "32G"
  }
```
