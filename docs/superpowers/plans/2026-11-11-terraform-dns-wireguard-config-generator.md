# Terraform DNS & WireGuard Config Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable declarative generation of WireGuard client configurations (`.conf`) and native Encrypted DNS profiles (Apple `.mobileconfig` for DoH and DoT, plus Android setup) directly via Terraform into `./clients/<peer_name>/`.

**Architecture:** Define peers declaratively in `terraform.tfvars`. Use `OJFord/wireguard` for Curve25519 keypair and PSK generation, `hashicorp/random` for RFC 4122 UUIDs, and `hashicorp/local` for generating permission-secured client configuration bundles. Keep existing live VM peers preserved without breaking connections.

**Tech Stack:** Terraform, HCL, `OJFord/wireguard`, `hashicorp/local`, `hashicorp/random`, Apple MobileConfig XML (plist), WireGuard `.conf`.

**Spec:** `docs/superpowers/specs/2026-11-11-terraform-dns-wireguard-config-generator-design.md`

## Global Constraints
- Client `.conf` files containing private keys and pre-shared keys MUST be written with `0600` permissions.
- Client directories under `clients/` containing secrets MUST be ignored by `.gitignore`.
- Existing live VM peers (`client1`, `client2`, `client3`) MUST have their existing public keys and PSKs preserved to prevent dropping connections.
- Apple `.mobileconfig` profiles MUST conform to valid Apple property list XML and pass `plutil -lint`.
- The live VM MUST NOT be destroyed or recreated (`ignore_changes = [custom_data]` preserved).

## Review Focus
- A peer with an explicitly provided `public_key` and `preshared_key` must not have new keys generated.
- A peer without keys must automatically have a valid Curve25519 keypair and 256-bit PSK generated.
- `apple-doh.mobileconfig` must resolve the active randomized `doh_path` (`/dns-query-...`).
- `apple-dot.mobileconfig` must specify port 853 and server domain name.
- Running `terraform apply` must generate all files cleanly without modifying the live VM.

---

### Task 1: Provider Setup & Peer Variable Definition

**Files:**
- Modify: `versions.tf`
- Modify: `variables.tf`
- Modify: `terraform.tfvars`
- Modify: `terraform.tfvars.example`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `var.peers` map in `variables.tf` and installed `OJFord/wireguard` + `hashicorp/local` providers.

- [ ] **Step 1: Update `.gitignore` to protect generated client secrets**
Add `clients/` and `*.mobileconfig` to `.gitignore`.

- [ ] **Step 2: Add `wireguard` and `local` providers to `versions.tf`**
Add `OJFord/wireguard` (~> 0.4.1) and `hashicorp/local` (~> 2.4) to `required_providers`.

- [ ] **Step 3: Define `variable "peers"` in `variables.tf`**
Add `peers` typed as:
```hcl
variable "peers" {
  description = "Map of WireGuard peer configurations to generate."
  type = map(object({
    ip            = string
    public_key    = optional(string)
    preshared_key = optional(string)
  }))
  default = {}
}
```

- [ ] **Step 4: Add existing VM peers to `terraform.tfvars`**
Define `client1`, `client2`, and `client3` in `terraform.tfvars` with their exact IP, public key, and preshared key from the live VM.

- [ ] **Step 5: Run `terraform init` and `terraform validate`**
Run: `terraform init && terraform validate`
Expected: Providers installed successfully and configuration valid.

- [ ] **Step 6: Commit**
```bash
git add versions.tf variables.tf terraform.tfvars.example .gitignore .terraform.lock.hcl
git commit -m "feat(infra): add wireguard and local providers and peer variables"
```

---

### Task 2: Peer Key Generation & Random UUIDs

**Files:**
- Create: `peers.tf`

**Interfaces:**
- Consumes: `var.peers`, `random_id.doh_secret`, `var.server_domain_name`
- Produces: `local.peers_computed` (map containing `name`, `ip`, `private_key`, `public_key`, `preshared_key`, `uuid_doh_profile`, `uuid_doh_payload`, `uuid_dot_profile`, `uuid_dot_payload`).

- [ ] **Step 1: Write peer key generation logic in `peers.tf`**
- Use `wireguard_asymmetric_key.peer` for peers where `public_key` is null.
- Use `wireguard_preshared_key.peer` for peers where `preshared_key` is null.
- Use `random_uuid` for Apple profile and payload UUIDs per peer.
- Build `locals { peers_computed = { ... } }` resolving final keys.

