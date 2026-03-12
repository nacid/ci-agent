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

    $gitUser = $env:GIT_USERNAME
    $gitPass = $env:GIT_PASSWORD
    if ([string]::IsNullOrWhiteSpace($gitUser) -or [string]::IsNullOrWhiteSpace($gitPass)) {
        throw 'GIT_USERNAME or GIT_PASSWORD is empty'
    }

    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($A)
        $hash = -join ($md5.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
    }
    finally {
        $md5.Dispose()
    }

    $storagePath = Join-Path -Path $lfsSpace.Trim() -ChildPath $hash
    New-Item -ItemType Directory -Path $storagePath -Force | Out-Null
    $storagePath = (Resolve-Path -LiteralPath $storagePath -ErrorAction Stop).Path

    $credFile = Join-Path -Path $PWD -ChildPath '.git/ci-credentials'

    try {
        & git lfs install --local
        if ($LASTEXITCODE -ne 0) {
            throw "git lfs install --local failed (exit=$LASTEXITCODE)"
        }

        & git config --local lfs.storage $storagePath
        if ($LASTEXITCODE -ne 0) {
            throw "git config lfs.storage failed (exit=$LASTEXITCODE)"
        }

        & git config --local credential.useHttpPath true
        if ($LASTEXITCODE -ne 0) {
            throw "git config credential.useHttpPath failed (exit=$LASTEXITCODE)"
        }

        & git config --local credential.helper "store --file=$credFile"
        if ($LASTEXITCODE -ne 0) {
            throw "git config credential.helper failed (exit=$LASTEXITCODE)"
        }

        $originUrl = (& git remote get-url origin).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($originUrl)) {
            throw "git remote get-url origin failed (exit=$LASTEXITCODE)"
        }

        $uri = [Uri]$originUrl
        $baseUrl = "{0}://{1}" -f $uri.Scheme, $uri.Host
        $path = $uri.AbsolutePath

        @"
protocol=$($uri.Scheme)
host=$($uri.Host)
path=$path
username=$gitUser
password=$gitPass

"@ | & git credential approve

        if ($LASTEXITCODE -ne 0) {
            throw "git credential approve failed (exit=$LASTEXITCODE)"
        }

        & git lfs pull
        if ($LASTEXITCODE -ne 0) {
            throw "git lfs pull failed (exit=$LASTEXITCODE)"
        }
    }
    finally {
        if (Test-Path -LiteralPath $credFile) {
            Remove-Item -LiteralPath $credFile -Force -ErrorAction SilentlyContinue
        }
    }
}