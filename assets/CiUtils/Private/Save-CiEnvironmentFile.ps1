function ConvertTo-CiPsd1Literal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Value,

        [Parameter()]
        [int]$IndentLevel = 0
    )

    $indent = ' ' * ($IndentLevel * 4)

    if ($null -eq $Value) {
        return "$indent`$null"
    }

    if ($Value -is [string]) {
        $escaped = $Value.Replace("'", "''")
        return "$indent'$escaped'"
    }

    if ($Value -is [bool]) {
        if ($Value) {
            return "$indent`$true"
        }

        return "$indent`$false"
    }

    if ($Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64] -or
        $Value -is [single] -or
        $Value -is [double] -or
        $Value -is [decimal]) {
        return "$indent$Value"
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $lines = @()
        $lines += "$indent@{"

        foreach ($key in $Value.Keys) {
            $keyLiteral = ConvertTo-CiPsd1Literal -Value ([string]$key)
            $valueLiteral = ConvertTo-CiPsd1Literal -Value $Value[$key] -IndentLevel ($IndentLevel + 1)
            $valueLiteralTrimmed = $valueLiteral.TrimStart()
            $lines += (' ' * (($IndentLevel + 1) * 4)) + "$keyLiteral = $valueLiteralTrimmed"
        }

        $lines += "$indent}"
        return ($lines -join [Environment]::NewLine)
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $lines = @()
        $lines += "$indent@("

        foreach ($item in $Value) {
            $lines += ConvertTo-CiPsd1Literal -Value $item -IndentLevel ($IndentLevel + 1)
        }

        $lines += "$indent)"
        return ($lines -join [Environment]::NewLine)
    }

    $fallback = $Value.ToString().Replace("'", "''")
    return "$indent'$fallback'"
}

function Save-CiEnvironmentFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [System.Collections.IEnumerable]$Modules,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Variables
    )

    $modulesList = @($Modules)
    $variablesValue = @()
    if ($null -ne $Variables) {
        $variablesValue = @($Variables)
    }

    $modulesLiteral = ConvertTo-CiPsd1Literal -Value $modulesList
    $variablesLiteral = ConvertTo-CiPsd1Literal -Value $variablesValue

    $content = @(
        '@{'
        "    Modules = $modulesLiteral"
        "    Variables = $variablesLiteral"
        '}'
        ''
    ) -join [Environment]::NewLine

    Set-Content -LiteralPath $Path -Value $content -Encoding UTF8NoBOM
}
