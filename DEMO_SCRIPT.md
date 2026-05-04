# Detection as Code — Demo Script

## Setup (before the demo)

1. Export your Elastic Cloud API key: `export EC_API_KEY=<your-key>`
2. Run bootstrap: `bash scripts/setup.sh`
   - Creates `stuartMoorhouse/terraform-dac` (private) and pushes local content
   - Forks `elastic/detection-rules` to `stuartMoorhouse/detection-rules`
   - Cleans inherited branches, creates `dev`, pushes DaC workflows, sets branch protection
3. Trigger initial Terraform deployment (creates Dev and Prod clusters):
   `gh workflow run deploy-dev.yml --repo stuartMoorhouse/terraform-dac`
4. Once deployment completes, set cluster secrets in the detection-rules fork:
   `bash scripts/set-detection-rules-secrets.sh`
   (requires `DEV_KIBANA_URL`, `DEV_KIBANA_PASSWORD`, `PROD_KIBANA_URL`, `PROD_KIBANA_PASSWORD`, etc.)

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
bash scripts/teardown.sh
```

Deletes `stuartMoorhouse/detection-rules` and `stuartMoorhouse/terraform-dac`.
Destroy Elastic Cloud clusters first: `cd ../terraform-dac && terraform destroy`
