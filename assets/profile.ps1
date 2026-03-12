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
elseif ($IsMacOS) {
    $swVersCommand = Get-Command -Name 'sw_vers' -ErrorAction SilentlyContinue
    if ($swVersCommand) {
        try {
            $productName = (sw_vers -productName).Trim()
            $productVersion = (sw_vers -productVersion).Trim()

            if (-not [string]::IsNullOrWhiteSpace($productName) -and -not [string]::IsNullOrWhiteSpace($productVersion)) {
                $osName = "$productName ($productVersion)"
            }
            elseif (-not [string]::IsNullOrWhiteSpace($productName)) {
                $osName = $productName
            }
        } catch {
        }
    }
}

Write-Host "$machineName - $osName"

Start-Transcript -Path $env:PATH_LOG -Append | Out-Null
