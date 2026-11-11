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
      private_key      = try(wireguard_asymmetric_key.peer[name].private_key, null)
      public_key       = coalesce(peer.public_key, try(wireguard_asymmetric_key.peer[name].public_key, null))
      preshared_key    = coalesce(peer.preshared_key, try(wireguard_preshared_key.peer[name].key, null))
      uuid_doh_profile = random_uuid.peer_doh_profile[name].result
      uuid_doh_payload = random_uuid.peer_doh_payload[name].result
      uuid_dot_profile = random_uuid.peer_dot_profile[name].result
      uuid_dot_payload = random_uuid.peer_dot_payload[name].result
    }
  }
}
