function Import-CiScripts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [string]$Filter = '*.ps1'
    )

    $rootPath = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
    $files = Get-ChildItem -LiteralPath $rootPath -Filter $Filter -File -Recurse | Sort-Object FullName

    $profilePath = $PROFILE
    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
        $profileDir = Split-Path -Path $profilePath -Parent
        if (-not (Test-Path -LiteralPath $profileDir -PathType Container)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    $profileLines = @(Get-Content -LiteralPath $profilePath -ErrorAction SilentlyContinue)

    foreach ($file in $files) {
        . $file.FullName

        $escapedPath = $file.FullName.Replace("'", "''")
        $importLine = ". '$escapedPath'"

        if ($profileLines -notcontains $importLine) {
            Add-Content -LiteralPath $profilePath -Value $importLine
            $profileLines += $importLine
        }
    }
}
