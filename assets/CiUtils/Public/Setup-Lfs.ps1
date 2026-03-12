function Setup-Lfs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$RepoId,

        [Parameter(Position = 1)]
        [string]$Include,

        [Parameter(Position = 2)]
        [string]$Exclude
    )

    function Invoke-Git {
        param(
            [Parameter(Mandatory)]
            [string[]]$Args,

            [switch]$AllowFailure
        )

        & git @Args
        $exitCode = $LASTEXITCODE

        if (-not $AllowFailure -and $exitCode -ne 0) {
            $joined = $Args -join ' '
            throw "git $joined failed (exit=$exitCode)"
        }

        return $exitCode
    }

    if ([string]::IsNullOrWhiteSpace($RepoId)) {
        Write-Warning 'warning: RepoId is empty; skipping lfs setup'
        return
    }

    $lfsSpace = $env:CI_LFS_SPACE
    if ([string]::IsNullOrWhiteSpace($lfsSpace)) {
        Write-Warning 'warning: CI_LFS_SPACE is empty; skipping lfs setup'
        return
    }

    $gitUser = $env:GIT_USERNAME
    $gitPass = $env:GIT_PASSWORD
    if ([string]::IsNullOrWhiteSpace($gitUser)) {
        throw 'GIT_USERNAME is empty'
    }
    if ([string]::IsNullOrWhiteSpace($gitPass)) {
        throw 'GIT_PASSWORD is empty'
    }

    $repoRoot = (& git rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
        throw "git rev-parse --show-toplevel failed (exit=$LASTEXITCODE)"
    }

    $gitDir = (& git rev-parse --git-dir).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitDir)) {
        throw "git rev-parse --git-dir failed (exit=$LASTEXITCODE)"
    }

    if (-not [System.IO.Path]::IsPathRooted($gitDir)) {
        $gitDir = Join-Path -Path $repoRoot -ChildPath $gitDir
    }
    $gitDir = (Resolve-Path -LiteralPath $gitDir -ErrorAction Stop).Path

    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($RepoId)
        $hash = -join ($md5.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
    }
    finally {
        $md5.Dispose()
    }

    $storagePath = Join-Path -Path $lfsSpace.Trim() -ChildPath $hash
    New-Item -ItemType Directory -Path $storagePath -Force | Out-Null
    $storagePath = (Resolve-Path -LiteralPath $storagePath -ErrorAction Stop).Path

    $credFile = Join-Path -Path $gitDir -ChildPath 'ci-credentials'

    try {
        Write-Host "LFS repo id: $RepoId"
        Write-Host "LFS cache path: $storagePath"

        Invoke-Git -Args @('lfs', 'install', '--local')
        Invoke-Git -Args @('config', '--local', 'lfs.storage', $storagePath)

        if (-not [string]::IsNullOrWhiteSpace($Include)) {
            Invoke-Git -Args @('config', '--local', 'lfs.fetchinclude', $Include)
            Write-Host "LFS include: $Include"
        }

        if (-not [string]::IsNullOrWhiteSpace($Exclude)) {
            Invoke-Git -Args @('config', '--local', 'lfs.fetchexclude', $Exclude)
            Write-Host "LFS exclude: $Exclude"
        }

        # Disable inherited helpers like osxkeychain for this repo.
		Invoke-Git -Args @('config', '--local', '--unset-all', 'credential.helper') -AllowFailure

		& git config --local credential.helper ""
		if ($LASTEXITCODE -ne 0) {
			throw "git config --local credential.helper `"`" failed (exit=$LASTEXITCODE)"
		}

		Invoke-Git -Args @('config', '--local', '--add', 'credential.helper', "store --file=$credFile")
		Invoke-Git -Args @('config', '--local', 'credential.useHttpPath', 'true')

        $originUrl = (& git remote get-url origin).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($originUrl)) {
            throw "git remote get-url origin failed (exit=$LASTEXITCODE)"
        }

        $uri = [Uri]$originUrl
        $credentialPayload = @"
protocol=$($uri.Scheme)
host=$($uri.Host)
path=$($uri.AbsolutePath)
username=$gitUser
password=$gitPass

"@

        $credentialPayload | & git credential approve
        if ($LASTEXITCODE -ne 0) {
            throw "git credential approve failed (exit=$LASTEXITCODE)"
        }

        Write-Host "Git credential helpers:"
        Invoke-Git -Args @('config', '--show-origin', '--get-all', 'credential.helper') -AllowFailure | Out-Null

        Write-Host "Running git lfs pull..."
        if ([string]::IsNullOrWhiteSpace($Include) -and [string]::IsNullOrWhiteSpace($Exclude)) {
            Invoke-Git -Args @('lfs', 'pull')
        }
        else {
            $pullArgs = @('lfs', 'pull')

            if (-not [string]::IsNullOrWhiteSpace($Include)) {
                $pullArgs += "--include=$Include"
            }

            if (-not [string]::IsNullOrWhiteSpace($Exclude)) {
                $pullArgs += "--exclude=$Exclude"
            }

            Invoke-Git -Args $pullArgs
        }

        Write-Host 'LFS setup completed successfully.'
    }
    finally {
        if (Test-Path -LiteralPath $credFile) {
            Remove-Item -LiteralPath $credFile -Force -ErrorAction SilentlyContinue
        }

        # Remove repo-local credential helper configuration so nothing persists unexpectedly.
        & git config --local --unset-all credential.helper 2>$null
        & git config --local --unset credential.useHttpPath 2>$null
    }
}