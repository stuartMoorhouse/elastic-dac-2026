# Detection as Code — Demo Script

## Setup (before the demo)

1. Fork the detection-rules repo (the only thing Terraform can't do):
   ```bash
   bash scripts/setup.sh
   ```
   This forks `elastic/detection-rules`, creates the `dev` branch, strips
   inherited workflows, and pushes the DaC demo workflows.

2. Provision everything else with one `terraform apply`:
   ```bash
   export TF_VAR_ec_api_key=<your Elastic Cloud API key>
   export GITHUB_TOKEN=$(gh auth token)
   cd infra/
   terraform init
   terraform apply
   ```
   This creates the `terraform-dac` repo (and pushes content), provisions
   Dev + Prod Elastic Cloud clusters, and sets branch protection and secrets
   in both repos automatically.

---

## The three repos

| Repo | Purpose | Audience-visible |
|------|---------|-----------------|
| `stuartMoorhouse/detection-rules` | Rules authoring, Python CLI — Scenario 1 | Yes |
| `stuartMoorhouse/terraform-dac` | Terraform for clusters + rule deployment — Scenarios 2 & 3 | Yes |
| `elastic-dac-2026` (this repo) | Bootstrap, teardown, demo script — never shown | No |

---

## Scenario 1: Python CLI (Repo 1)

Audience sees: `stuartMoorhouse/detection-rules`

- Open `custom-rules/rules/powershell_encoded_command.toml`
- Point out: same TOML format Elastic's own engineers use for built-in rules
- Fields map directly to Kibana rule editor — query, severity, MITRE ATT&CK — but stored as plain text
- Create a feature branch and add a new rule:
  ```bash
  git checkout -b feature/detect-mimikatz
  cp custom-rules/rules/powershell_encoded_command.toml \
     custom-rules/rules/mimikatz_lsass_access.toml
  # edit mimikatz_lsass_access.toml
  ```
- Push and open a PR targeting `dev`:
  ```bash
  git add custom-rules/rules/mimikatz_lsass_access.toml
  git commit -m "feat: add Mimikatz LSASS access detection"
  git push origin feature/detect-mimikatz
  gh pr create --base dev --title "feat: Mimikatz LSASS access"
  ```
- The "Validate Detection Rules" CI check runs automatically — shows schema + query syntax validation
- Key point: a broken rule is caught here, before it touches any cluster
- Once approved, merge to `dev` — CI deploys to Dev cluster automatically

---

## Scenario 2: Terraform-native HCL (Repo 2)

Audience sees: `stuartMoorhouse/terraform-dac`

- Open `rules_hcl.tf`
- The "Service Account Interactive Login" rule is a Terraform resource — show the exception list alongside it
- `svc_sqlbackup` is approved for interactive logins: that approval is code, visible in every PR
- Run `terraform plan -var="environment=dev"` — show the diff before anything changes
- Key point: drift detection — if someone edits a rule manually in Kibana, the next `terraform apply` reverts it

---

## Scenario 3: TOML + Terraform for_each (Repo 2)

Audience sees: `stuartMoorhouse/terraform-dac`

- Open `rules_toml.tf`
- Pattern: `fileset()` discovers every `.toml` in `local-detection-rules/`, `toml::decode()` parses it, `for_each` creates one resource per file
- Adding a new rule = create a TOML file, no Terraform edits required
- Best of both worlds: detection engineers write human-readable TOML; Terraform handles deployment across environments
- Add a rule, open a PR to `dev`, show the plan diff in CI

---

## Reset

```bash
bash scripts/reset-demo.sh
```

Closes open PRs and deletes `feature/*`, `feat/*`, `fix/*` branches in the detection-rules fork.

---

## Teardown (after the demo)

```bash
export GITHUB_TOKEN=$(gh auth token)
bash scripts/teardown.sh
```

Runs `terraform destroy` in `infra/` (removes the `terraform-dac` repo, branch
protection, secrets, and Elastic Cloud clusters), then deletes the
`detection-rules` fork.
