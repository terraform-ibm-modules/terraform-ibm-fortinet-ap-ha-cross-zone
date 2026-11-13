#!/usr/bin/env bash
# CI environment loader for FortiGate A/P HA Cross Zone
# Source this file — do NOT execute it directly.
# Sets all TF_VAR_* exports and IC_API_KEY needed by ci-deploy.sh and ci-destroy.sh.
#
# Required pipeline properties:
#   TF_CI_CONFIG_CROSS_ZONE   — JSON blob with all non-secret deployment config (get_env)
#   TF_VAR_IBMCLOUD_API_KEY   — secure property (get_secret)

TF_CI_CONFIG_CROSS_ZONE="$(get_env TF_CI_CONFIG_CROSS_ZONE "")"
if [[ -z "$TF_CI_CONFIG_CROSS_ZONE" ]]; then
  echo "✗ Missing required pipeline property: TF_CI_CONFIG_CROSS_ZONE (JSON blob with all deployment config)"
  exit 1
fi

_jq() { echo "$TF_CI_CONFIG_CROSS_ZONE" | jq -r ".$1 // empty"; }
export TF_VAR_REGION="${TF_VAR_REGION:-$(_jq REGION)}"
export TF_VAR_ZONE_1="${TF_VAR_ZONE_1:-$(_jq ZONE_1)}"
export TF_VAR_ZONE_2="${TF_VAR_ZONE_2:-$(_jq ZONE_2)}"
export TF_VAR_VPC="${TF_VAR_VPC:-$(_jq VPC)}"
export TF_VAR_SUBNET_1_Z1="${TF_VAR_SUBNET_1_Z1:-$(_jq SUBNET_1_Z1)}"
export TF_VAR_SUBNET_2_Z1="${TF_VAR_SUBNET_2_Z1:-$(_jq SUBNET_2_Z1)}"
export TF_VAR_SUBNET_3_Z1="${TF_VAR_SUBNET_3_Z1:-$(_jq SUBNET_3_Z1)}"
export TF_VAR_SUBNET_4_Z1="${TF_VAR_SUBNET_4_Z1:-$(_jq SUBNET_4_Z1)}"
export TF_VAR_SUBNET_1_Z2="${TF_VAR_SUBNET_1_Z2:-$(_jq SUBNET_1_Z2)}"
export TF_VAR_SUBNET_2_Z2="${TF_VAR_SUBNET_2_Z2:-$(_jq SUBNET_2_Z2)}"
export TF_VAR_SUBNET_3_Z2="${TF_VAR_SUBNET_3_Z2:-$(_jq SUBNET_3_Z2)}"
export TF_VAR_SUBNET_4_Z2="${TF_VAR_SUBNET_4_Z2:-$(_jq SUBNET_4_Z2)}"
export TF_VAR_NETMASK="${TF_VAR_NETMASK:-$(_jq NETMASK)}"
export TF_VAR_FGT1_STATIC_IP_PORT1="${TF_VAR_FGT1_STATIC_IP_PORT1:-$(_jq FGT1_STATIC_IP_PORT1)}"
export TF_VAR_FGT1_STATIC_IP_PORT2="${TF_VAR_FGT1_STATIC_IP_PORT2:-$(_jq FGT1_STATIC_IP_PORT2)}"
export TF_VAR_FGT1_STATIC_IP_PORT3="${TF_VAR_FGT1_STATIC_IP_PORT3:-$(_jq FGT1_STATIC_IP_PORT3)}"
export TF_VAR_FGT1_STATIC_IP_PORT4="${TF_VAR_FGT1_STATIC_IP_PORT4:-$(_jq FGT1_STATIC_IP_PORT4)}"
export TF_VAR_FGT1_PORT4_MGMT_GATEWAY="${TF_VAR_FGT1_PORT4_MGMT_GATEWAY:-$(_jq FGT1_PORT4_MGMT_GATEWAY)}"
export TF_VAR_FGT2_STATIC_IP_PORT1="${TF_VAR_FGT2_STATIC_IP_PORT1:-$(_jq FGT2_STATIC_IP_PORT1)}"
export TF_VAR_FGT2_STATIC_IP_PORT2="${TF_VAR_FGT2_STATIC_IP_PORT2:-$(_jq FGT2_STATIC_IP_PORT2)}"
export TF_VAR_FGT2_STATIC_IP_PORT3="${TF_VAR_FGT2_STATIC_IP_PORT3:-$(_jq FGT2_STATIC_IP_PORT3)}"
export TF_VAR_FGT2_STATIC_IP_PORT4="${TF_VAR_FGT2_STATIC_IP_PORT4:-$(_jq FGT2_STATIC_IP_PORT4)}"
export TF_VAR_FGT2_PORT4_MGMT_GATEWAY="${TF_VAR_FGT2_PORT4_MGMT_GATEWAY:-$(_jq FGT2_PORT4_MGMT_GATEWAY)}"
export TF_VAR_PAR_ADDRESS_COUNT="${TF_VAR_PAR_ADDRESS_COUNT:-$(_jq PAR_ADDRESS_COUNT)}"
export TF_VAR_SSH_PUBLIC_KEY_NAME="${TF_VAR_SSH_PUBLIC_KEY_NAME:-$(_jq SSH_PUBLIC_KEY_NAME)}"
export TF_VAR_RESOURCE_GRP="${TF_VAR_RESOURCE_GRP:-$(_jq RESOURCE_GRP)}"
export TF_VAR_CLUSTER_NAME="${TF_VAR_CLUSTER_NAME:-$(_jq CLUSTER_NAME)}"
export TF_VAR_CATALOG_OFFERING_VERSION_CRN="${TF_VAR_CATALOG_OFFERING_VERSION_CRN:-$(_jq CATALOG_OFFERING_VERSION_CRN)}"
export TF_VAR_CATALOG_OFFERING_PLAN_CRN="${TF_VAR_CATALOG_OFFERING_PLAN_CRN:-$(_jq CATALOG_OFFERING_PLAN_CRN)}"

# Secure property — must use get_secret, not get_env
export TF_VAR_IBMCLOUD_API_KEY="${TF_VAR_IBMCLOUD_API_KEY:-$(get_secret TF_VAR_IBMCLOUD_API_KEY "")}"

# Override IC_API_KEY so the IBM Terraform provider uses the deployment key,
# not the OnePipeline service ID key injected into the container.
export IC_API_KEY="$TF_VAR_IBMCLOUD_API_KEY"
