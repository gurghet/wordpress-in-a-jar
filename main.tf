terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

variable "hcloud_token" {
  type = string
}

variable "github_token" {
  type = string
}

resource "hcloud_server" "master_node" {
  name        = "geppetto"
  image       = "ubuntu-20.04"
  server_type = "cax11"
  location    = "fsn1"
  user_data   = templatefile("${path.module}/cloud-init.tpl", {
    github_token  = var.github_token
  })

  ssh_keys = [data.hcloud_ssh_key.gaia_key.id]
}

output "ip_address" {
  value = hcloud_server.master_node.ipv4_address
}

# resource "hcloud_ssh_key" "gaia_key" {
#   name        = "Public key of my MacBook Pro (Gaia)"
#   public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDUAl/qrUV1Nkcd7fPbYAahOAg7p4Nn5+Gkv5Y1lQ/Hm7DqSJki9mmxhtuB/HHV3pZuriAzVJKpee8q8p55EnWhv9xw04oHBXYuJYzkU0kNMiZGMgh/Z8BNkY7QBqitDLOeCNk8gKpKYY0kbINvUaWUNy/JQdmLUu9erCzbkkC0k3KLTlVRr6ZyKuJ6yHX9zYHDJRw9iO+SKA7V/fFVBZtxfYXNN0GaDw6+33z7A7pxbt4wlCuFir2AYTUcU6E2jwrtpq9gwJ0dXiiOW5H/RRGJ1D3VDIcag+Zy7p54K3fH2KOgjujbPq6SS8zJ8/GE+iHCCVxhLnXLin66rRUOIbYVzxPtryX+f4fAxfxTWKLMNWWIVFa11/FOJ792j9MIuYvV/dn3nICsBSQToGQ94A7LoN6W0j4INViHbkzEZVaXQth2urFQ/1NmJGnQkbRR8/XU4ej06WUtie9oGjNY2SXOKVahjBWoybunbtKuv4gtz/XEQKjQDU4T1qXJ6k11jEM= gurghet@Gaia.local"
# }

data "hcloud_ssh_key" "gaia_key" {
  name = "Public key of the Gaia machine"
}
