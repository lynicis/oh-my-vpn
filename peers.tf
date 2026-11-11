# ==============================================================================
# Peer Key Generation & Random UUIDs
# ==============================================================================

locals {
  peers_needing_public_key    = { for name, peer in var.peers : name => peer if peer.public_key == null || peer.public_key == "" }
  peers_needing_preshared_key = { for name, peer in var.peers : name => peer if peer.preshared_key == null || peer.preshared_key == "" }
}

resource "wireguard_asymmetric_key" "peer" {
  for_each = local.peers_needing_public_key
}

resource "wireguard_preshared_key" "peer" {
  for_each = local.peers_needing_preshared_key
}

resource "random_uuid" "peer_doh_profile" {
  for_each = var.peers
}

resource "random_uuid" "peer_doh_payload" {
  for_each = var.peers
}

resource "random_uuid" "peer_dot_profile" {
  for_each = var.peers
}

resource "random_uuid" "peer_dot_payload" {
  for_each = var.peers
}

locals {
  peers_computed = {
    for name, peer in var.peers : name => {
      name             = name
      ip               = peer.ip
      private_key      = peer.private_key != null && peer.private_key != "" ? peer.private_key : try(wireguard_asymmetric_key.peer[name].private_key, null)
      public_key       = coalesce(peer.public_key, try(wireguard_asymmetric_key.peer[name].public_key, null))
      preshared_key    = coalesce(peer.preshared_key, try(wireguard_preshared_key.peer[name].key, null))
      uuid_doh_profile = random_uuid.peer_doh_profile[name].result
      uuid_doh_payload = random_uuid.peer_doh_payload[name].result
      uuid_dot_profile = random_uuid.peer_dot_profile[name].result
      uuid_dot_payload = random_uuid.peer_dot_payload[name].result
    }
  }
}

# ==============================================================================
# Per-Peer Client Configuration Generation
# ==============================================================================

resource "local_file" "wireguard_client_conf" {
  for_each = local.peers_computed

  filename        = "${path.module}/clients/${each.key}/wireguard.conf"
  file_permission = "0600"
  content = templatefile("${path.module}/templates/wireguard-client.conf.tftpl", {
    client_ip          = each.value.ip
    client_private_key = each.value.private_key
    server_public_key  = var.wireguard_server_public_key
    endpoint           = "${var.server_domain_name}:${var.wireguard_port}"
    preshared_key      = each.value.preshared_key
  })
}

resource "local_file" "apple_doh" {
  for_each = local.peers_computed

  filename        = "${path.module}/clients/${each.key}/apple-doh.mobileconfig"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/apple-doh.mobileconfig.tftpl", {
    server_domain_name = var.server_domain_name
    doh_path           = local.doh_path
    payload_uuid       = each.value.uuid_doh_payload
    profile_uuid       = each.value.uuid_doh_profile
  })
}

resource "local_file" "apple_dot" {
  for_each = local.peers_computed

  filename        = "${path.module}/clients/${each.key}/apple-dot.mobileconfig"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/apple-dot.mobileconfig.tftpl", {
    server_domain_name = var.server_domain_name
    server_public_ip   = azurerm_public_ip.wireguard.ip_address
    payload_uuid       = each.value.uuid_dot_payload
    profile_uuid       = each.value.uuid_dot_profile
  })
}

resource "local_file" "dns_setup" {
  for_each = local.peers_computed

  filename        = "${path.module}/clients/${each.key}/dns-setup.txt"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/dns-setup.txt.tftpl", {
    server_domain_name = var.server_domain_name
    server_public_ip   = azurerm_public_ip.wireguard.ip_address
    doh_path           = local.doh_path
  })
}
