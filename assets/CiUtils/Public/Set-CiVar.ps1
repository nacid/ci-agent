function Set-CiVar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Warning '⚠️ warning'
        return
    }

    $normalizedName = $Name.Trim()
    Set-Item -Path ("Env:{0}" -f $normalizedName) -Value $Value

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

    $registeredVariables = @()
    if ($environmentData.ContainsKey('Variables') -and
        $null -ne $environmentData.Variables -and
        $environmentData.Variables -isnot [System.Management.Automation.Internal.AutomationNull]) {
        if ($environmentData.Variables -is [System.Collections.IEnumerable] -and
            $environmentData.Variables -isnot [string]) {
            $registeredVariables = @($environmentData.Variables)
        } else {
            $registeredVariables = @($environmentData.Variables)
        }
    }

    $updatedVariables = @()
    $isUpdated = $false
    foreach ($entry in $registeredVariables) {
        if ($entry -is [System.Collections.IDictionary]) {
            $entryName = [string]$entry['Name']
            if (-not [string]::IsNullOrWhiteSpace($entryName) -and
                $entryName.Equals($normalizedName, [System.StringComparison]::OrdinalIgnoreCase)) {
                $updatedVariables += @{
                    Name  = $normalizedName
                    Value = $Value
                }
                $isUpdated = $true
                continue
            }

            $updatedVariables += @{
                Name  = $entry['Name']
                Value = $entry['Value']
            }
            continue
        }

        $updatedVariables += $entry
    }

    if (-not $isUpdated) {
        $updatedVariables += @{
            Name  = $normalizedName
            Value = $Value
        }
    }

    Save-CiEnvironmentFile -Path $script:CiEnvironmentFilePath -Modules $registeredModules -Variables $updatedVariables
}
