$machineName = [System.Environment]::MachineName
$runtimeOsDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
$osName = $runtimeOsDescription

if ($IsWindows) {
    $getCimInstanceCommand = Get-Command -Name 'Get-CimInstance' -ErrorAction SilentlyContinue
    if ($getCimInstanceCommand) {
        try {
            $cimOsName = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).Caption
            if (-not [string]::IsNullOrWhiteSpace($cimOsName)) {
                $osName = $cimOsName
            }
        } catch {
        }
    }
}

Write-Host "$machineName ($osName)"

$ArtifactsDir = Join-Path $HOME 'Artifacts' 
$WoodpeckerLogPath = Join-Path $ArtifactsDir '.woodpecker-current.log'
Start-Transcript -Path $WoodpeckerLogPath -Append | Out-Null
