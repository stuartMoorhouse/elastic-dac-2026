# ---------------------------------------------------------------------------
# Exception list — Service Account Interactive Login
# ---------------------------------------------------------------------------

resource "elasticstack_kibana_security_exception_list" "svc_account_login" {
  name           = "Service Account Interactive Login Exceptions"
  list_id        = "svc-account-interactive-login-exceptions"
  description    = "Allowlisted service accounts excluded from the interactive login detection rule"
  type           = "detection"
  namespace_type = "single"
}

# ---------------------------------------------------------------------------
# Exception list item — svc_sqlbackup
# ---------------------------------------------------------------------------

resource "elasticstack_kibana_security_exception_item" "svc_sqlbackup" {
  name           = "Exclude svc_sqlbackup"
  item_id        = "svc-sqlbackup-exclusion"
  list_id        = elasticstack_kibana_security_exception_list.svc_account_login.list_id
  namespace_type = "single"
  description    = "SQL backup service account — interactive logins are expected during maintenance windows"
  type           = "simple"

  entries = [
    {
      field    = "user.name"
      operator = "included"
      type     = "match"
      value    = "svc_sqlbackup"
    }
  ]
}

# ---------------------------------------------------------------------------
# Detection rule — Service Account Interactive Login (ESQL)
# ---------------------------------------------------------------------------

resource "elasticstack_kibana_security_detection_rule" "svc_account_login" {
  name        = "Service Account Interactive Login"
  description = "Detects interactive (type 2) Windows logon events where the username starts with 'svc_', which may indicate misuse or compromise of a service account."
  rule_id     = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  enabled     = false
  risk_score  = 73
  severity    = "high"
  type        = "esql"
  language    = "esql"
  version     = 1
  interval    = "5m"
  from        = "now-6m"
  to          = "now"
  author      = ["Elastic"]
  license     = "Elastic License v2"
  tags        = ["Detection-as-Code", "Windows", "Service Account", "Privilege Abuse"]

  query = <<-ESQL
    FROM logs-system.security-* metadata _id, _version, _index
    | WHERE event.code == "4624"
      AND winlog.logon.type == "Interactive"
      AND user.name LIKE "svc_*"
    | KEEP _id, _index, _version, user.name, host.name, @timestamp
  ESQL

  threat = [
    {
      framework = "MITRE ATT&CK"
      tactic = {
        id        = "TA0001"
        name      = "Initial Access"
        reference = "https://attack.mitre.org/tactics/TA0001/"
      }
      technique = [
        {
          id        = "T1078"
          name      = "Valid Accounts"
          reference = "https://attack.mitre.org/techniques/T1078/"
          subtechnique = [
            {
              id        = "T1078.002"
              name      = "Domain Accounts"
              reference = "https://attack.mitre.org/techniques/T1078/002/"
            }
          ]
        }
      ]
    }
  ]

  exceptions_list = [
    {
      id             = elasticstack_kibana_security_exception_list.svc_account_login.id
      list_id        = elasticstack_kibana_security_exception_list.svc_account_login.list_id
      namespace_type = "single"
      type           = "detection"
    }
  ]
}
