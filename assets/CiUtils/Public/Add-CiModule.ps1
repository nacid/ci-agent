function Add-CiModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $inputPath = $Path.Trim()
    $modulePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($inputPath)

    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        return
    }

    if ([System.IO.Path]::GetExtension($modulePath) -ine '.psm1') {
        return
    }

    $normalizedModulePath = [System.IO.Path]::GetFullPath($modulePath)

    $isLoaded = Get-Module | Where-Object {
        $_.Path -and
        [System.IO.Path]::GetFullPath($_.Path).Equals($normalizedModulePath, [System.StringComparison]::OrdinalIgnoreCase)
    }

    if (-not $isLoaded) {
        Import-Module -Name $normalizedModulePath -Global -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction Stop
    }

    if (-not $script:CiEnvironmentFilePath -or -not (Test-Path -LiteralPath $script:CiEnvironmentFilePath -PathType Leaf)) {
        if (Get-Command -Name Initialize-CiEnvironmentFile -CommandType Function -ErrorAction SilentlyContinue) {
            Initialize-CiEnvironmentFile
        }
    }

    if (-not $script:CiEnvironmentFilePath -or -not (Test-Path -LiteralPath $script:CiEnvironmentFilePath -PathType Leaf)) {
        return
    }

    $environmentData = Import-PowerShellDataFile -Path $script:CiEnvironmentFilePath
    $registeredModules = @()
    if ($environmentData.ContainsKey('Modules') -and $environmentData.Modules) {
        $registeredModules = @($environmentData.Modules | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }

    $isRegistered = $false
    foreach ($registeredModule in $registeredModules) {
        $registeredModulePath = [string]$registeredModule
        $candidatePath = $registeredModulePath

        if (-not [System.IO.Path]::IsPathRooted($candidatePath)) {
            $environmentDirectory = Split-Path -Path $script:CiEnvironmentFilePath -Parent
            $candidatePath = Join-Path -Path $environmentDirectory -ChildPath $candidatePath
        }

        $candidateFullPath = [System.IO.Path]::GetFullPath($candidatePath)
        if ($candidateFullPath.Equals($normalizedModulePath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $isRegistered = $true
            break
        }
    }

    if ($isRegistered) {
        return
    }

    $registeredModules += $normalizedModulePath

    $variablesValue = @()
    if ($environmentData.ContainsKey('Variables') -and
        $null -ne $environmentData.Variables -and
        $environmentData.Variables -isnot [System.Management.Automation.Internal.AutomationNull]) {
        if ($environmentData.Variables -is [System.Collections.IEnumerable] -and
            $environmentData.Variables -isnot [string]) {
            $variablesValue = @($environmentData.Variables)
        } else {
            $variablesValue = @($environmentData.Variables)
        }
    }

    Save-CiEnvironmentFile -Path $script:CiEnvironmentFilePath -Modules $registeredModules -Variables $variablesValue
}
