terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.9.14"
    }
    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

provider "proxmox" {
  pm_api_url  = var.pm_api_url
  pm_debug    = true
  pm_parallel = 10
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#-_=+?"
}

resource "tls_private_key" "dev_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "proxmox_lxc" "basic" {
  target_node  = var.node
  hostname     = var.hostname
  ostemplate   = var.ostemplate
  pool         = var.pool_name 
  password     = random_password.password.result
  unprivileged = var.unprivileged
  memory       = var.memory
  cores        = var.cores
  start        = var.start

  # auto create ssh key pair
  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.dev_key.private_key_pem}' > ./'${var.generated_key_name}'.pem
      chmod 400 ./'${var.generated_key_name}'.pem
    EOT
  }

  ssh_public_keys = tls_private_key.dev_key.public_key_openssh

  rootfs {
    storage = var.storage
    size    = var.storage_size
  }

  network {
    name   = var.nic_name
    bridge = var.bridge_name
    gw     = var.gateway_address
    ip     = var.ipv4_address
    ip6    = "auto"
  }

  # a bind mountpoint requires high privileges. use the root@pam password authentication to work
  # mountpoint {
  #   key     = "100"
  #   slot    = 0
  #   storage = "HDD-Data"
  #   mp      = "/sharedstorage"
  #   volume  = "/mnt/pve/HDD-Shared/shared"
  #   size    = "12G"
  #   shared  = true
  # }

  # storage mountpoint for additional space
  # mountpoint {
  #   key     = "100"
  #   slot    = 0
  #   storage = "HDD-Data"
  #   mp      = "/mnt/container/device-mount-point"
  #   size    = "32G"
  # }
}

# root password of the container
output "password" {
  value = nonsensitive(random_password.password.result)
  sensitive = false
}

# ssh pub key of the container
output "public-key" {
  value = tls_private_key.dev_key.public_key_openssh
}