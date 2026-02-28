$script:CiUtilsRoot = $PSScriptRoot
$script:CiEnvironmentFilePath = $null

$publicPath = Join-Path $PSScriptRoot 'Public'
$privatePath = Join-Path $PSScriptRoot 'Private'

if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter '*.ps1' -File | ForEach-Object {
        . $_.FullName
    }
}

if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter '*.ps1' -File | ForEach-Object {
        . $_.FullName
    }
}

if (Get-Command -Name Initialize-CiEnvironmentFile -CommandType Function -ErrorAction SilentlyContinue) {
    Initialize-CiEnvironmentFile
}

if (Get-Command -Name Import-CiEnvironmentVariables -CommandType Function -ErrorAction SilentlyContinue) {
    Import-CiEnvironmentVariables
}

if (Get-Command -Name Import-CiEnvironmentModules -CommandType Function -ErrorAction SilentlyContinue) {
    Import-CiEnvironmentModules
}

Export-ModuleMember -Function (
    Get-ChildItem -Path $publicPath -Filter '*.ps1' -File |
    Select-Object -ExpandProperty BaseName
)
