function Initialize-CiEnvironmentFile {
    [CmdletBinding()]
    param()

    $manifestPath = Join-Path -Path $script:CiUtilsRoot -ChildPath 'CiUtils.psd1'
    $environmentFileName = 'environment.psd1'

    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        $settings = Import-PowerShellDataFile -Path $manifestPath
        if ($settings.EnvironmentFile -and -not [string]::IsNullOrWhiteSpace($settings.EnvironmentFile)) {
            $environmentFileName = $settings.EnvironmentFile
        }
    }

    $profilePath = Join-Path -Path $HOME -ChildPath 'profile.ps1'
    $profileDirectory = Split-Path -Path $profilePath -Parent
    if (-not (Test-Path -LiteralPath $profileDirectory -PathType Container)) {
        New-Item -Path $profileDirectory -ItemType Directory -Force | Out-Null
    }

    $environmentFilePath = Join-Path -Path $profileDirectory -ChildPath $environmentFileName
    $script:CiEnvironmentFilePath = $environmentFilePath

    if (Test-Path -LiteralPath $environmentFilePath -PathType Leaf) {
        return
    }

    @'
@{
    Modules = @(
    )
    Variables = @(
    )
}
'@ | Set-Content -LiteralPath $environmentFilePath -Encoding UTF8NoBOM
}
