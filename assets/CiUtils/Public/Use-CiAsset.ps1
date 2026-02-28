function Use-CiAsset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Url
    )

    function Get-Md5Hex {
        param(
            [Parameter(Mandatory)]
            [string]$InputText
        )

        $md5 = [System.Security.Cryptography.MD5]::Create()
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
            $hash = $md5.ComputeHash($bytes)
            return -join ($hash | ForEach-Object { $_.ToString('x2') })
        } finally {
            $md5.Dispose()
        }
    }

    function Import-CiAssetModules {
        param(
            [Parameter(Mandatory)]
            [string]$Root
        )

        $rootPath = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
        $moduleFiles = Get-ChildItem -LiteralPath $rootPath -Filter '*.psm1' -File -Recurse | Sort-Object FullName

        foreach ($moduleFile in $moduleFiles) {
            Add-CiModule -Path $moduleFile.FullName
        }
    }

    $archivePath = $null
    $tmpTarPath = $null
    $targetDir = $null
    $hash = $null

    try {
        $assetsSpace = $env:CI_ASSETS_SPACE
        if ([string]::IsNullOrWhiteSpace($assetsSpace)) {
            Write-Warning 'warning: CI_ASSETS_SPACE is empty; skipping assets import'
            return
        }

        $pass = $env:CI_ASSETS_PASS
        if ([string]::IsNullOrWhiteSpace($Url) -or [string]::IsNullOrWhiteSpace($pass)) {
            Write-Warning 'warning: url or pass is empty; skipping assets import'
            return
        }

        $uri = [Uri]$Url
        $fileName = [System.IO.Path]::GetFileName($uri.AbsolutePath)

        if (-not $fileName.ToLowerInvariant().EndsWith('.tar.gpg')) {
            Write-Warning "warning: archive must be .tar.gpg, got '$fileName'; skipping"
            return
        }

        $hash = Get-Md5Hex -InputText ("$Url$pass")
        $targetDir = Join-Path -Path $assetsSpace -ChildPath $hash

        if (Test-Path -LiteralPath $targetDir -PathType Container) {
            Import-CiAssetModules -Root $targetDir
            Write-Host "HASH: $hash"
            return
        }

        New-Item -ItemType Directory -Path $assetsSpace -Force | Out-Null

        $archivePath = Join-Path -Path $assetsSpace -ChildPath $fileName
        Write-Host "DOWNLOADING: $Url"
        Invoke-WebRequest -Uri $Url -OutFile $archivePath -UseBasicParsing -ErrorAction Stop

        $baseName = $fileName.Substring(0, $fileName.Length - '.tar.gpg'.Length)
        $passHash = Get-Md5Hex -InputText ("$baseName$pass")

        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        $tmpTarPath = Join-Path -Path $assetsSpace -ChildPath ($baseName + '.tar')

        try {
            & gpg --batch --yes --passphrase $passHash -o $tmpTarPath -d $archivePath 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "gpg decrypt failed (exit=$LASTEXITCODE)"
            }

            & tar -xf $tmpTarPath -C $targetDir 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "tar extract failed (exit=$LASTEXITCODE)"
            }
        } catch {
            if (Test-Path -LiteralPath $targetDir -PathType Container) {
                Remove-Item -LiteralPath $targetDir -Recurse -Force -ErrorAction SilentlyContinue
            }

            throw
        } finally {
            if ($tmpTarPath -and (Test-Path -LiteralPath $tmpTarPath -PathType Leaf)) {
                Remove-Item -LiteralPath $tmpTarPath -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Warning "warning: $($_.Exception.Message)"
        return
    } finally {
        if ($archivePath -and (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
            Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
        }
    }

    try {
        Import-CiAssetModules -Root $targetDir
        Write-Host "HASH: $hash"
    } catch {
        Write-Warning "warning: import failed: $($_.Exception.Message)"
        return
    }
}
