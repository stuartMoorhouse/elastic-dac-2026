#!/usr/bin/env bash
set -euo pipefail

# Loads ECS-compliant network traffic test data into the Dev Elasticsearch cluster.
# Creates malicious C2 beacon events (to 185.220.101.0/24 and 194.147.78.0/24) and
# legitimate traffic, so the Scenario 1 demo rule immediately finds matching data.
#
# Reads cluster credentials from terraform outputs in infra/.
# Requires: curl, jq

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"

for cmd in curl jq terraform; do
  command -v "$cmd" &>/dev/null || { echo "Error: $cmd is required" >&2; exit 1; }
done

echo "Reading Dev cluster credentials from terraform outputs..."
ES_URL=$(terraform -chdir="$INFRA_DIR" output -raw dev_elasticsearch_endpoint)
ES_USER=$(terraform -chdir="$INFRA_DIR" output -raw dev_elasticsearch_username)
ES_PASS=$(terraform -chdir="$INFRA_DIR" output -raw dev_elasticsearch_password)

echo "  Endpoint: $ES_URL"
echo ""

# ---------------------------------------------------------------------------
# Index template + data stream
# ---------------------------------------------------------------------------

# Clean up any previous run so this script is idempotent
curl -sS -X DELETE "$ES_URL/_data_stream/logs-network_traffic-default" \
  -u "$ES_USER:$ES_PASS" > /dev/null 2>&1 || true
curl -sS -X DELETE "$ES_URL/_index_template/dac-demo-network-traffic" \
  -u "$ES_USER:$ES_PASS" > /dev/null 2>&1 || true
curl -sS -X DELETE "$ES_URL/_index_template/logs-network_traffic" \
  -u "$ES_USER:$ES_PASS" > /dev/null 2>&1 || true

echo "Creating component template..."
curl -sS -X PUT "$ES_URL/_component_template/logs-network_traffic-default-mappings" \
  -u "$ES_USER:$ES_PASS" -H "Content-Type: application/json" -d '{
  "template": {
    "mappings": {
      "properties": {
        "@timestamp":          { "type": "date" },
        "event.category":      { "type": "keyword" },
        "event.kind":          { "type": "keyword" },
        "network.direction":   { "type": "keyword" },
        "network.bytes":       { "type": "long" },
        "network.transport":   { "type": "keyword" },
        "network.protocol":    { "type": "keyword" },
        "source.ip":           { "type": "ip" },
        "source.port":         { "type": "long" },
        "destination.ip":      { "type": "ip" },
        "destination.port":    { "type": "long" },
        "host.name":           { "type": "keyword" },
        "user.name":           { "type": "keyword" },
        "process.name":        { "type": "keyword" },
        "data_stream.dataset": { "type": "keyword" },
        "data_stream.namespace":{ "type": "keyword" },
        "data_stream.type":    { "type": "keyword" }
      }
    }
  }
}' | jq -r '.acknowledged // .' ; echo ""

echo "Creating index template..."
curl -sS -X PUT "$ES_URL/_index_template/dac-demo-network-traffic" \
  -u "$ES_USER:$ES_PASS" -H "Content-Type: application/json" -d '{
  "index_patterns": ["logs-network_traffic-default"],
  "data_stream":    {},
  "composed_of":    ["logs-network_traffic-default-mappings"],
  "priority":       1000
}' | jq -r '.acknowledged // .' ; echo ""

echo "Creating data stream..."
curl -sS -X PUT "$ES_URL/_data_stream/logs-network_traffic-default" \
  -u "$ES_USER:$ES_PASS" | jq -r '.acknowledged // .' ; echo ""

# ---------------------------------------------------------------------------
# Timestamps
# ---------------------------------------------------------------------------

T_NOW=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
T_2M=$(date -u -v-2M  +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -d '2 minutes ago'  +%Y-%m-%dT%H:%M:%S.000Z)
T_5M=$(date -u -v-5M  +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -d '5 minutes ago'  +%Y-%m-%dT%H:%M:%S.000Z)
T_10M=$(date -u -v-10M +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S.000Z)
T_15M=$(date -u -v-15M +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S.000Z)
T_20M=$(date -u -v-20M +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -d '20 minutes ago' +%Y-%m-%dT%H:%M:%S.000Z)
T_25M=$(date -u -v-25M +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -d '25 minutes ago' +%Y-%m-%dT%H:%M:%S.000Z)
T_30M=$(date -u -v-30M +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S.000Z)

# ---------------------------------------------------------------------------
# Malicious C2 beacon traffic  (will trigger the detection rule)
# Small payloads (<1KB) to known bad IP ranges, no excluded users
# ---------------------------------------------------------------------------

