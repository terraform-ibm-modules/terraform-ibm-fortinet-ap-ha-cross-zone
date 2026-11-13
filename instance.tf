# CRN to profile mapping is now centralized in locals.tf
# This provides region-specific profile overrides and validation

data "ibm_is_ssh_key" "ssh_key" {
  name = var.SSH_PUBLIC_KEY_NAME
}

// HA Password
resource "random_string" "ha_password" {
  length  = 8
  special = false
}

// Log disk volumes are only provisioned for profiles lacking local instance storage (e.g. cx2).
// cx3d profiles already include built-in local NVMe instance storage (/dev/vdb) used for disk logging;
// attaching an extra block volume creates a redundant disk that FortiOS may format for WANOpt, causing HA sync issues.
resource "ibm_is_volume" "logDisk1" {
  count = startswith(local.selected_profile, "cx3d") ? 0 : 1
  // Name must be lower case
  name    = "${var.CLUSTER_NAME}-logdisk1-${random_string.random_suffix.result}"
  profile = "10iops-tier"
  zone    = var.ZONE_1
}

resource "ibm_is_volume" "logDisk2" {
  count = startswith(local.selected_profile, "cx3d") ? 0 : 1
  // Name must be lower case
  name    = "${var.CLUSTER_NAME}-logdisk2-${random_string.random_suffix.result}"
  profile = "10iops-tier"
  zone    = var.ZONE_2
}

// Floating IP for Active FGT1 Port1
resource "ibm_is_floating_ip" "publicip" {
  name = "${var.CLUSTER_NAME}-fgt1-port1-${random_string.random_suffix.result}"
  zone = var.ZONE_1
}

// Floating IP for Active FGT1 Port4 (HA Management)
resource "ibm_is_floating_ip" "publicip2" {
  name = "${var.CLUSTER_NAME}-fgt1-port4-${random_string.random_suffix.result}"
  zone = var.ZONE_1
}

// Floating IP for Passive FGT2 Port1
resource "ibm_is_floating_ip" "publicip3" {
  name = "${var.CLUSTER_NAME}-fgt2-port1-${random_string.random_suffix.result}"
  zone = var.ZONE_2
}

// Floating IP for Passive FGT2 Port4 (HA Management)
resource "ibm_is_floating_ip" "publicip4" {
  name = "${var.CLUSTER_NAME}-fgt2-port4-${random_string.random_suffix.result}"
  zone = var.ZONE_2
}

// Attach Floating IP to Active FGT1 Port1
resource "ibm_is_virtual_network_interface_floating_ip" "public_ip" {
  virtual_network_interface = ibm_is_virtual_network_interface.vni-active["interface1"].id
  floating_ip               = ibm_is_floating_ip.publicip.id
}

// Attach Floating IP to Active FGT1 Port4
resource "ibm_is_virtual_network_interface_floating_ip" "public_ip2" {
  virtual_network_interface = ibm_is_virtual_network_interface.vni-active["interface4"].id
  floating_ip               = ibm_is_floating_ip.publicip2.id
}

// Attach Floating IP to Passive FGT2 Port1
resource "ibm_is_virtual_network_interface_floating_ip" "public_ip3" {
  virtual_network_interface = ibm_is_virtual_network_interface.vni-passive["interface1"].id
  floating_ip               = ibm_is_floating_ip.publicip3.id
}

// Attach Floating IP to Passive FGT2 Port4
resource "ibm_is_virtual_network_interface_floating_ip" "public_ip4" {
  virtual_network_interface = ibm_is_virtual_network_interface.vni-passive["interface4"].id
  floating_ip               = ibm_is_floating_ip.publicip4.id
}

//Primary Fortigate
resource "ibm_is_instance" "fgt1" {
  name           = "${var.CLUSTER_NAME}-fortigate1-${random_string.random_suffix.result}"
  profile        = local.selected_profile
  resource_group = data.ibm_resource_group.rg.id

  # Use catalog offering instead of custom image
  catalog_offering {
    version_crn = var.CATALOG_OFFERING_VERSION_CRN
    plan_crn    = var.CATALOG_OFFERING_PLAN_CRN
  }

  # Enable metadata service with secure access
  metadata_service {
    enabled            = true
    protocol           = "https"
    response_hop_limit = 5
  }
  primary_network_attachment {
    name = "${var.CLUSTER_NAME}-port1-fgt1-att-${random_string.random_suffix.result}"
    virtual_network_interface {
      id = ibm_is_virtual_network_interface.vni-active["interface1"].id


    }
  }
  network_attachments {
    name = "${var.CLUSTER_NAME}-port2-fgt1-att-${random_string.random_suffix.result}"
    virtual_network_interface {
      id = ibm_is_virtual_network_interface.vni-active["interface2"].id

    }
  }

  network_attachments {
    name = "${var.CLUSTER_NAME}-port3-fgt1-${random_string.random_suffix.result}"
    virtual_network_interface {
      id = ibm_is_virtual_network_interface.vni-active["interface3"].id


    }
  }

  network_attachments {
    name = "${var.CLUSTER_NAME}-port4-fgt1-${random_string.random_suffix.result}"
    virtual_network_interface {
      id = ibm_is_virtual_network_interface.vni-active["interface4"].id


    }
  }

  // Only attach log volume for profiles without instance storage (cx2); cx3d uses built-in NVMe
  volumes            = startswith(local.selected_profile, "cx3d") ? [] : [ibm_is_volume.logDisk1[0].id]
  auto_delete_volume = true

  # Allocate 1 Gbps (1000 Mbps) to volumes, rest goes to networking
  total_volume_bandwidth = 1000

  vpc       = data.ibm_is_vpc.vpc1.id
  zone      = var.ZONE_1
  user_data = local.userdata_active
  keys      = [data.ibm_is_ssh_key.ssh_key.id]
  // Timeout issues persist. See https://www.ibm.com/cloud/blog/timeout-errors-with-ibm-cloud-schematics
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
  // Force IBM to recover from perpetual 'starting state' see:
  // https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_instance#force_recovery_time
  force_recovery_time = 20
}

