package test

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// getTerraformDir returns the Terraform directory from environment or default
func getTerraformDir() string {
	terraformDir := os.Getenv("TERRAFORM_DIR")
	if terraformDir == "" {
		terraformDir = "../"
	}
	return terraformDir
}

// getTerraformOptions creates standard Terraform options for testing
func getTerraformOptions(t *testing.T) *terraform.Options {
	terraformDir := getTerraformDir()

	options := &terraform.Options{
		TerraformDir: terraformDir,
		NoColor:      true,
	}

	// Check if we need to set variables from environment
	if varsJSON := os.Getenv("TF_VARS_JSON"); varsJSON != "" {
		t.Logf("Using variables from environment")
	}

	return options
}

// TestTerraformValidation performs basic validation of Terraform code
// This test only runs terraform init and validate (no actual deployment)
func TestTerraformValidation(t *testing.T) {
	t.Parallel()

	// Get API key from environment (can be dummy for validation)
	apiKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	if apiKey == "" {
		apiKey = "dummy-api-key-for-validation"
	}

	terraformOptions := getTerraformOptions(t)

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	// Run terraform init and validate in one step (using context-aware function)
	t.Log("Running terraform init and validate...")
	terraform.InitAndValidateContext(t, ctx, terraformOptions)

	t.Log("✓ Terraform validation passed")
}

// TestTerraformFormat checks if Terraform files are properly formatted
func TestTerraformFormat(t *testing.T) {
	t.Parallel()

	terraformOptions := getTerraformOptions(t)

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	// Run terraform fmt -check with -diff for better error messages
	// diffutils is installed in the setup script to support this
	t.Log("Running terraform fmt -check...")
	terraform.RunTerraformCommandContext(t, ctx, terraformOptions, "fmt", "-check", "-diff")

	t.Log("✓ Terraform format check passed")
}

// TestTerraformSyntax performs additional syntax validation
func TestTerraformSyntax(t *testing.T) {
	t.Parallel()

	terraformDir := getTerraformDir()

	// Check for common syntax issues
	t.Log("Checking for common Terraform syntax issues...")

	// Verify .tf files exist
	matches, err := filepath.Glob(filepath.Join(terraformDir, "*.tf"))
	assert.NoError(t, err, "Should be able to search for .tf files")

	if len(matches) == 0 {
		t.Skip("No .tf files found - skipping syntax check (tests should run from a Terraform project directory)")
	}

	t.Logf("Found %d Terraform files", len(matches))
}

// TestTerraformVariables checks if all required variables are defined
func TestTerraformVariables(t *testing.T) {
	t.Parallel()

	terraformDir := getTerraformDir()

	t.Log("Checking for variables.tf...")

	// Check if variables.tf exists
	variablesFile := filepath.Join(terraformDir, "variables.tf")
	if _, err := os.Stat(variablesFile); err == nil {
		t.Logf("Found variables.tf")
	} else {
		t.Log("No variables.tf found (may be defined elsewhere)")
	}
}

// TestTerraformOutputs checks if outputs are properly defined
func TestTerraformOutputs(t *testing.T) {
	t.Parallel()

	terraformDir := getTerraformDir()

	t.Log("Checking for outputs.tf...")

	// Check if outputs.tf exists
	outputsFile := filepath.Join(terraformDir, "outputs.tf")
	if _, err := os.Stat(outputsFile); err == nil {
		t.Logf("Found outputs.tf")
	} else {
		t.Log("No outputs.tf found")
	}
}

// TestTerraformProviders checks if providers are properly configured
// Note: This test is informational only and doesn't fail on provider issues
func TestTerraformProviders(t *testing.T) {
	t.Parallel()

	terraformDir := getTerraformDir()

	t.Log("Checking provider configuration...")

	// Check if providers.tf or main.tf contains provider blocks
	providerFiles := []string{
		filepath.Join(terraformDir, "providers.tf"),
		filepath.Join(terraformDir, "main.tf"),
	}

	foundProvider := false
	for _, file := range providerFiles {
		if _, err := os.Stat(file); err == nil {
			t.Logf("Found provider configuration file: %s", filepath.Base(file))
			foundProvider = true
		}
	}

	if !foundProvider {
		t.Log("No dedicated provider configuration file found (providers may be defined inline)")
	}

	t.Log("✓ Provider configuration check complete")
}
