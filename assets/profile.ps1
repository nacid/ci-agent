$machineName = [System.Environment]::MachineName
$osName = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption

Write-Host "$machineName ($osName)"

$ArtifactsDir = Join-Path $HOME 'Artifacts' 
$WoodpeckerLogPath = Join-Path $ArtifactsDir '.woodpecker-current.log'
Start-Transcript -Path $WoodpeckerLogPath -Append | Out-Null
