# CI PowerShell Toolkit

This repository contains a small PowerShell toolkit for CI bootstrap and reusable helpers.

## Structure

- `install-ci-profile.ps1` - bootstrap script.
- `install-ci-profile.psd1` - bootstrap config.
- `assets/profile.ps1` - profile template copied to `$PROFILE`.
- `assets/agent.psd1` - optional variables source for final `Set-CiVar` pass.
- `assets/CiUtils` - reusable module with CI helpers.

## Bootstrap

Run:

```powershell
./install-ci-profile.ps1
```

What it does:

1. Reads `install-ci-profile.psd1`.
2. Copies `Paths.Profile` (from `Paths.Root`) to `$PROFILE`.
3. Imports modules from `Paths.Modules` (`.psm1` only).
4. Prepends module import lines (absolute paths) to `$PROFILE`.
5. Dot-sources `$PROFILE`.
6. If `Paths.Agent` exists, reads variables and applies them via `Set-CiVar`.

## CiUtils commands

- `Add-CiModule -Path <module.psm1>`
  - Imports module if not loaded.
  - Persists module path to environment file near `$PROFILE`.

- `Set-CiVar -Name <NAME> -Value <VALUE>`
  - Sets `Env:<NAME>`.
  - Persists variable in environment file near `$PROFILE`.

- `Test-CiEnvironment -Commands @('pwsh','git',...)`
  - Validates required commands are available.
  - Throws if any command is missing.

## Environment file

`CiUtils` uses `environment.psd1` (name from `assets/CiUtils/CiUtils.psd1`, key `EnvironmentFile`) located next to `$PROFILE`.

Default shape:

```powershell
@{
    Modules = @(
    )
    Variables = @(
    )
}
```

On module import, `CiUtils`:

1. Ensures the environment file exists.
2. Restores variables from `Variables`.
3. Restores modules from `Modules`.
