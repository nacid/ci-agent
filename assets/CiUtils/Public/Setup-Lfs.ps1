function Setup-Lfs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$A
    )

    if ([string]::IsNullOrWhiteSpace($A)) {
        Write-Warning 'warning: A is empty; skipping lfs setup'
        return
    }

    $lfsSpace = $env:CI_LFS_SPACE
    if ([string]::IsNullOrWhiteSpace($lfsSpace)) {
        Write-Warning 'warning: CI_LFS_SPACE is empty; skipping lfs setup'
        return
    }

    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($A)
        $hash = -join ($md5.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
    } finally {
        $md5.Dispose()
    }

    $storagePath = Join-Path -Path $lfsSpace.Trim() -ChildPath $hash
    New-Item -ItemType Directory -Path $storagePath -Force | Out-Null
    $storagePath = (Resolve-Path -LiteralPath $storagePath -ErrorAction Stop).Path

    & git lfs install --local
    if ($LASTEXITCODE -ne 0) {
        throw "git lfs install --local failed (exit=$LASTEXITCODE)"
    }

    & git config lfs.storage $storagePath
    if ($LASTEXITCODE -ne 0) {
        throw "git config lfs.storage failed (exit=$LASTEXITCODE)"
    }

    & git lfs pull
    if ($LASTEXITCODE -ne 0) {
        throw "git lfs pull failed (exit=$LASTEXITCODE)"
    }
}
