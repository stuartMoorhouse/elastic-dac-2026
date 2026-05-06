# Detection as Code — Demo Script

## Setup (before the demo)

```bash
export EC_API_KEY=<your Elastic Cloud API key>
export DETECTION_TEAM_LEAD_TOKEN=<GitHub PAT for detection-team-lead account>
bash scripts/setup.sh
```

This single command does everything:
1. Forks `elastic/detection-rules`, strips inherited branches and workflows, pushes DaC demo workflows
2. Runs `terraform apply` — provisions Dev + Prod Elastic Cloud clusters, sets branch protection, adds `detection-team-lead` as a collaborator, and stores secrets in the `detection-rules` repo
3. Clones the demo repo to the parent directory, ready for presentation

Prerequisites: `gh` (authenticated as your main account), `git`, `terraform >= 1.8`, `EC_API_KEY` and `DETECTION_TEAM_LEAD_TOKEN` set.

### Python environment (detection-rules repo)

The export command in Scenario 1 requires the `detection-rules` CLI. Set this up once after `setup.sh` completes:

```bash
cd ../detection-rules
python3 --version          # must be 3.12+; install via: brew install python@3.12
python3 -m venv env
source env/bin/activate
pip install --upgrade pip
pip install -e ".[dev]"    # installs from the fork's own source (~2-3 min first time)
pip install lib/kql lib/kibana
python -m detection_rules --help   # verify install
```

Keep the venv active in the terminal you use for the demo. Before each session:

```bash
cd ../detection-rules
source env/bin/activate
```

### Terraform environment
```bash
cd terraform/scenario2 && terraform init
cd ../scenario3 && terraform init
```

---

## The demo repos

| Repo | Purpose | Audience-visible |
|------|---------|-----------------|
| `stuartMoorhouse/detection-rules` | Rules authoring, Python CLI — Scenario 1 | Yes |
| `elastic-dac-2026/terraform` | Terraform files shown locally — Scenarios 2 & 3 | No |
| `elastic-dac-2026` (this repo) | Bootstrap, teardown, demo script — never shown | No |

---

## The workflow (Scenario 1)

```
feature branch  →  push  →  CI validates
                              ↓
                            PR to main  →  detection-team-lead approves
                                            ↓
                                          merge  →  CI deploys to Prod Kibana
```

Dev Elastic cluster = sandbox. Rules are authored and tested there manually. Prod is only updated via an approved PR merge to `main`.

Scenarios 2 & 3 demonstrate the Terraform approach locally — `terraform plan` and `terraform apply` run directly against the Dev cluster.

---

## Scenario 1: Python CLI (Repo 1)
**1. Author a new rule using the Dev cluster as a sandbox:**

Create a feature branch first (in the `../detection-rules` directory):
```bash
git checkout -b feature/c2-beacon-detection
```

Setup has already loaded test data into Dev — 8 malicious C2 beacon events (outbound to
`185.220.101.0/24` and `194.147.78.0/24`, <1 KB payload) and 4 legitimate/excluded events.

- Open Dev Kibana → Security > Rules → Create new rule → Custom query
- Set index pattern: `logs-network_traffic-default`
- Enter the query:
  ```
  event.category:network and
  network.direction:outbound and
  destination.ip:(185.220.101.0/24 or 194.147.78.0/24) and
  network.bytes < 1024 and
  not user.name:(security_scanner or backup_service)
  ```
- Click "Test" — should return 8 matching documents
- Fill in rule details:
  - Name: `Outbound C2 Beacon to Known Malicious Infrastructure`
  - Severity: High / Risk score: 73
  - MITRE: TA0011 Command and Control  → T1071 Application Layer Protocols → T1071.001 Web Protocols
- Save the rule

Export to TOML (with the venv active — credentials come from `.detection-rules-cfg.json` written by setup.sh):
```bash
python -m detection_rules kibana export-rules \
  --custom-rules-only \
  --strip-version \
  --directory custom-rules/rules/
```

**2. Push through the pipeline:**
```bash
git add custom-rules/rules/
git commit -m "feat: add C2 beacon detection for known malicious infrastructure"
git push origin feature/c2-beacon-detection
```
- CI runs "Validate Detection Rules" on push — schema + query syntax checked before any cluster is touched
- Once all checks pass, CI automatically opens a PR to `main`
- In a private/incognito browser window, log in to GitHub as `detection-team-lead` and open the PR
- Click the **Files changed** tab → a review panel appears on the right
- Select **Approve**, then click **Submit review**
- Back in your main browser as `stuartMoorhouse`, the Merge button is now unblocked — click **Merge pull request**
- CI deploys the rule to Prod Kibana automatically
- Key point: Prod is only ever updated via an approved PR. No one can bypass this — branch protection enforces it.

---

## 2. Scenario 2: Terraform-native HCL

```bash
cd terraform/scenario2
```

- Open `terraform/scenario2/rules_hcl.tf`
- The "Service Account Interactive Login" rule is a plain Terraform resource — show the exception list alongside it
- `svc_sqlbackup` is approved for interactive logins: that approval is code, visible in every PR, reviewable, auditable
- Run a plan against the Dev cluster to show the diff before anything changes:
  ```bash
  terraform plan
  terraform apply --auto-approve
  ```
- Key point: drift detection — if someone edits a rule manually in Kibana, the next `terraform apply` reverts it
- Key point: parameterized rules (to do)

---

## 3. Scenario 3: TOML + Terraform for_each

- Open `terraform/scenario3/rules_toml.tf`
- Pattern: `fileset()` discovers every `.toml` in `local-detection-rules/`, `toml::decode()` parses it, `for_each` creates one Elastic rule resource per file
- Adding a new rule = drop in a TOML file, no Terraform edits required
- Best of both worlds: detection engineers write human-readable TOML; Terraform handles deployment across environments

**Show what DaC looks like at rest:**
- Open `local-detection-rules/` — three rules are already present:
  - `powershell_encoded_command.toml` — Suspicious PowerShell Encoded Command Execution
  - `lateral_movement_psexec.toml` — Potential Lateral Movement via PsExec
  - `c2_beacon_dns.toml` — Potential C2 Beacon via High-Frequency DNS
- Fields map directly to the Kibana rule editor — query, severity, MITRE ATT&CK — but stored as plain text in Git
- Same TOML format Elastic's own engineers use for built-in rules

**Show the apply:**
- Add a `.toml` file to `local-detection-rules/`
- Run `terraform apply` from `terraform/scenario3/` — one new rule resource appears

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

Runs `terraform destroy` in `infra/` (removes branch protection, secrets, collaborators, and Elastic Cloud clusters), then deletes the `detection-rules` fork.
