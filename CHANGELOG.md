# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- README status line now states what CI actually runs and links this changelog, instead of claiming there is no CI.
- `terraform.tfvars.example` ships a syntactically valid placeholder SSH key, so `terraform plan` succeeds before you replace it.

## [0.2.0] - 2026-11-12

### Added

- GitHub Actions CI on every pull request and push to `main`: `terraform fmt -check`, `init -lockfile=readonly`, `validate`, tflint with the bundled recommended ruleset, and a Trivy config scan that fails on HIGH or CRITICAL findings.
- Tag-driven release workflow: pushing a `vX.Y.Z` tag publishes a GitHub release from that version's CHANGELOG section.
- Dependabot configuration for weekly GitHub Actions and Terraform provider updates.

### Changed

- Bumped the `hashicorp/azurerm` provider from 4.81.0 to 5.13.0 and widened the constraint to `>= 3.0, < 5.14`.
- The dependency lock file is now exported with Linux hashes so CI can verify providers against the committed lock file.
- NSG rules that are intentionally reachable from the internet (WireGuard, DoT, DoH) carry inline Trivy ignore annotations.

## [0.1.0] - 2026-11-12

First public release. Terraform deploys a WireGuard VPN and a private DNS resolver on a single Azure VM.

### Added

- Azure infrastructure for a WireGuard gateway: resource group, VNet, subnet, NSG, static public IP, NIC and an Ubuntu 24.04 LTS VM (`Standard_B2ats_v2`), with cloud-init bootstrap.
- Private DNS stack in cloud-init: Pi-hole with query logging disabled and privacy level 3, recursive DNSSEC-validating unbound on loopback, and dnsdist exposing DoH on 443/tcp and DoT on 853/tcp.
- WireGuard server on `10.8.0.1/24` with automated startup and a per-peer preshared key.
- Server-side `add-wg-client` helper script that allocates the next free `10.8.0.x` address, enrolls the peer, persists it across reboots, writes client configs and prints a QR code.
- Declarative `peers` variable: Terraform generates WireGuard key pairs, preshared keys and Apple DNS profile UUIDs, and accepts existing private keys for peers already provisioned by cloud-init.
- Generated client artifacts per peer in `clients/<name>/`: `wireguard.conf`, `apple-doh.mobileconfig`, `apple-dot.mobileconfig` and `dns-setup.txt`.
- `client_qr_commands` output that prints an absolute-path `qrencode` command per generated peer.
- `doh_secret_path` variable with a random 8-character hex fallback, plus outputs for the DoH URL, DoT endpoint, public IP, SSH connection string and peer public keys.
- Architecture and operations documentation in the README, including known gaps: self-signed DoH/DoT certificate, `custom_data` drift on VM replacement, dnsdist binding a fixed private address, and the single point of failure.
- MIT licence.

### Fixed

- Relaxed dnsdist connection and rate limits so mobile clients on the tunnel resolve reliably.

[Unreleased]: https://github.com/lynicis/oh-my-vpn/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/lynicis/oh-my-vpn/releases/tag/v0.2.0
[0.1.0]: https://github.com/lynicis/oh-my-vpn/releases/tag/v0.1.0
