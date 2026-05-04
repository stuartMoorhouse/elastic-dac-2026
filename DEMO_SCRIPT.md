# Detection as Code — Demo Script

## Prerequisites

Before the demo:

- Elastic Cloud API key exported: `export EC_API_KEY=<your-key>`
- Terraform initialised and infrastructure deployed:
  ```bash
  terraform -chdir=terraform init
  terraform -chdir=terraform apply   # creates both Dev and Prod clusters
  bash scripts/get-env.sh            # writes shared/env.json
  ```
- Python package installed: `pip install elastic-detection-rules`
- Both Dev and Prod Kibana URLs available from `terraform -chdir=terraform output`

---

## The Workflow (big picture)

```
Write rule → test in Dev → commit to feature branch
    → PR review → merge to dev branch → promote to Prod
```

Rules live in `detection-rules/custom-rules/`. Dev is where rules are written and
validated. Prod only receives rules that have passed review on the dev branch.

---

## Act 1: The Problem (1 min)

- Security teams manage dozens or hundreds of detection rules. Editing them one by one
  in the Kibana UI leaves no audit trail, no peer review, and no rollback.
- Rules in Dev drift from rules in Prod. You can't be sure what's actually running.
- Detection as Code solves this: rules live in a Git repo, changes go through PR review,
  and Terraform enforces the desired state on every cluster.

---

## Act 2: Approach 1 — Python CLI (3 min)

- Open `detection-rules/custom-rules/powershell_encoded_command.toml`
- This is the same TOML format used by Elastic's own detection engineers for the
  out-of-the-box rules shipped with Elastic Security.
- Fields map directly to what you see in the Kibana rule editor — query, severity,
  MITRE ATT&CK mappings — but stored as a plain text file you can diff and review in a PR.

Run validation:

```bash
bash scripts/validate-rules.sh
```

- The validator checks schema, required fields, and query syntax before anything touches
  the cluster.
- Key point: catching a broken rule here is free. Catching it in production is not.
- Show `lateral_movement_psexec.toml` and `c2_beacon_dns.toml` — different rule types
  (query and threshold) to show the format handles the full range.

---

## Act 3: Approach 2 — Terraform Native HCL (3 min)

- Open `terraform/rules_hcl.tf`
- The "Service Account Interactive Login" rule is defined directly as a Terraform resource.
- Show the exception list alongside it — `svc_sqlbackup` is approved for interactive
  logins. That approval is code, visible in every PR, not buried in the Kibana UI.
- Run `terraform -chdir=terraform plan -var="environment=dev"` and show the diff output:
  Terraform tells you exactly what will change before it changes it.
- Key point: drift detection. If someone edits a rule manually in Kibana, the next
  `terraform apply` will revert it. The repo is the source of truth.

---

## Act 4: Approach 3 — TOML + Terraform for_each (3 min)

- Open `terraform/rules_toml.tf`
- The pattern: `fileset()` discovers every `.toml` file in `detection-rules/custom-rules/`,
  `toml::decode()` parses it, `for_each` creates one Terraform resource per file.
- Adding a new rule requires no Terraform edits at all — create a TOML, validate it, open a PR.
- Best of both worlds: detection engineers write human-readable TOML in the format they
  already know; Terraform handles deployment consistently across environments.

---

## Act 5: The Full Workflow — Dev to Prod (3 min)

### Step 1 — Write and test in Dev

Create a feature branch and add a new rule:

```bash
git checkout -b feature/detect-mimikatz
cp detection-rules/custom-rules/powershell_encoded_command.toml \
   detection-rules/custom-rules/mimikatz_lsass_access.toml
# edit mimikatz_lsass_access.toml
bash scripts/validate-rules.sh
```

Deploy to Dev to test:

```bash
bash scripts/deploy-dev.sh
```

- Rules land in the Dev Elastic deployment.
- Open Dev Kibana, verify the rule appears, trigger a test alert if you have test data.
- Iterate: edit the TOML, re-run `deploy-dev.sh`, repeat until the rule behaves correctly.

### Step 2 — Commit to feature branch

```bash
git add detection-rules/custom-rules/mimikatz_lsass_access.toml
git commit -m "feat: add Mimikatz LSASS access detection"
git push origin feature/detect-mimikatz
```

Open a PR targeting the `dev` branch. The PR diff shows exactly what changed — the TOML
file, nothing else. Reviewers can comment on the query, severity, MITRE mapping.

### Step 3 — Merge to dev branch

Once the PR is approved and merged to `dev`, the dev branch now reflects the validated
state of all rules that have passed review.

### Step 4 — Promote to Prod

```bash
bash scripts/deploy-prod.sh
```

- The script prompts for explicit confirmation before touching production.
- Same Terraform code, same TOML files, target cluster switches to Prod.
- No manual copy-paste, no drift between Dev and Prod.
- Key point: Prod only ever receives rules that have been written, tested in Dev,
  reviewed in a PR, and merged to the dev branch.

In a real pipeline: replace `deploy-prod.sh` with a CI step that runs automatically
on merge to `main`, gated on the PR approval.

---

## Reset

To reset the demo to a clean state:

```bash
bash scripts/reset-demo.sh
```

Re-applies all rules to Dev from the current branch state. Any manual changes made in
Kibana during the demo are reconciled back to the repo.
