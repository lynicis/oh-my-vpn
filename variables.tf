variable "admin_ssh_allowed_cidrs" {
  description = "List of IPv4/IPv6 CIDR blocks permitted to access administrative SSH (port 22). Restrict to your trusted IP ranges."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_username" {
  description = "Administrator username for the Linux virtual machine."
  type        = string
  default     = "lynicis"
}

variable "doh_secret_path" {
  description = "Optional custom secret path suffix for DNS-over-HTTPS (e.g. '230a4c95'). If null or empty, a random hex secret is generated."
  type        = string
  default     = null
}

variable "location" {
  description = "The Azure region where all resources will be provisioned. Defaults to Austria East."
  type        = string
  default     = "austriaeast"
}

variable "peers" {
  description = "Map of WireGuard peer configurations to generate."
  type = map(object({
    ip            = string
    public_key    = optional(string)
    preshared_key = optional(string)
  }))
  default = {}
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group."
  type        = string
  default     = "rg-wireguard-vpn"
}

variable "ssh_public_key" {
  description = "SSH public key content (e.g. ~/.ssh/id_rsa.pub or ~/.ssh/id_ed25519.pub) for authenticating as admin_username."
  type        = string
}

variable "server_domain_name" {
  description = "Domain name / FQDN assigned to the WireGuard and DNS server (e.g. dns.lynicis.dev)."
  type        = string
  default     = "dns.lynicis.dev"
}

variable "vm_size" {
  description = "Azure Virtual Machine SKU size. Defaults to Standard_B2ats_v2."
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "wireguard_port" {
  description = "UDP port for incoming WireGuard tunnel traffic."
  type        = number
  default     = 51820
}