- [ ] **Step 2: Validate plan with `terraform plan`**
Run: `terraform plan`
Expected: Configuration compiles, random UUIDs and keys planned for any new peer without touching Azure VM resources.

- [ ] **Step 3: Commit**
```bash
git add peers.tf
git commit -m "feat(infra): implement declarative peer key and uuid generation"
```

---

### Task 3: Client & DNS Profile Templates

**Files:**
- Create: `templates/wireguard-client.conf.tftpl`
- Create: `templates/apple-doh.mobileconfig.tftpl`
- Create: `templates/apple-dot.mobileconfig.tftpl`
- Create: `templates/dns-setup.txt.tftpl`

**Interfaces:**
- Consumes: `local.peers_computed`, `server_domain_name`, `server_public_ip`, `wireguard_port`, `doh_path`.
- Produces: Rendered templates for `.conf`, `.mobileconfig`, and `.txt`.

- [ ] **Step 1: Create `templates/wireguard-client.conf.tftpl`**
WireGuard client config with Interface IP, PrivateKey (if available), DNS = 10.8.0.1, Peer PublicKey, Endpoint, AllowedIPs = 0.0.0.0/0, PresharedKey, PersistentKeepalive = 25.

- [ ] **Step 2: Create `templates/apple-doh.mobileconfig.tftpl`**
Apple configuration profile using `com.apple.dnsSettings.managed` with `DNSProtocol = HTTPS` and `ServerURL = https://${server_domain_name}${doh_path}`.

- [ ] **Step 3: Create `templates/apple-dot.mobileconfig.tftpl`**
Apple configuration profile using `com.apple.dnsSettings.managed` with `DNSProtocol = TLS`, `ServerName = ${server_domain_name}`, and `ServerAddresses = [${server_public_ip}]`.

- [ ] **Step 4: Create `templates/dns-setup.txt.tftpl`**
Text file explaining Android Private DNS (`${server_domain_name}`) and browser DoH URL (`https://${server_domain_name}${doh_path}`).

- [ ] **Step 5: Commit**
```bash
git add templates/wireguard-client.conf.tftpl templates/apple-doh.mobileconfig.tftpl templates/apple-dot.mobileconfig.tftpl templates/dns-setup.txt.tftpl
git commit -m "feat(templates): add client templates for wireguard and apple encrypted dns"
```

---

### Task 4: Local File Generation & Outputs

**Files:**
- Modify: `peers.tf`
- Modify: `outputs.tf`

**Interfaces:**
- Consumes: Templates and `local.peers_computed`.
- Produces: Files in `./clients/<peer_name>/*` and descriptive Terraform outputs.

- [ ] **Step 1: Add `local_file` resources to `peers.tf`**
Generate:
- `clients/${each.key}/wireguard.conf` (permissions 0600)
- `clients/${each.key}/apple-doh.mobileconfig` (permissions 0644)
- `clients/${each.key}/apple-dot.mobileconfig` (permissions 0644)
- `clients/${each.key}/dns-setup.txt` (permissions 0644)

- [ ] **Step 2: Update `outputs.tf`**
Output:
- `generated_clients`: list of peer names generated.
- `client_configs_dir`: path to `./clients`.
- `client_qr_commands`: map of commands to print QR code for each client.

- [ ] **Step 3: Test generation with `terraform apply`**
Run: `terraform apply -auto-approve`
Expected: Files written to `./clients/*` with correct permissions.

- [ ] **Step 4: Lint Apple `.mobileconfig` profiles**
Run: `plutil -lint clients/*/apple-*.mobileconfig`
Expected: All `.mobileconfig` files report `OK`.

- [ ] **Step 5: Commit**
```bash
git add peers.tf outputs.tf
git commit -m "feat(infra): add local file generation for wireguard and dns profiles"
```

---

### Task 5: End-to-End Verification & Health Check

**Files:**
- None (verification only)

- [ ] **Step 1: Verify clean Terraform plan**
Run: `terraform plan`
Expected: `No changes. Your infrastructure matches the configuration.`

- [ ] **Step 2: Test DoH and WireGuard on live VM**
Run: `ssh lynicis-vpn "sudo systemctl is-active wg-quick@wg0 dnsdist pihole-FTL unbound"`
Expected: All services active.

- [ ] **Step 3: Test generated QR code command**
Run QR command on one generated client config to verify it prints properly.
