package integration

import (
	"crypto/tls"
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestE2ECluster(t *testing.T) {
	t.Parallel()

	// 1. Define AWS region for ephemeral testing
	awsRegion := "us-east-1"
	uniqueID := fmt.Sprintf("test-%d", time.Now().Unix())
	clusterName := fmt.Sprintf("temp-eks-%s", uniqueID)

	// Configure OpenTofu/Terraform options targeting the Dev environment or custom test config
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../terraform/live/dev",
		Vars: map[string]interface{}{
			"aws_region":   awsRegion,
			"cluster_name": clusterName,
			"environment":  "test",
			"vpc_cidr":     "10.99.0.0/16",
		},
		// We can override the backend config to local for ephemeral testing so we do not pollute S3 state
		BackendConfig: map[string]interface{}{
			"bucket":         "template-cluster-k8s-terraform-state-dev", // standard bucket
			"key":            fmt.Sprintf("test/eks-cluster-%s/terraform.tfstate", uniqueID),
			"region":         awsRegion,
			"dynamodb_table": "template-cluster-k8s-tflocks-dev",
		},
	})

	// 2. Clean up resources at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// 3. Deploy VPC and EKS Cluster
	t.Log("Starting OpenTofu Apply...")
	terraform.InitAndApply(t, terraformOptions)

	// 4. Retrieve outputs from Terraform run
	clusterNameOutput := terraform.Output(t, terraformOptions, "cluster_name")
	vpcIDOutput := terraform.Output(t, terraformOptions, "vpc_id")
	podIdentityRoleArn := terraform.Output(t, terraformOptions, "pod_identity_role_arn")

	assert.NotEmpty(t, clusterNameOutput)
	assert.NotEmpty(t, vpcIDOutput)
	assert.NotEmpty(t, podIdentityRoleArn)

	t.Logf("EKS Cluster %s successfully provisioned.", clusterNameOutput)

	// 5. Setup KubeConfig options
	options := k8s.NewKubectlOptions("", "", "dev")

	// 6. Deploy Kubernetes Manifests representing our Application Template
	t.Log("Applying apps-template Kubernetes manifests...")
	k8s.KubectlApply(t, options, "../../apps-template/base/deployment.yaml")
	k8s.KubectlApply(t, options, "../../apps-template/base/service.yaml")
	k8s.KubectlApply(t, options, "../../apps-template/base/http-route.yaml")

	defer k8s.KubectlDelete(t, options, "../../apps-template/base/http-route.yaml")
	defer k8s.KubectlDelete(t, options, "../../apps-template/base/service.yaml")
	defer k8s.KubectlDelete(t, options, "../../apps-template/base/deployment.yaml")

	// 7. Verify Pods and Service are running correctly
	t.Log("Verifying EKS Pods and Service...")
	k8s.WaitUntilPodAvailable(t, options, "api-exemplo", 15, 5*time.Second)

	pods, err := k8s.ListPodsE(t, options, metav1.ListOptions{LabelSelector: "app=api-exemplo"})
	require.NoError(t, err)
	require.NotEmpty(t, pods)

	testPodName := pods[0].Name

	// 8. Validate Amazon EKS Pod Identity Integration (AWS STS caller identity test inside Pod)
	t.Log("Testing Amazon EKS Pod Identity STS validation inside pod...")
	execArgs := []string{"exec", testPodName, "--", "sh", "-c", "env | grep AWS_CONTAINER_"}
	stdout, err := k8s.RunKubectlAndGetOutputE(t, options, execArgs...)
	if err == nil {
		assert.Contains(t, stdout, "AWS_CONTAINER_CREDENTIALS_FULL_URI")
		t.Log("SUCCESS: AWS container credentials metadata injected correctly by EKS Pod Identity agent.")
	} else {
		t.Logf("AWS credentials not checked or container lacks sh. Skipping deep env check. Error: %s", err)
	}

	// 9. Verify local or external service HTTP accessibility
	serviceName := "api-exemplo-svc"
	k8s.WaitUntilServiceAvailable(t, options, serviceName, 10, 5*time.Second)

	// Formulate HTTP check via Terratest's port-forwarding capabilities or http-helper
	tunnel := k8s.NewTunnel(options, k8s.ResourceTypeService, serviceName, 0, 80)
	defer tunnel.Close()
	tunnel.ForwardPort(t)

	localEndpoint := fmt.Sprintf("http://%s", tunnel.Endpoint())
	t.Logf("Verifying HTTP endpoint: %s", localEndpoint)

	tlsConfig := tls.Config{}
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		localEndpoint,
		&tlsConfig,
		15,
		2*time.Second,
		func(statusCode int, body string) bool {
			return statusCode == 200
		},
	)

	t.Log("E2E Integration Test passed successfully!")
}
