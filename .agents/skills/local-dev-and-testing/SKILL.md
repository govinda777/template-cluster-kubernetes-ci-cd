---
name: local-dev-and-testing
description: >-
  Rules and procedures for local development, code review standards, running unit tests
  in pre-commit hooks, and executing BDD/integration tests in pre-push hooks using a local
  Kind Kubernetes environment that conforms to ADR 0006.
---

# Local Development, Code Review, and Testing Skill

This skill defines the development guidelines, code review standards, and automated testing workflows (unit tests on pre-commit, BDD/integration tests on pre-push) using a local Kind Kubernetes cluster to emulate production multi-cloud behavior.

## Core Workflows

### 1. Pre-commit Checklist (Unit Tests & Static Code Analysis)
Before committing code, you must execute static checks and unit validation:
- Format check for Terraform/OpenTofu files: `tofu fmt -check -recursive terraform/`
- YAML validation: `yamllint` on YAML manifests.
- OPA Policy compliance check: `conftest` against policies in `tests/policies/`.
- Run: [run-unit-tests.sh](./scripts/run-unit-tests.sh)

### 2. Local Environment Management (ADR 0006)
To build a local development cluster as close to real production environments as possible:
- **Build Cluster**: Run [setup-local-env.sh](./scripts/setup-local-env.sh) to spin up a Kind cluster, standard Gateway API CRDs, Envoy Gateway controller, and ArgoCD.
- **Destroy Cluster**: Run [destroy-local-env.sh](./scripts/destroy-local-env.sh) to tear down the cluster and clean docker resources.

### 3. Pre-push Checklist (BDD / Integration Tests)
Before pushing code, run BDD validation to verify how the application behaves in a simulated live environment:
- Verify Kind cluster status.
- Deploy the applications to the local cluster using `kustomize` / `kubectl`.
- Execute a suite of curl/request checks (simulating a client interacting via HTTPRoute) and pod health checks.
- Run: [run-bdd-tests.sh](./scripts/run-bdd-tests.sh)

### 4. Git Hooks Configuration
To automatically enforce the DoD (Definition of Done), run:
- [install-hooks.sh](./scripts/install-hooks.sh) to link pre-commit and pre-push hooks.

---

## Code Review & Standards Guidelines

1. **Gateway API Enforcement**: Always use Gateway API resources (`HTTPRoute`) instead of the legacy `Ingress` resource.
2. **Infrastructure-as-Code Quality**: Maintain consistent HCL styling with `tofu fmt` and ensure strict compliance with OPA policies.
3. **No Secret Exposures**: Ensure any secrets are managed locally via Kubernetes Secret resources or mock variables, never committed to VCS.
