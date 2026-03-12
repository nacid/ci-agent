#!/usr/bin/env pwsh
[CmdletBinding()]
param()

$manifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'install-ci-profile.psd1'
$config = Import-PowerShellDataFile -Path $manifestPath

$rootPath = Join-Path -Path $PSScriptRoot -ChildPath $config.Paths.Root
$sourceProfilePath = Join-Path -Path $rootPath -ChildPath $config.Paths.Profile

if (-not (Test-Path -Path $sourceProfilePath -PathType Leaf)) {
    throw "Profile script not found: $sourceProfilePath"
}

$targetProfilePath = Join-Path -Path $HOME -ChildPath 'profile.ps1'
$targetProfileDirectory = Split-Path -Path $targetProfilePath -Parent
if (-not (Test-Path -Path $targetProfileDirectory -PathType Container)) {
    New-Item -Path $targetProfileDirectory -ItemType Directory -Force | Out-Null
}

Copy-Item -Path $sourceProfilePath -Destination $targetProfilePath -Force

$profileLines = @(Get-Content -Path $targetProfilePath)
$moduleImportLines = @()

foreach ($modulePath in $config.Paths.Modules) {
    $resolvedModulePath = Join-Path -Path $rootPath -ChildPath $modulePath

    $psm1Path = $null
    if (Test-Path -Path $resolvedModulePath -PathType Container) {
        $moduleName = Split-Path -Path $resolvedModulePath -Leaf
        $psm1Path = Join-Path -Path $resolvedModulePath -ChildPath "$moduleName.psm1"
    } elseif ([System.IO.Path]::GetExtension($resolvedModulePath) -ieq '.psm1') {
        $psm1Path = $resolvedModulePath
    } else {
        $psm1Path = "$resolvedModulePath.psm1"
    }

    if (-not (Test-Path -Path $psm1Path -PathType Leaf)) {
        throw "Module psm1 not found: $psm1Path"
    }

    $absolutePsm1Path = [System.IO.Path]::GetFullPath($psm1Path)
    $escapedAbsolutePsm1Path = $absolutePsm1Path.Replace("'", "''")
    $profileImportLine = "Import-Module -Name '$escapedAbsolutePsm1Path' -Force -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction Stop"

    if ($profileLines -notcontains $profileImportLine -and $moduleImportLines -notcontains $profileImportLine) {
        $moduleImportLines += $profileImportLine
    }

    Import-Module -Name $psm1Path -Force -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction Stop
}

if ($moduleImportLines.Count -gt 0) {
    $updatedProfileLines = @($moduleImportLines + $profileLines)
    Set-Content -Path $targetProfilePath -Value $updatedProfileLines -Encoding UTF8NoBOM
}

. $targetProfilePath

$agentPath = $null
if ($config.Paths.ContainsKey('Agent') -and -not [string]::IsNullOrWhiteSpace([string]$config.Paths.Agent)) {
    $agentPath = Join-Path -Path $rootPath -ChildPath $config.Paths.Agent
}

if ($agentPath -and (Test-Path -Path $agentPath -PathType Leaf)) {
    $agentData = Import-PowerShellDataFile -Path $agentPath
    $agentVariables = @()

    if ($agentData -is [System.Collections.IDictionary]) {
        if ($agentData.Contains('Variables')) {
            $agentVariables = @($agentData['Variables'])
        } else {
            foreach ($key in $agentData.Keys) {
                $agentVariables += @{
                    Name  = [string]$key
                    Value = $agentData[$key]
                }
            }
        }
    } elseif ($agentData -is [System.Collections.IEnumerable] -and $agentData -isnot [string]) {
        $agentVariables = @($agentData)
    }

    foreach ($entry in $agentVariables) {
        if ($null -eq $entry) {
            continue
        }

        $name = $null
        $value = $null

        if ($entry -is [System.Collections.IDictionary]) {
            if ($entry.Contains('Name')) {
                $name = [string]$entry['Name']
            } elseif ($entry.Keys.Count -eq 1) {
                $singleKey = @($entry.Keys)[0]
                $name = [string]$singleKey
                $value = $entry[$name]
            }

            if ($null -eq $value -and $entry.Contains('Value')) {
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

        Set-CiVar -Name $name -Value ([string]$value)
    }
}

$ArtifactsDir = Join-Path $HOME 'Artifacts'

if (Test-Path $ArtifactsDir) {
    Remove-Item $ArtifactsDir -Recurse -Force
}

$ArtifactsTarget = Join-Path $env:CI_ARTIFACTS_SPACE $env:CI_WORKFLOW_NAME
$ArtifactsTarget = Join-Path $ArtifactsTarget $env:CI_WORKFLOW_NAME

if (-not (Test-Path $ArtifactsTarget)) {
    New-Item -ItemType Directory -Path $ArtifactsTarget -Force | Out-Null
}

New-Item -ItemType SymbolicLink -Path $ArtifactsDir -Target $ArtifactsTarget | Out-Null

$WoodpeckerLogPath = Join-Path $ArtifactsDir '.woodpecker-current.log'
if (Test-Path $WoodpeckerLogPath) { 
	Remove-Item $WoodpeckerLogPath -Force 
}
