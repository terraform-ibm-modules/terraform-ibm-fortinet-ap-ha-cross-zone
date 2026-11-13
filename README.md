# FortiGate Active-Passive HA Deployment on IBM Cloud (Cross Zone)

## Description

A Terraform based script that deploys an Active-Passive (A-P) HA cluster across two availability zones. This script is used by the IBM Cloud Catalog offering `Fortinet FortiGate VM NGFW - A/P HA Cross Zone`. This template makes use of the FortiGate IBM SDN connector and Public Address Range (PAR) to failover in the event of a VM shutdown. After the active VM is back up, it will take over as active once again.

- This terraform will deploy a FortiGate license for the selected pricing plan.
- Users may submit support tickets to IBM Cloud for issues relating to this offering.
- The Virtual FortiGate is customer managed. Details on roles and responsibilities can be found [here](https://cloud.ibm.com/docs/licensed-firewall?topic=licensed-firewall-fortinet-racii-v3)

## Post-Deployment Considerations

### Firmware and Vulnerability Patching

For complete information about security maintenance and vulnerability management, see [Security maintenance and vulnerability management](https://cloud.ibm.com/docs/licensed-firewall?topic=licensed-firewall-security-maintenance-vulnerability-management).

Fortinet is responsible for identifying, investigating, and publishing security vulnerabilities that affect FortiGate products. Fortinet also provides security advisories, remediation guidance, firmware updates, and software fixes for affected products.

Your responsibilities for maintaining and operating your FortiGate deployment are defined in your service agreement and other applicable service documentation. Review your service agreement to understand your obligations regarding software maintenance, security updates, and vulnerability management.

**Monitoring security advisories**

Fortinet publishes security advisories through its Product Security Incident Response Team (PSIRT). Advisories include information about affected product versions, vulnerability severity, available mitigations, and recommended software updates.

IBM recommends that you regularly review Fortinet security advisories and evaluate whether remediation actions are required for your environment.

For more information, see the [Fortinet PSIRT portal](https://www.fortiguard.com/psirt).

**Subscribe to Fortinet notifications**

To receive notifications about security advisories, firmware releases, and other product updates, subscribe to Fortinet notification services.

Fortinet provides RSS feeds for security advisories, firmware releases, threat intelligence updates, and other product announcements. For more information, see [Manage Your Subscriptions to Fortinet](https://support.fortinet.com/).

**Accessing the FortiGate web management console**

Firmware upgrades require access to the FortiGate web management console on port 443. By default, this deployment attaches Floating IPs (FIPs) to both FortiGates with deny-all inbound access for security. You can access the console using one of the following methods:

- **Floating IP with Allowlist**: Modify the security group rules to allowlist your source IP address for HTTPS (port 443) access to the attached FIPs. This enables direct access to the FortiGate web console from the internet.
- **VPN Access (No FIP Required)**: Configure a VPN connection into your VPC to access the FortiGate management interface using its private IP address on port 443. This method does not require a Floating IP and provides secure private network access.

**Network requirements**

For firmware upgrades and license validation to function properly:

- **Egress Internet Access**: An egress route to the internet must be configured to allow the FortiGate to download firmware updates and validate the installed license.
- **Security Group Rules**: Ensure appropriate security group rules are in place to allow HTTPS (port 443) access from your management source IP addresses (when using FIP) or from your VPN subnet (when using VPN access).

**Best practices**

IBM recommends that you:

- Subscribe to Fortinet security notifications.
- Review Fortinet PSIRT advisories regularly.
- Maintain supported FortiOS versions.
- Apply security updates and remediation actions according to your organization's operational and security requirements.
- Include Fortinet security advisories in your vulnerability management processes.
- Ensure secure access to the FortiGate web management console before attempting firmware upgrades.
- Verify egress internet connectivity is available for firmware downloads and license validation.


## Requirements

-   [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html) 1.6+
-   IBM Cloud Terraform Provider version 2.1.0+
-   IBM Cloud Catalog offering CRNs (Version CRN and Plan CRN) for FortiGate
-   [A VPC with eight subnets across two zones](https://cloud.ibm.com/docs/vpc/vpc-getting-started-with-ibm-cloud-virtual-private-cloud-infrastructure)
-   [A configured IBM SSH key](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)
-   IBM Cloud API key with appropriate permissions

## Key Features

- **Cross-Zone High Availability**: Automatic failover between availability zones for maximum resilience
- **Public Address Range (PAR)**: Floating IP addresses for seamless failover
- **Automatic Profile Selection**: VSI profile is automatically selected based on the catalog offering plan CRN
- **Region-Specific Support**: Handles region-specific profile availability (e.g., Chennai region where cx2 profiles are unavailable)
- **Dual Security Groups**: Two distinct security groups are automatically created — `sg-public` (port1 + port4) and `sg-private` (port2 + port3) — each with highly restrictive rules:
  - Inbound: self-referencing rule (inter-FGT traffic only, nothing external)
  - Public SG outbound: restricted to FortiGuard services only (UDP 53, TCP 853, TCP 443, TCP 8890)
  - Private SG outbound: self-referencing only (no internet access on internal/HA ports)
- **Auto-derived Port1 Gateway**: The default route gateway for port1 on each FortiGate is derived automatically from the subnet CIDR — no manual variable required
- **Metadata Service Enabled**: Required for VNF licensing
- **Catalog Offering Support**: Uses IBM Cloud Catalog offerings instead of custom images
- **IBM SDN Connector**: Automatic route updates during failover

## Deployment overview

Terraform deploys the following components:

-   Two FortiGate licensed instances (via IBM Cloud Catalog) with four NICs each, deployed across two availability zones
-   Four floating Public IP addresses: two attached to Port1 (primary management) and two attached to Port4 (HA management) of each FortiGate
-   One Public Address Range (PAR) for floating IP addresses used in failover
-   One log disk per FortiGate
-   A security group with appropriate inbound and outbound rules
-   A basic bootstrap configuration with HA support

## Deployment Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         IBM Cloud VPC                            │
│                                                                   │
│  ┌──────────────────────┐         ┌──────────────────────┐     │
│  │   Zone 1 (Active)    │         │   Zone 2 (Passive)   │     │
│  │                      │         │                      │     │
│  │  ┌────────────────┐  │         │  ┌────────────────┐  │     │
│  │  │  FortiGate 1   │  │         │  │  FortiGate 2   │  │     │
│  │  │                │  │         │  │                │  │     │
│  │  │ Port1 (Public) │◄─┼─────────┼─►│ Port1 (Public) │  │     │
│  │  │ Port2 (Private)│  │         │  │ Port2 (Private)│  │     │
│  │  │ Port3 (HA HB)  │◄─┼─────────┼─►│ Port3 (HA HB)  │  │     │
│  │  │ Port4 (HA Mgmt)│  │         │  │ Port4 (HA Mgmt)│  │     │
│  │  └────────────────┘  │         │  └────────────────┘  │     │
│  │         │             │         │         │             │     │
│  │    [Log Disk]        │         │    [Log Disk]        │     │
│  └──────────────────────┘         └──────────────────────┘     │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         Public Address Range (PAR)                       │   │
│  │         Floating IPs for failover                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         IBM SDN Connector                                │   │
│  │         Automatic route updates on failover              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration

### IBM Cloud Authentication
```hcl
IBMCLOUD_API_KEY    = "<your-ibmcloud-api-key>"
SSH_PUBLIC_KEY_NAME = "<your-ssh-key-name>"
```

### Region and Zones
```hcl
REGION = "us-south"      # IBM Cloud region
ZONE_1 = "us-south-1"    # First availability zone
ZONE_2 = "us-south-2"    # Second availability zone
```

### VPC and Network Configuration

**Zone 1 Subnets:**
```hcl
VPC         = "your-vpc-name"
SUBNET_1_Z1 = "subnet-uuid-for-port1"  # Primary/Public subnet
SUBNET_2_Z1 = "subnet-uuid-for-port2"  # Secondary/Private subnet
SUBNET_3_Z1 = "subnet-uuid-for-port3"  # HA Heartbeat subnet
SUBNET_4_Z1 = "subnet-uuid-for-port4"  # HA Management subnet
```

**Zone 2 Subnets:**
```hcl
SUBNET_1_Z2 = "subnet-uuid-for-port1"  # Primary/Public subnet
SUBNET_2_Z2 = "subnet-uuid-for-port2"  # Secondary/Private subnet
SUBNET_3_Z2 = "subnet-uuid-for-port3"  # HA Heartbeat subnet
SUBNET_4_Z2 = "subnet-uuid-for-port4"  # HA Management subnet
```

> **Note:** For Subnets, the UUID is required, not the name.

### Static IP Configuration

All four ports on each FortiGate use **static IPs** — not DHCP. Each IP must fall within its corresponding subnet CIDR.

**FortiGate 1 (Zone 1 — Active):**
```hcl
FGT1_STATIC_IP_PORT1    = "10.240.0.4"    # port1 — public/external
FGT1_STATIC_IP_PORT2    = "10.240.1.4"    # port2 — private/internal
FGT1_STATIC_IP_PORT3    = "10.240.2.4"    # port3 — HA heartbeat
FGT1_STATIC_IP_PORT4    = "10.240.3.4"    # port4 — HA management
FGT1_PORT4_MGMT_GATEWAY = "10.240.3.1"    # gateway for port4 management route
```

**FortiGate 2 (Zone 2 — Passive):**
```hcl
FGT2_STATIC_IP_PORT1    = "10.240.10.4"   # port1 — public/external
FGT2_STATIC_IP_PORT2    = "10.240.11.4"   # port2 — private/internal
FGT2_STATIC_IP_PORT3    = "10.240.12.4"   # port3 — HA heartbeat
FGT2_STATIC_IP_PORT4    = "10.240.13.4"   # port4 — HA management
FGT2_PORT4_MGMT_GATEWAY = "10.240.13.1"   # gateway for port4 management route
```

> **Port1 default route gateway (auto-derived)**: The default route for port1 on each FortiGate is computed automatically using `cidrhost(<subnet_cidr>, 1)`. IBM VPC always reserves the first host address of a subnet (e.g. `10.240.0.1`) as the gateway — no additional variable is needed for this.

### Public Address Range Configuration
```hcl
PAR_ADDRESS_COUNT = "8"  # Number of IP addresses in the PAR
```

### Resource Configuration
```hcl
CLUSTER_NAME = "fortigate-ha-cluster"  # Must be lowercase
RESOURCE_GRP = "Default"
NETMASK      = "255.255.255.0"
```

### Automatic Profile Selection

The VSI profile is automatically selected based on the `CATALOG_OFFERING_PLAN_CRN`. The mapping includes:

**Enterprise Plans:**
- 8vCPU Medium → cx3d-8x20
- 16vCPU Large → cx3d-16x40
- 32vCPU X-large → cx3d-32x80

**UTP Plans:**
- 2vCPU Small → cx3d-2x5
- 8vCPU Medium → cx3d-8x20
- 16vCPU Large → cx3d-16x40

**ATP Plans:**
- 2vCPU Small → cx2-2x4
- 8vCPU Medium → cx2-8x16

Region-specific overrides are automatically applied where certain profiles are unavailable (e.g., Chennai region).

## Outputs

The deployment provides the following outputs:

- `FGT1_Port1_Public_IP`: Floating IP attached to FortiGate 1 port1 (public/external)
- `FGT1_Port4_Public_IP`: Floating IP attached to FortiGate 1 port4 (HA management)
- `FGT2_Port1_Public_IP`: Floating IP attached to FortiGate 2 port1 (public/external)
- `FGT2_Port4_Public_IP`: Floating IP attached to FortiGate 2 port4 (HA management)
- `Par_ID`: Public Address Range ID
- `Par_Name`: Public Address Range name
- `Par_CIDR`: Public Address Range CIDR block
- `Public_Security_Group_ID`: ID of the public security group (port1 + port4)
- `Public_Security_Group_Name`: Name of the public security group
- `Private_Security_Group_ID`: ID of the private security group (port2 + port3)
- `Private_Security_Group_Name`: Name of the private security group
- `Selected_Profile`: VSI profile selected based on plan CRN and region
- `Catalog_Offering_Version_CRN`: Catalog offering version CRN used
- `Catalog_Offering_Plan_CRN`: Catalog offering plan CRN used
- `Username`: Default admin username (`admin`)
- `FGT1_Default_Admin_Password`: FGT1 instance ID (used as initial login password)
- `FGT2_Default_Admin_Password`: FGT2 instance ID (used as initial login password)

## Security Group Configuration

Two distinct security groups are automatically created, separating public-facing and private interfaces for defence in depth.

### `sg-public` — port1 (external) + port4 (HA management)

| Rule | Direction | Remote | Protocol | Port | Purpose |
|------|-----------|--------|----------|------|---------|
| `allow-inbound-from-same-sg` | Inbound | This SG | All | All | Inter-FGT traffic only — nothing external permitted |
| `allow-outbound-fortiguard-dns-udp-53` | Outbound | `0.0.0.0/0` | UDP | 53 | FortiGuard DNS & SDNS queries |
| `allow-outbound-dns-over-tls-tcp-853` | Outbound | `0.0.0.0/0` | TCP | 853 | DNS over TLS (DoT) |
| `allow-outbound-fortiguard-licensing-tcp-443` | Outbound | `0.0.0.0/0` | TCP | 443 | Licensing, FortiCare & entitlements |
| `allow-outbound-fortiguard-updates-tcp-8890` | Outbound | `0.0.0.0/0` | TCP | 8890 | FortiGuard distribution updates |
| `allow-outbound-ntp-udp-123` | Outbound | `0.0.0.0/0` | UDP | 123 | NTP time synchronization |

### `sg-private` — port2 (internal) + port3 (HA heartbeat)

| Rule | Direction | Remote | Protocol | Port | Purpose |
|------|-----------|--------|----------|------|---------|
| `allow-inbound-from-same-sg` | Inbound | This SG | All | All | Inter-FGT traffic only (HA sync, heartbeat) |
| `allow-outbound-to-same-sg` | Outbound | This SG | All | All | Inter-FGT traffic only — no internet access |

### Security Benefits
- **Interface Segregation**: Public and private ports operate under separate security boundaries
- **Minimal Attack Surface**: Self-referencing inbound rules allow only traffic from the two FortiGate instances — nothing external
- **No Broad CIDRs**: No wide subnet ranges; membership in the SG controls access automatically
- **Restricted Outbound**: Public SG outbound is scoped to FortiGuard service ports only (UDP 53, TCP 853, TCP 443, TCP 8890)
- **Air-gapped Private Ports**: Private SG has zero internet access — HA heartbeat and internal traffic stay fully isolated
- **Named Rules**: All rules have descriptive names for easy identification in the IBM Cloud console

### Customization
You can modify these rules in `security_group_ha.tf` as needed. The current configuration provides maximum security while maintaining full HA and FortiGuard licensing functionality.

**Important**: The FortiGate instances handle all traffic forwarding and security policies internally. The security groups only control access to the FortiGate management interfaces and HA communication.

## HA Configuration

The deployment configures Active-Passive HA with:
- **Port 3**: HA heartbeat and synchronization
- **Port 4**: HA management
- **SDN Connector**: For dynamic route updates during failover
- **Public Address Range (PAR)**: For floating IP addresses
- **Automatic Failover**: When the active instance fails, the passive takes over
- **Automatic Failback**: When the original active instance recovers, it resumes the active role
- **Cross-Zone Redundancy**: Instances deployed in separate availability zones for maximum resilience

## Troubleshooting

### Common Issues

1. **Viewing Terraform Execution Logs**
   - The Firewall VSI installation creates a Schematics workspace that displays terraform execution logs
   - This workspace is automatically launched when the VSI is created
   - To access the workspace manually: Navigate to **IBM Cloud Menu** > **Platform Automation** > **Schematics** > **Terraform** > Select your workspace
   - The workspace logs provide detailed information about the deployment process and can help troubleshoot any issues

2. **Profile Not Available in Region**
   - The system automatically handles region-specific profile availability
   - Check the logs to see which profile was selected

3. **Timeout Errors**
   - The deployment includes extended timeouts (60 minutes) for instance creation
   - If issues persist, check IBM Cloud status

4. **Password Empty on First Boot**
   - This is normal behavior for catalog offerings
   - The password will be set after the first boot completes
   - Use the instance ID as the initial password

5. **HA Synchronization Fails**
   - Verify the security group allows traffic between FortiGate Port3 interfaces
   - Check that both FortiGates can reach each other on the HA heartbeat subnet
   - Use `get system ha status` command to verify HA status

6. **License Validation Fails**
   - Verify Floating IPs are properly attached to Port1 and Port4 interfaces
   - Check security group allows outbound HTTPS (TCP 443) traffic
   - Ensure egress internet connectivity is available

## Support

- Users may submit support tickets to IBM Cloud for issues relating to this offering.
- The Virtual FortiGate is customer managed. Details on roles and responsibilities can be found [here](https://cloud.ibm.com/docs/licensed-firewall?topic=licensed-firewall-fortinet-racii-v3)

## Additional Resources

- [IBM Cloud VPC Documentation](https://cloud.ibm.com/docs/vpc)
- [FortiGate IBM Cloud Administration Guide](https://docs.fortinet.com/document/fortigate-public-cloud/latest/ibm-cloud-administration-guide)
- [Terraform IBM Provider Documentation](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs)
- [FortiGate HA Documentation](https://docs.fortinet.com/document/fortigate/latest/administration-guide/186277/high-availability)
