$cred = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("admin:mtu12345"))
$headers = @{ "Authorization" = "Basic $cred"; "Content-Type" = "application/json" }
$body = @{
  overwrite = $true
  folderId = 0
  dashboard = @{
    title = "PetClinic Metrics"
    schemaVersion = 36
    version = 0
    panels = @(
      @{ id=1; title="Uptime"; type="stat"; gridPos=@{h=4;w=6;x=0;y=0}; datasource="prometheus"
         targets=@(@{ expr='process_uptime_seconds{application="petclinic"}'; refId="A"; legendFormat="Uptime" }) },
      @{ id=2; title="Heap Used (bytes)"; type="stat"; gridPos=@{h=4;w=6;x=6;y=0}; datasource="prometheus"
         targets=@(@{ expr='sum(jvm_memory_used_bytes{application="petclinic",area="heap"})'; refId="A" }) },
      @{ id=3; title="Non-Heap Used (bytes)"; type="stat"; gridPos=@{h=4;w=6;x=12;y=0}; datasource="prometheus"
         targets=@(@{ expr='sum(jvm_memory_used_bytes{application="petclinic",area="nonheap"})'; refId="A" }) },
      @{ id=4; title="CPU Usage"; type="timeseries"; gridPos=@{h=8;w=12;x=0;y=4}; datasource="prometheus"
         targets=@(@{ expr='process_cpu_usage{application="petclinic"}'; refId="A"; legendFormat="CPU" }) },
      @{ id=5; title="JVM Memory Used"; type="timeseries"; gridPos=@{h=8;w=12;x=12;y=4}; datasource="prometheus"
         targets=@(@{ expr='jvm_memory_used_bytes{application="petclinic"}'; refId="A"; legendFormat="{{id}}" }) },
      @{ id=6; title="HTTP Request Rate"; type="timeseries"; gridPos=@{h=8;w=24;x=0;y=12}; datasource="prometheus"
         targets=@(@{ expr='rate(http_server_requests_seconds_count{application="petclinic"}[1m])'; refId="A"; legendFormat="{{uri}} [{{status}}]" }) }
    )
  }
} | ConvertTo-Json -Depth 10

$response = Invoke-WebRequest -Uri "http://localhost:3000/api/dashboards/db" -Method POST -Headers $headers -Body $body -UseBasicParsing
$response.Content
