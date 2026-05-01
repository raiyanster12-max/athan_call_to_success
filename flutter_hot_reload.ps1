$logFile = "C:\Users\r88st\OneDrive\Desktop\athan_call_to_success\flutter_run_machine.log"

if (-not (Test-Path $logFile)) { Write-Host "No flutter run session found"; exit 1 }

$content = Get-Content $logFile -Raw
$match = [regex]::Match($content, '"wsUri":"(ws://[^"]+)"')
if (-not $match.Success) { Write-Host "No VM service URI found in log"; exit 1 }

$wsUri = $match.Groups[1].Value

$ws = [System.Net.WebSockets.ClientWebSocket]::new()
$cts = [System.Threading.CancellationTokenSource]::new(10000)

try {
    $ws.ConnectAsync([Uri]$wsUri, $cts.Token).Wait()

    # Get VM to find isolate ID
    $getVm = '{"jsonrpc":"2.0","method":"getVM","params":{},"id":"1"}'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($getVm)
    $ws.SendAsync([ArraySegment[byte]]$bytes, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).Wait()

    $buf = [byte[]]::new(65536)
    $seg = [ArraySegment[byte]]$buf
    $recv = $ws.ReceiveAsync($seg, $cts.Token).Result
    $vmJson = [System.Text.Encoding]::UTF8.GetString($buf, 0, $recv.Count) | ConvertFrom-Json
    $isolateId = $vmJson.result.isolates[0].id

    # Hot reload
    $reload = '{"jsonrpc":"2.0","method":"reloadSources","params":{"isolateId":"' + $isolateId + '","pause":false},"id":"2"}'
    $bytes2 = [System.Text.Encoding]::UTF8.GetBytes($reload)
    $ws.SendAsync([ArraySegment[byte]]$bytes2, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).Wait()

    $buf2 = [byte[]]::new(65536)
    $seg2 = [ArraySegment[byte]]$buf2
    $recv2 = $ws.ReceiveAsync($seg2, $cts.Token).Result
    $resultJson = [System.Text.Encoding]::UTF8.GetString($buf2, 0, $recv2.Count) | ConvertFrom-Json

    if ($resultJson.result) {
        Write-Host "Hot reload OK: $($resultJson.result.type)"
    } else {
        Write-Host "Hot reload error: $($resultJson.error.message)"
        exit 1
    }
} catch {
    Write-Host "Hot reload failed: $_"
    exit 1
} finally {
    $ws.Dispose()
}
