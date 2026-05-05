# Detection as Code — Demo Script

## Setup (before the demo)

```bash
export EC_API_KEY=<your Elastic Cloud API key>
export DETECTION_TEAM_LEAD_TOKEN=<GitHub PAT for detection-team-lead account>
bash scripts/setup.sh
```

This single command does everything:
1. Forks `elastic/detection-rules`, strips inherited branches and workflows, pushes DaC demo workflows
2. Runs `terraform apply` — provisions Dev + Prod Elastic Cloud clusters, creates `terraform-dac` repo, sets branch protection, adds `detection-team-lead` as a collaborator, and stores secrets in both repos
3. Clones both demo repos to the parent directory, ready for presentation

Prerequisites: `gh` (authenticated as your main account), `git`, `terraform >= 1.8`, `EC_API_KEY` and `DETECTION_TEAM_LEAD_TOKEN` set.

---

## The two demo repos

| Repo | Purpose | Audience-visible |
|------|---------|-----------------|
| `stuartMoorhouse/detection-rules` | Rules authoring, Python CLI — Scenario 1 | Yes |
| `stuartMoorhouse/terraform-dac` | Terraform rule deployment — Scenarios 2 & 3 | Yes |
| `elastic-dac-2026` (this repo) | Bootstrap, teardown, demo script — never shown | No |

---

## The workflow (all three scenarios)

```
feature branch  →  push  →  CI validates
                              ↓
                            PR to main  →  detection-team-lead approves
                                            ↓
                                          merge  →  CI deploys to Prod Kibana
```

Dev Elastic cluster = sandbox. Rules are authored and tested there manually. Prod is only updated via an approved PR merge to `main`.

---

## Scenario 1: Python CLI (Repo 1)

Audience sees: `stuartMoorhouse/detection-rules`

**Show what DaC looks like at rest:**
- Open `custom-rules/rules/powershell_encoded_command.toml`
- Fields map directly to the Kibana rule editor — query, severity, MITRE ATT&CK — but stored as plain text in Git
- Same TOML format Elastic's own engineers use for built-in rules

**Author a new rule using the Dev cluster as a sandbox:**
- Open Dev Kibana, navigate to Security > Rules, create a new rule via the UI
- Once satisfied, export it to TOML using the CLI (install once with `pip install elastic-detection-rules`):
  ```bash
  python -m detection_rules kibana export-rules \
    --kibana-url $DEV_KIBANA_URL \
    -u elastic -p $DEV_KIBANA_PASSWORD \
    --custom-rules-only \
    --directory custom-rules/rules/
  ```
- The exported TOML file is now under version control

**Push through the pipeline:**
```bash
git checkout -b feature/detect-mimikatz
git add custom-rules/rules/mimikatz_lsass_access.toml
git commit -m "feat: add Mimikatz LSASS access detection"
git push origin feature/detect-mimikatz
```
- CI runs "Validate Detection Rules" on push — schema + query syntax checked before any cluster is touched
- Open a PR to `main`:
  ```bash
  gh pr create --base main --title "feat: Mimikatz LSASS access"
  ```
- Log in as `detection-team-lead`, review and approve the PR
- Merge — CI deploys the rule to Prod Kibana automatically
- Key point: Prod is only ever updated via an approved PR. No one can bypass this — branch protection enforces it.

---

## Scenario 2: Terraform-native HCL (Repo 2)

Audience sees: `stuartMoorhouse/terraform-dac`

- Open `rules_hcl.tf`
- The "Service Account Interactive Login" rule is a plain Terraform resource — show the exception list alongside it
- `svc_sqlbackup` is approved for interactive logins: that approval is code, visible in every PR, reviewable, auditable
- Run a plan against the Dev cluster to show the diff before anything changes:
  ```bash
  cd terraform
  terraform init
  terraform plan -var="kibana_endpoint=$DEV_KIBANA_URL" -var="kibana_password=$DEV_KIBANA_PASSWORD"
  ```
- Key point: drift detection — if someone edits a rule manually in Kibana, the next `terraform apply` reverts it

**Push through the pipeline:**
- Add or modify a rule in HCL, create a feature branch, open a PR to `main`
- `detection-team-lead` approves; merge triggers CI deploy to Prod

---

## Scenario 3: TOML + Terraform for_each (Repo 2)

Audience sees: `stuartMoorhouse/terraform-dac`

- Open `rules_toml.tf`
- Pattern: `fileset()` discovers every `.toml` in `local-detection-rules/`, `toml::decode()` parses it, `for_each` creates one Elastic rule resource per file
- Adding a new rule = drop in a TOML file, no Terraform edits required
- Best of both worlds: detection engineers write human-readable TOML; Terraform handles deployment across environments

**Push through the pipeline:**
- Add a `.toml` file, create a feature branch, open a PR to `main`
- CI shows the `terraform plan` diff — one new rule resource
- `detection-team-lead` approves; merge deploys to Prod

---

## Reset (between rehearsals)

```bash
bash scripts/reset-demo.sh
```

Closes open PRs and deletes `feature/*`, `feat/*`, `fix/*` branches in both repos.

---

## Teardown (after the demo)

```bash
export GITHUB_TOKEN=$(gh auth token)
bash scripts/teardown.sh
```

Runs `terraform destroy` in `infra/` (removes the `terraform-dac` repo, branch protection, secrets, collaborators, and Elastic Cloud clusters), then deletes the `detection-rules` fork.
