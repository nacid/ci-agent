function Import-CiEnvironmentModules {
    [CmdletBinding()]
    param()

    if (-not $script:CiEnvironmentFilePath -or -not (Test-Path -LiteralPath $script:CiEnvironmentFilePath -PathType Leaf)) {
        return
    }

    $environmentData = Import-PowerShellDataFile -Path $script:CiEnvironmentFilePath
    if (-not $environmentData.ContainsKey('Modules') -or -not $environmentData.Modules) {
        return
    }

    $environmentDirectory = Split-Path -Path $script:CiEnvironmentFilePath -Parent
    $moduleEntries = @($environmentData.Modules)

    foreach ($moduleEntry in $moduleEntries) {
        $modulePath = [string]$moduleEntry
        if ([string]::IsNullOrWhiteSpace($modulePath)) {
            continue
        }
        $modulePath = $modulePath.Trim()

        $candidatePath = $modulePath
        if (-not [System.IO.Path]::IsPathRooted($candidatePath)) {
            $candidatePath = Join-Path -Path $environmentDirectory -ChildPath $candidatePath
        }

        try {
            $fullModulePath = [System.IO.Path]::GetFullPath($candidatePath)
        } catch {
            continue
        }

        Add-CiModule -Path $fullModulePath
    }
}
