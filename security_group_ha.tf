# ============================================================================
# Security Group - Public
# Attached to: port1 (external) and port4 (HA management) on both FortiGates
# Inbound : self-referencing — only traffic from within this SG (inter-FGT)
# Outbound: restricted to FortiGuard services required for licensing/DNS/updates
# ============================================================================

resource "ibm_is_security_group" "fgt_sg_public" {
  name           = "${var.CLUSTER_NAME}-sg-public-${random_string.random_suffix.result}"
  vpc            = data.ibm_is_vpc.vpc1.id
  resource_group = data.ibm_resource_group.rg.id
}

# Inbound — allow traffic only from interfaces in this same SG (inter-FGT).
# Both FGT VNIs on port1/port4 share this SG, so only traffic originating
# from these two instances is permitted — nothing external.
resource "ibm_is_security_group_rule" "fgt_public_inbound_self" {
  group     = ibm_is_security_group.fgt_sg_public.id
  direction = "inbound"
  remote    = ibm_is_security_group.fgt_sg_public.id
  name      = "allow-inbound-from-same-sg"
}

# Outbound — UDP 53 for FortiGuard DNS & SDNS queries
resource "ibm_is_security_group_rule" "fgt_public_outbound_dns" {
  group     = ibm_is_security_group.fgt_sg_public.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  name      = "allow-outbound-fortiguard-dns-udp-53"
  protocol  = "udp"
  port_min  = 53
  port_max  = 53
}

# Outbound — TCP 853 for DNS over TLS (DoT)
resource "ibm_is_security_group_rule" "fgt_public_outbound_dot" {
  group     = ibm_is_security_group.fgt_sg_public.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  name      = "allow-outbound-dns-over-tls-tcp-853"
  protocol  = "tcp"
  port_min  = 853
  port_max  = 853
}

# Outbound — TCP 443 for licensing, FortiCare & entitlements
resource "ibm_is_security_group_rule" "fgt_public_outbound_https" {
  group     = ibm_is_security_group.fgt_sg_public.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  name      = "allow-outbound-fortiguard-licensing-tcp-443"
  protocol  = "tcp"
  port_min  = 443
  port_max  = 443
}

# Outbound — TCP 8890 for FortiGuard distribution updates
resource "ibm_is_security_group_rule" "fgt_public_outbound_fortiguard_updates" {
  group     = ibm_is_security_group.fgt_sg_public.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  name      = "allow-outbound-fortiguard-updates-tcp-8890"
  protocol  = "tcp"
  port_min  = 8890
  port_max  = 8890
}

# Outbound — UDP 123 for NTP time synchronization
resource "ibm_is_security_group_rule" "fgt_public_outbound_ntp" {
  group     = ibm_is_security_group.fgt_sg_public.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  name      = "allow-outbound-ntp-udp-123"
  protocol  = "udp"
  port_min  = 123
  port_max  = 123
}


# Inbound — TCP 22 for CI SSH init and acceptance testing.
# Only created when CI_MODE=true — never present in production deployments.
# Remote is locked to the pipeline worker's IP (CI_ALLOWED_CIDR) — never 0.0.0.0/0.
resource "ibm_is_security_group_rule" "fgt_public_inbound_ci_ssh" {
  count     = var.CI_MODE ? 1 : 0
  group     = ibm_is_security_group.fgt_sg_public.id
  direction = "inbound"
  remote    = var.CI_ALLOWED_CIDR
  protocol  = "tcp"
  port_min  = 22
  port_max  = 22
}

# ============================================================================
# Security Group - Private
# Attached to: port2 (internal) and port3 (HA heartbeat) on both FortiGates
# Inbound : self-referencing — only traffic from within this SG (inter-FGT)
# Outbound: self-referencing only — no internet access needed on private ports
# ============================================================================

resource "ibm_is_security_group" "fgt_sg_private" {
  name           = "${var.CLUSTER_NAME}-sg-private-${random_string.random_suffix.result}"
  vpc            = data.ibm_is_vpc.vpc1.id
  resource_group = data.ibm_resource_group.rg.id
}

# Inbound — allow traffic only from interfaces in this same SG (inter-FGT).
# Covers all HA protocols: heartbeat (UDP), session sync (TCP 703), etc.
resource "ibm_is_security_group_rule" "fgt_private_inbound_self" {
  group     = ibm_is_security_group.fgt_sg_private.id
  direction = "inbound"
  remote    = ibm_is_security_group.fgt_sg_private.id
  name      = "allow-inbound-from-same-sg"
}

# Outbound — allow traffic only to interfaces in this same SG (inter-FGT)
resource "ibm_is_security_group_rule" "fgt_private_outbound_self" {
  group     = ibm_is_security_group.fgt_sg_private.id
  direction = "outbound"
  remote    = ibm_is_security_group.fgt_sg_private.id
  name      = "allow-outbound-to-same-sg"
}
