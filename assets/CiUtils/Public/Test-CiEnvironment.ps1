function Test-CiEnvironment {
    [CmdletBinding()]
    param(
        # Names of commands that must exist (e.g. git, dotnet, node, pwsh)
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Commands
    )

    $missing = @()

    foreach ($name in $Commands) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $commandName = $name.Trim()
        $cmd = Get-Command -Name $commandName -ErrorAction SilentlyContinue

        if (-not $cmd) {
            Write-Host "NOT FOUND: $commandName"
            $missing += $commandName
            continue
        }

        $version = $null

        # Try to get a meaningful version
        try {
            if ($cmd.CommandType -eq [System.Management.Automation.CommandTypes]::Application -and $cmd.Source) {
                $version = (Get-Item -LiteralPath $cmd.Source -ErrorAction Stop).VersionInfo.ProductVersion
            }
        } catch { }

        if (-not $version) {
            try { $version = (& $commandName --version 2>$null | Select-Object -First 1) } catch { }
        }
        if (-not $version) {
            try { $version = (& $commandName -Version 2>$null | Select-Object -First 1) } catch { }
        }
        if (-not $version) {
            try { $version = (& $commandName -v 2>$null | Select-Object -First 1) } catch { }
        }
        if (-not $version) {
            try {
                # As a fallback, show command type + resolved path
                $version = "{0} ({1})" -f $cmd.CommandType, ($cmd.Source ?? $cmd.Definition)
            } catch { }
        }

        Write-Host "OK: $commandName - $version"
    }

    if ($missing.Count -gt 0) {
        throw "Environment check failed. Missing commands: $($missing -join ', ')"
    }
}
