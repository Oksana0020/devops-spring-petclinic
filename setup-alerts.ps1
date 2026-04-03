# Grafana Alerting Setup Script for PetClinic
# Configures Slack contact point, default notification policy and three alert rules:
#   1)PetClinic App Down: fires when app is unreachable (up == 0) for > 1 minute
#   2)High CPU Usage: fires when process_cpu_usage exceeds 80% for > 2 minutes
#   3)High Heap Memory: fires when JVM heap usage exceeds 80% of max for > 2 minutes
# prerequisites: Grafana running on localhost:3000 with Prometheus configured
# using: $env:SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..." ; .\setup-alerts.ps1
$cred = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("admin:mtu12345"))
$headers = @{ "Authorization" = "Basic $cred"; "Content-Type" = "application/json" }
$baseUrl = "http://localhost:3000"
$slackWebhook = $env:SLACK_WEBHOOK_URL

# creating Slack contact point
$contactPoint = @{
  name = "PetClinic Slack"
  type = "slack"
  settings = @{
    url = $slackWebhook
    title = '{{ template "default.title" . }}'
    text = '{{ template "default.message" . }}'
    username = "Grafana Alerts"
    icon_emoji = ":bell:"
  }
  disableResolveMessage = $false
} | ConvertTo-Json -Depth 10

$cp = Invoke-WebRequest -Uri "$baseUrl/api/v1/provisioning/contact-points" -Method POST -Headers $headers -Body $contactPoint -UseBasicParsing | ConvertFrom-Json
Write-Host "Contact point created: $($cp.uid)"
$cpUid = $cp.uid

# update default notification policy to use Slack
$policy = @{
  receiver = "PetClinic Slack"
  group_by = @("alertname")
  group_wait = "30s"
  group_interval = "5m"
  repeat_interval = "1h"
} | ConvertTo-Json -Depth 10

Invoke-WebRequest -Uri "$baseUrl/api/v1/provisioning/policies" -Method PUT -Headers $headers -Body $policy -UseBasicParsing | Out-Null
Write-Host "Notification policy updated"
$ds = (Invoke-WebRequest -Uri "$baseUrl/api/datasources/name/prometheus" -Headers $headers -UseBasicParsing | ConvertFrom-Json)
$dsUid = $ds.uid
Write-Host "Datasource UID: $dsUid"
$folder = @{ title = "PetClinic Alerts" } | ConvertTo-Json
$folderResp = Invoke-WebRequest -Uri "$baseUrl/api/folders" -Method POST -Headers $headers -Body $folder -UseBasicParsing | ConvertFrom-Json
$folderUid = $folderResp.uid
Write-Host "Folder UID: $folderUid"

# alert rules
$alertRules = @{
  name = "PetClinic Alert Rules"
  folderUID = $folderUid
  interval = "1m"
  rules = @(
    @{
      title = "High CPU Usage"
      condition = "C"
      data = @(
        @{ refId="A"; queryType=""; relativeTimeRange=@{from=300;to=0}
           datasourceUid=$dsUid
           model=@{ expr='process_cpu_usage{application="petclinic"}'; refId="A"; intervalMs=1000; maxDataPoints=43200 } },
        @{ refId="C"; queryType=""; relativeTimeRange=@{from=300;to=0}
           datasourceUid="__expr__"
           model=@{ refId="C"; type="threshold"; conditions=@(@{ evaluator=@{params=@(0.8);type="gt"}; operator=@{type="and"}; query=@{params=@("A")}; reducer=@{params=@();type="last"} }) } }
      )
      noDataState = "NoData"
      execErrState = "Error"
      for = "2m"
      annotations = @{ summary="High CPU on PetClinic"; description="CPU usage has exceeded 80% for more than 2 minutes." }
      labels = @{ severity="warning" }
    },
    @{
      title = "High Heap Memory Usage"
      condition = "C"
      data = @(
        @{ refId="A"; queryType=""; relativeTimeRange=@{from=300;to=0}
           datasourceUid=$dsUid
           model=@{ expr='sum(jvm_memory_used_bytes{application="petclinic",area="heap"}) / sum(jvm_memory_max_bytes{application="petclinic",area="heap"})'; refId="A"; intervalMs=1000; maxDataPoints=43200 } },
        @{ refId="C"; queryType=""; relativeTimeRange=@{from=300;to=0}
           datasourceUid="__expr__"
           model=@{ refId="C"; type="threshold"; conditions=@(@{ evaluator=@{params=@(0.8);type="gt"}; operator=@{type="and"}; query=@{params=@("A")}; reducer=@{params=@();type="last"} }) } }
      )
      noDataState = "NoData"
      execErrState = "Error"
      for = "2m"
      annotations = @{ summary="High Heap Memory on PetClinic"; description="JVM heap usage has exceeded 80% of max heap for more than 2 minutes." }
      labels = @{ severity="critical" }
    },
    @{
      title = "PetClinic App Down"
      condition = "C"
      data = @(
        @{ refId="A"; queryType=""; relativeTimeRange=@{from=300;to=0}
           datasourceUid=$dsUid
           model=@{ expr='up{job="petclinic"}'; refId="A"; intervalMs=1000; maxDataPoints=43200 } },
        @{ refId="C"; queryType=""; relativeTimeRange=@{from=300;to=0}
           datasourceUid="__expr__"
           model=@{ refId="C"; type="threshold"; conditions=@(@{ evaluator=@{params=@(1);type="lt"}; operator=@{type="and"}; query=@{params=@("A")}; reducer=@{params=@();type="last"} }) } }
      )
      noDataState = "Alerting"
      execErrState = "Alerting"
      for = "1m"
      annotations = @{ summary="PetClinic is down"; description="PetClinic application is not reachable. Prometheus cannot scrape metrics" }
      labels = @{ severity="critical" }
    }
  )
} | ConvertTo-Json -Depth 20

$alertResp = Invoke-WebRequest -Uri "$baseUrl/api/v1/provisioning/alert-rules/export" -Headers $headers -UseBasicParsing
$rulesResp = Invoke-WebRequest -Uri "$baseUrl/api/v1/provisioning/alert-rules" -Method POST -Headers $headers -Body ($alertRules | ConvertFrom-Json | Select-Object -ExpandProperty rules | Select-Object -First 1 | ConvertTo-Json -Depth 20) -UseBasicParsing
Write-Host $rulesResp.Content

# create each rule individually
$alertRulesObj = $alertRules | ConvertFrom-Json
foreach ($rule in $alertRulesObj.rules) {
  $ruleBody = @{
    title = $rule.title
    condition = $rule.condition
    data = $rule.data
    noDataState = $rule.noDataState
    execErrState = $rule.execErrState
    for = $rule.for
    annotations = $rule.annotations
    labels = $rule.labels
    folderUID = $folderUid
    ruleGroup = "PetClinic Alert Rules"
  } | ConvertTo-Json -Depth 20
  $r = Invoke-WebRequest -Uri "$baseUrl/api/v1/provisioning/alert-rules" -Method POST -Headers $headers -Body $ruleBody -UseBasicParsing | ConvertFrom-Json
  Write-Host "Created rule: $($rule.title) -> UID: $($r.uid)"
}

Write-Host "Done! All alerts configured"
