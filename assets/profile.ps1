$profileItem = Get-Item -LiteralPath $PROFILE -ErrorAction SilentlyContinue
$machineName = [System.Environment]::MachineName
$profileCreatedAt = if ($profileItem) { $profileItem.CreationTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'unknown' }
$currentTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

Write-Host "Machine: $machineName"
Write-Host "Profile created: $profileCreatedAt"
Write-Host "Current time: $currentTime"
