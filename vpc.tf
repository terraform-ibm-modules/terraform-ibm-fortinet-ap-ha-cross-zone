data "ibm_is_vpc" "vpc1" {
  name = var.VPC
}
//Subnets for primary (ACTIVE) FortiGate
data "ibm_is_subnet" "subnet1-z1" {
  identifier = var.SUBNET_1_Z1
}
data "ibm_is_subnet" "subnet2-z1" {
  identifier = var.SUBNET_2_Z1
}
data "ibm_is_subnet" "subnet3-z1" {
  identifier = var.SUBNET_3_Z1
}
data "ibm_is_subnet" "subnet4-z1" {
  identifier = var.SUBNET_4_Z1
}

//Subnets for secondary (PASSIVE) FortiGate
data "ibm_is_subnet" "subnet1-z2" {
  identifier = var.SUBNET_1_Z2
}
data "ibm_is_subnet" "subnet2-z2" {
  identifier = var.SUBNET_2_Z2
}
data "ibm_is_subnet" "subnet3-z2" {
  identifier = var.SUBNET_3_Z2
}
data "ibm_is_subnet" "subnet4-z2" {
  identifier = var.SUBNET_4_Z2
}


locals {
  active = {
    "interface1" = { ip = var.FGT1_STATIC_IP_PORT1, subnet = var.SUBNET_1_Z1 },
    "interface2" = { ip = var.FGT1_STATIC_IP_PORT2, subnet = var.SUBNET_2_Z1 },
    "interface3" = { ip = var.FGT1_STATIC_IP_PORT3, subnet = var.SUBNET_3_Z1 },
    "interface4" = { ip = var.FGT1_STATIC_IP_PORT4, subnet = var.SUBNET_4_Z1 },
  }
  passive = {
    "interface1" = { ip = var.FGT2_STATIC_IP_PORT1, subnet = var.SUBNET_1_Z2 },
    "interface2" = { ip = var.FGT2_STATIC_IP_PORT2, subnet = var.SUBNET_2_Z2 },
    "interface3" = { ip = var.FGT2_STATIC_IP_PORT3, subnet = var.SUBNET_3_Z2 },
    "interface4" = { ip = var.FGT2_STATIC_IP_PORT4, subnet = var.SUBNET_4_Z2 },
  }

  # interface1 = port1 (public), interface4 = port4 (HA mgmt) → public SG
  # interface2 = port2 (private), interface3 = port3 (HA heartbeat) → private SG
  sg_map = {
    "interface1" = ibm_is_security_group.fgt_sg_public.id
    "interface2" = ibm_is_security_group.fgt_sg_private.id
    "interface3" = ibm_is_security_group.fgt_sg_private.id
    "interface4" = ibm_is_security_group.fgt_sg_public.id
  }

}

// PAR creation and routes
resource "ibm_is_public_address_range" "public_address_range_instance" {
  ipv4_address_count = var.PAR_ADDRESS_COUNT #Int, can be set larger. This is just the default
  name               = "${var.CLUSTER_NAME}-par-${random_string.random_suffix.result}"

  resource_group {
    id = data.ibm_resource_group.rg.id
  }
  target {
    vpc {
      id = data.ibm_is_vpc.vpc1.id
    }
    zone {
      name = var.ZONE_1
    }
  }
}

resource "ibm_is_virtual_network_interface" "vni-active" {
  for_each                      = local.active
  name                          = "${var.CLUSTER_NAME}-fgt1-${each.key}-${random_string.random_suffix.result}"
  allow_ip_spoofing             = each.key == "interface2" # port2 - trusted data interface
  protocol_state_filtering_mode = each.key == "interface2" ? "disabled" : null
  auto_delete                   = false
  enable_infrastructure_nat     = true
  security_groups               = [local.sg_map[each.key]]
  resource_group                = data.ibm_resource_group.rg.id

  primary_ip {
    auto_delete = false
    address     = each.value.ip
  }
  subnet = each.value.subnet
}

resource "ibm_is_virtual_network_interface" "vni-passive" {
  for_each                      = local.passive
  name                          = "${var.CLUSTER_NAME}-fgt2-${each.key}-${random_string.random_suffix.result}"
  allow_ip_spoofing             = each.key == "interface2" # port2 - trusted data interface
  protocol_state_filtering_mode = each.key == "interface2" ? "disabled" : null
  auto_delete                   = false
  enable_infrastructure_nat     = true
  resource_group                = data.ibm_resource_group.rg.id
  security_groups               = [local.sg_map[each.key]]

  primary_ip {
    auto_delete = false
    address     = each.value.ip
  }
  subnet = each.value.subnet
}

resource "ibm_is_vpc_routing_table" "par_route" {
  name                   = "${var.CLUSTER_NAME}-par-rtb-${random_string.random_suffix.result}"
  vpc                    = data.ibm_is_vpc.vpc1.id
  route_internet_ingress = true
}

resource "ibm_is_vpc_routing_table_route" "par_routing_table" {
  depends_on    = [ibm_is_vpc_routing_table.par_route]
  vpc           = data.ibm_is_vpc.vpc1.id
  routing_table = ibm_is_vpc_routing_table.par_route.routing_table
  zone          = var.ZONE_1
  name          = "par-route-${random_string.random_suffix.result}"
  destination   = ibm_is_public_address_range.public_address_range_instance.cidr
  action        = "deliver"
  advertise     = false
  next_hop      = var.FGT1_STATIC_IP_PORT1
  priority      = 0
}
