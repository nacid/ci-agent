function Import-CiEnvironmentVariables {
    [CmdletBinding()]
    param()

    if (-not $script:CiEnvironmentFilePath -or -not (Test-Path -LiteralPath $script:CiEnvironmentFilePath -PathType Leaf)) {
        return
    }

    $environmentData = Import-PowerShellDataFile -Path $script:CiEnvironmentFilePath
    if (-not $environmentData.ContainsKey('Variables') -or -not $environmentData.Variables) {
        return
    }

    $variableEntries = @($environmentData.Variables)
    foreach ($entry in $variableEntries) {
        if ($null -eq $entry) {
            continue
        }

        $name = $null
        $value = $null

        if ($entry -is [System.Collections.IDictionary]) {
            if ($entry.Contains('Name')) {
                $name = [string]$entry['Name']
            }
            if ($entry.Contains('Value')) {
                $value = $entry['Value']
            }
        } else {
            $nameProperty = $entry.PSObject.Properties['Name']
            $valueProperty = $entry.PSObject.Properties['Value']

            if ($nameProperty) {
                $name = [string]$nameProperty.Value
            }
            if ($valueProperty) {
                $value = $valueProperty.Value
            }
        }

        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $normalizedName = $name.Trim()
        Set-Item -Path ("Env:{0}" -f $normalizedName) -Value $value
    }
}