echo "Loading malicious C2 beacon traffic..."
curl -sS -X POST "$ES_URL/_bulk" \
  -u "$ES_USER:$ES_PASS" -H "Content-Type: application/x-ndjson" --data-binary @- <<BULK | jq -r '.errors'
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_30M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":512,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.1.50","port":58234},"destination":{"ip":"185.220.101.45","port":443},"host":{"name":"workstation-001"},"process":{"name":"chrome.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_25M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":623,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.2.15","port":49823},"destination":{"ip":"185.220.101.67","port":8443},"host":{"name":"workstation-002"},"process":{"name":"edge.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_20M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":445,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.2.15","port":51234},"destination":{"ip":"194.147.78.23","port":443},"host":{"name":"workstation-002"},"process":{"name":"edge.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_15M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":892,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.3.75","port":60123},"destination":{"ip":"185.220.101.100","port":443},"host":{"name":"server-web-01"},"process":{"name":"svchost.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_10M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":756,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.3.75","port":61234},"destination":{"ip":"194.147.78.155","port":8443},"host":{"name":"server-web-01"},"process":{"name":"svchost.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_5M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":234,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.4.100","port":62345},"destination":{"ip":"185.220.101.200","port":443},"host":{"name":"laptop-exec-05"},"process":{"name":"firefox.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_2M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":567,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.4.101","port":63456},"destination":{"ip":"194.147.78.250","port":443},"host":{"name":"laptop-exec-06"},"process":{"name":"chrome.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_NOW","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":345,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.5.51","port":65678},"destination":{"ip":"185.220.101.5","port":8443},"host":{"name":"desktop-fin-02"},"process":{"name":"chrome.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
BULK

echo ""

# ---------------------------------------------------------------------------
# Legitimate traffic + excluded users  (should NOT trigger the rule)
# ---------------------------------------------------------------------------

echo "Loading legitimate traffic..."
curl -sS -X POST "$ES_URL/_bulk" \
  -u "$ES_USER:$ES_PASS" -H "Content-Type: application/x-ndjson" --data-binary @- <<BULK | jq -r '.errors'
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_30M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":5234,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.1.50","port":50234},"destination":{"ip":"142.250.185.46","port":443},"host":{"name":"workstation-001"},"process":{"name":"chrome.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_15M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":8912,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.1.51","port":51345},"destination":{"ip":"52.88.151.22","port":443},"host":{"name":"workstation-003"},"process":{"name":"teams.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_5M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":734,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.4.100","port":56890},"destination":{"ip":"185.220.101.200","port":443},"host":{"name":"laptop-exec-05"},"user":{"name":"backup_service"},"process":{"name":"backup.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic-default"}}
{"@timestamp":"$T_2M","event":{"category":"network","kind":"event"},"network":{"direction":"outbound","bytes":512,"transport":"tcp","protocol":"https"},"source":{"ip":"10.0.4.100","port":56891},"destination":{"ip":"185.220.101.200","port":443},"host":{"name":"laptop-exec-05"},"user":{"name":"security_scanner"},"process":{"name":"nessus.exe"},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
BULK

echo ""

# Refresh and verify
curl -sS -X POST "$ES_URL/logs-network_traffic-default/_refresh" -u "$ES_USER:$ES_PASS" | jq -r '.acknowledged // .'

TOTAL=$(curl -sS "$ES_URL/logs-network_traffic-default/_count" \
  -u "$ES_USER:$ES_PASS" | jq -r '.count')

SHOULD_ALERT=$(curl -sS -X POST "$ES_URL/logs-network_traffic-default/_count" \
  -u "$ES_USER:$ES_PASS" -H "Content-Type: application/json" -d '{
  "query": {
    "bool": {
      "filter": [
        {"term":  {"event.category": "network"}},
        {"term":  {"network.direction": "outbound"}},
        {"range": {"network.bytes": {"lt": 1024}}},
        {"bool":  {"should": [
          {"term": {"destination.ip": "185.220.101.0/24"}},
          {"term": {"destination.ip": "194.147.78.0/24"}}
        ], "minimum_should_match": 1}}
      ],
      "must_not": [
        {"terms": {"user.name": ["security_scanner", "backup_service"]}}
      ]
    }
  }
}' | jq -r '.count // 0')
SHOULD_ALERT=${SHOULD_ALERT:-0}

echo ""
echo "=== Test data loaded ==="
echo "  Total documents : $TOTAL"
echo "  Should alert    : $SHOULD_ALERT  (C2 beacons, <1KB, no excluded users)"
echo "  No alert        : $((TOTAL - SHOULD_ALERT))  (legitimate traffic or excluded users)"
