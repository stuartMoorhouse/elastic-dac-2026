locals {
  rule_files = fileset(path.module, "../local-detection-rules/*.toml")

  raw_decoded = {
    for f in local.rule_files :
    f => provider::toml::decode(file("${path.module}/${f}"))
  }

  normalized_rules = {
    for f, content in local.raw_decoded :
    f => content.rule
  }
}

resource "elasticstack_kibana_security_detection_rule" "toml_rules" {
  for_each = local.normalized_rules

  name        = each.value.name
  description = try(each.value.description, null)
  rule_id     = try(each.value.rule_id, null)
  enabled     = try(each.value.enabled, false)
  risk_score  = each.value.risk_score
  severity    = each.value.severity
  type        = each.value.type

  author   = try(each.value.author, null)
  license  = try(each.value.license, null)
  version  = try(each.value.version, 1)
  interval = try(each.value.interval, "5m")
  from     = try(each.value.from, "now-6m")
  to       = try(each.value.to, "now")

  language = try(each.value.language, null)
  query    = try(each.value.query, null)
  index    = try(each.value.index, null)
  tags     = try(each.value.tags, null)

  timestamp_override   = try(each.value.timestamp_override, null)
  investigation_fields = try(each.value.investigation_fields, null)
  filters              = try(length(each.value.filters) > 0 ? jsonencode(each.value.filters) : null, null)

  threat = try(length(each.value.threat) > 0 ? [
    for t in each.value.threat : {
      framework = t.framework
      tactic = {
        id        = t.tactic.id
        name      = t.tactic.name
        reference = t.tactic.reference
      }
      technique = try(length(t.technique) > 0 ? [
        for tech in t.technique : {
          id        = tech.id
          name      = tech.name
          reference = tech.reference
          subtechnique = try(length(tech.subtechnique) > 0 ? [
            for sub in tech.subtechnique : {
              id        = sub.id
              name      = sub.name
              reference = sub.reference
            }
          ] : null, null)
        }
      ] : null, null)
    }
  ] : null, null)

  alert_suppression = try(each.value.alert_suppression != null ? {
    group_by                = try(each.value.alert_suppression.group_by, null)
    duration                = try(each.value.alert_suppression.duration, null)
    missing_fields_strategy = try(each.value.alert_suppression.missing_fields_strategy, null)
  } : null, null)

  threshold = try(each.value.threshold != null ? {
    field = try(each.value.threshold.field, null)
    value = try(each.value.threshold.value, null)
    cardinality = try(each.value.threshold.cardinality != null ? {
      field = each.value.threshold.cardinality.field
      value = each.value.threshold.cardinality.value
    } : null, null)
  } : null, null)

  required_fields = try(length(each.value.required_fields) > 0 ? [
    for rf in each.value.required_fields : {
      name = rf.name
      type = rf.type
    }
  ] : null, null)

  related_integrations = try(length(each.value.related_integrations) > 0 ? [
    for ri in each.value.related_integrations : {
      package     = ri.package
      version     = ri.version
      integration = try(ri.integration, null)
    }
  ] : null, null)

  exceptions_list = try(length(each.value.exceptions_list) > 0 ? [
    for el in each.value.exceptions_list : {
      id             = el.id
      list_id        = el.list_id
      namespace_type = el.namespace_type
      type           = el.type
    }
  ] : null, null)
}