// Secondary FortiGate
resource "ibm_is_instance" "fgt2" {
  name           = "${var.CLUSTER_NAME}-fortigate2-${random_string.random_suffix.result}"
  profile        = local.selected_profile
  resource_group = data.ibm_resource_group.rg.id

  # Use catalog offering instead of custom image
  catalog_offering {
    version_crn = var.CATALOG_OFFERING_VERSION_CRN
    plan_crn    = var.CATALOG_OFFERING_PLAN_CRN
  }

  # Enable metadata service with secure access
  metadata_service {
    enabled            = true
    protocol           = "https"
    response_hop_limit = 5
  }

  primary_network_attachment {
    name = "${var.CLUSTER_NAME}-port1-fgt2-${random_string.random_suffix.result}"
    virtual_network_interface {
      id = ibm_is_virtual_network_interface.vni-passive["interface1"].id
    }
  }
  network_attachments {
    name = "${var.CLUSTER_NAME}-port2-fgt2-${random_string.random_suffix.result}"
    virtual_network_interface {
      id = ibm_is_virtual_network_interface.vni-passive["interface2"].id
    }
  }

  network_attachments {
    name = "${var.CLUSTER_NAME}-port3-fgt2-${random_string.random_suffix.result}"
    virtual_network_interface {
      id = ibm_is_virtual_network_interface.vni-passive["interface3"].id
    }
  }

  network_attachments {
    name = "${var.CLUSTER_NAME}-port4-fgt2-${random_string.random_suffix.result}"
    virtual_network_interface {
      id = ibm_is_virtual_network_interface.vni-passive["interface4"].id
    }
  }
  // Only attach log volume for profiles without instance storage (cx2); cx3d uses built-in NVMe
  volumes            = startswith(local.selected_profile, "cx3d") ? [] : [ibm_is_volume.logDisk2[0].id]
  auto_delete_volume = true

  # Allocate 1 Gbps (1000 Mbps) to volumes, rest goes to networking
  total_volume_bandwidth = 1000

  vpc       = data.ibm_is_vpc.vpc1.id
  zone      = var.ZONE_2
  user_data = local.userdata_passive
  keys      = [data.ibm_is_ssh_key.ssh_key.id]
  //Timeout issues persist. See https://www.ibm.com/cloud/blog/timeout-errors-with-ibm-cloud-schematics
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
  // Force IBM to recover from perpetual 'starting state' see:
  // https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_instance#force_recovery_time
  force_recovery_time = 20
}

// Bootstrap cloud-init config templates for active and passive FortiGates.
locals {
  userdata_active = templatefile("user_data_active.conf", {
    fgt_1_static_port1 = var.FGT1_STATIC_IP_PORT1
    fgt_1_static_port2 = var.FGT1_STATIC_IP_PORT2
    fgt_1_static_port3 = var.FGT1_STATIC_IP_PORT3
    fgt_1_static_port4 = var.FGT1_STATIC_IP_PORT4

    fgt_2_static_port1 = var.FGT2_STATIC_IP_PORT1
    fgt_2_static_port2 = var.FGT2_STATIC_IP_PORT2
    fgt_2_static_port3 = var.FGT2_STATIC_IP_PORT3
    fgt_2_static_port4 = var.FGT2_STATIC_IP_PORT4

    netmask                  = var.NETMASK
    ibm_api_key              = var.IBMCLOUD_API_KEY
    region                   = var.REGION
    fgt1_port_4_mgmt_gateway = var.FGT1_PORT4_MGMT_GATEWAY
    ha_password              = random_string.ha_password.result
    par_id                   = ibm_is_public_address_range.public_address_range_instance.id
    port1_active_gateway     = local.port1_active_gateway
  })

  // Passive Config Template.
  userdata_passive = templatefile("user_data_passive.conf", {
    fgt_1_static_port1 = var.FGT1_STATIC_IP_PORT1
    fgt_1_static_port2 = var.FGT1_STATIC_IP_PORT2
    fgt_1_static_port3 = var.FGT1_STATIC_IP_PORT3
    fgt_1_static_port4 = var.FGT1_STATIC_IP_PORT4

    fgt_2_static_port1 = var.FGT2_STATIC_IP_PORT1
    fgt_2_static_port2 = var.FGT2_STATIC_IP_PORT2
    fgt_2_static_port3 = var.FGT2_STATIC_IP_PORT3
    fgt_2_static_port4 = var.FGT2_STATIC_IP_PORT4

    netmask                  = var.NETMASK
    ibm_api_key              = var.IBMCLOUD_API_KEY
    region                   = var.REGION
    fgt2_port_4_mgmt_gateway = var.FGT2_PORT4_MGMT_GATEWAY
    ha_password              = random_string.ha_password.result
    par_id                   = ibm_is_public_address_range.public_address_range_instance.id
    port1_passive_gateway    = local.port1_passive_gateway
  })
}
