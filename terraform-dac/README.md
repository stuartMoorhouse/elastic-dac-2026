# terraform-dac

Repo 2 of the Elastic Security Detection-as-Code demo. Contains Terraform that provisions
two Elastic Cloud clusters (Dev + Prod) and deploys detection rules using two native
Terraform approaches.

## What this repo demonstrates

**Scenario 2 — Native HCL rules** (`terraform/rules_hcl.tf`): Detection rules, exception
lists, and exception list items authored directly in HCL using the
`elasticstack_kibana_security_detection_rule` resource. Illustrates full rule lifecycle
management with exception handling, all in version-controlled Terraform.

**Scenario 3 — TOML + for_each** (`terraform/rules_toml.tf`): TOML rule files stored in
`local-detection-rules/` are decoded at plan time using the `Tobotimus/toml` provider and
deployed via a `for_each` loop. This bridges the Elastic `detection-rules` TOML format
with Terraform, avoiding duplication.

## Prerequisites

- Terraform >= 1.5
- An Elastic Cloud API key with deployment permissions
- The API key supplied as an environment variable (never in a committed file):

```bash
export TF_VAR_ec_api_key=<your-elastic-cloud-api-key>
```

## Local usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars as needed (do not add ec_api_key here)
terraform init
terraform apply -var="environment=dev"
```

## CI/CD deployment

Rules are deployed automatically via GitHub Actions:

| Trigger | Workflow | Action |
|---|---|---|
| Push to `feature/**` or PR to `dev`/`main` | `ci.yml` | Secrets scan + fmt/validate |
| Push to `dev` | `deploy-dev.yml` | Deploy to Dev cluster |
| Push to `main` or manual dispatch | `deploy-main.yml` | Deploy to Prod cluster |

All workflows read the API key from the `EC_API_KEY` GitHub secret.

## Directory structure

```
terraform/                  Terraform configuration
  providers.tf              Provider requirements (ec, elasticstack, toml)
  variables.tf              Input variables
  deployments.tf            Dev and Prod Elastic Cloud deployments
  rules_hcl.tf              Scenario 2: HCL-native detection rule + exception list
  rules_toml.tf             Scenario 3: TOML for_each loader
  outputs.tf                Kibana endpoints and workflow guidance
  terraform.tfvars.example  Variable template (safe to commit, no secrets)

local-detection-rules/      TOML rule files consumed by rules_toml.tf (Scenario 3)
  powershell_encoded_command.toml
  lateral_movement_psexec.toml
  c2_beacon_dns.toml

detection-rules-workflows/  Workflow files for the detection-rules fork (Repo 1)
  ci.yml                    Validate rules on feature branches / PRs
  deploy-dev.yml            Upload rules to Dev Kibana on push to dev
  deploy-main.yml           Upload rules to Prod Kibana on push to main

.github/workflows/          CI/CD for this repo (Terraform)
  ci.yml
  deploy-dev.yml
  deploy-main.yml
```

## detection-rules-workflows/

The files in `detection-rules-workflows/` are not used by this repo directly. They are
workflow files intended for the `detection-rules` fork (Repo 1), and are placed here so
the bootstrap script in `elastic-dac-2026` (Repo 3) can copy them into the fork during
environment setup.

## Secrets required

| Secret | Used by |
|---|---|
| `EC_API_KEY` | All Terraform workflows (maps to `TF_VAR_ec_api_key`) |
| `DEV_KIBANA_URL` | detection-rules-workflows/deploy-dev.yml |
| `DEV_KIBANA_USERNAME` | detection-rules-workflows/deploy-dev.yml |
| `DEV_KIBANA_PASSWORD` | detection-rules-workflows/deploy-dev.yml |
| `PROD_KIBANA_URL` | detection-rules-workflows/deploy-main.yml |
| `PROD_KIBANA_USERNAME` | detection-rules-workflows/deploy-main.yml |
| `PROD_KIBANA_PASSWORD` | detection-rules-workflows/deploy-main.yml |
