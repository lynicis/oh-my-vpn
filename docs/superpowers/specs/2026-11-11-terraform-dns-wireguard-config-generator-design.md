# Terraform DNS & WireGuard Config Generator Design

**Date:** 2026-11-11  
**Status:** Approved

## Intent & Why
To provide a declarative client configuration generator directly in Terraform. Users define peers (e.g. phone, laptop) in Terraform variables, and `terraform apply` automatically generates complete, ready-to-use client artifacts for WireGuard (`.conf`) and native Encrypted DNS (Apple `.mobileconfig` profiles for DoH and DoT, plus Android Private DNS instructions).

## Goals
- Declaratively manage WireGuard client peers in `terraform.tfvars`.
- Generate client configuration bundles saved to local directory `clients/<peer_name>/`.
- Generate Apple `.mobileconfig` payload profiles for zero-touch iOS/macOS DoH (using the randomized secret query path) and DoT.
- Generate standard `wireguard.conf` client profiles with tunnel IP, keys, endpoint, and `DNS = 10.8.0.1`.
- Preserve existing VM peers (`client1`, `client2`, `client3`) without regenerating their keys.
- Output terminal QR code scanning commands and DNS setup guides.

## Non-Goals
- Hosting an interactive web UI dashboard.
- Modifying client devices over the network automatically.

## Approaches Considered
1. **Declarative Peers in Terraform (Selected)**: Terraform manages keys, files, and templates via `OJFord/wireguard`, `hashicorp/local`, and `hashicorp/random`. All client artifacts are written to `./clients/<peer>/`.
2. **Output-Only**: Terraform outputs raw base64 or plaintext strings without writing local files. Dropped because managing multiple files for multiple devices across profiles becomes cumbersome.
3. **VM-Only Generator Script**: Generating files via SSH commands on the VM. Dropped because it moves state out of IaC and requires manual SSH retrieval for each peer.

## Architecture & Interfaces
- **Providers**:
  - `OJFord/wireguard` (~> 0.4): Generates Curve25519 keypairs and PSKs.
  - `hashicorp/local` (~> 2.4): Writes `./clients/<peer>/*` with `0600` permissions.
  - `hashicorp/random` (~> 3.5): Generates UUIDs for Apple `.mobileconfig` payloads.
- **Peer Schema (`var.peers`)**:
  - Map of peer objects:
    ```hcl
    variable "peers" {
      type = map(object({
        ip             = string
        public_key     = optional(string)
        preshared_key  = optional(string)
      }))
      default = {}
    }
    ```
- **Templates**:
  - `templates/wireguard-client.conf.tftpl`: WireGuard client profile.
  - `templates/apple-doh.mobileconfig.tftpl`: Apple DoH profile with random secret path.
  - `templates/apple-dot.mobileconfig.tftpl`: Apple DoT profile.
  - `templates/dns-setup.txt.tftpl`: Android and browser DNS instructions.
