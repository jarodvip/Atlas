<#
.SYNOPSIS
    A deterministic, host-independent JSON writer for the committed Atlas catalogs.
.DESCRIPTION
    Windows PowerShell 5.1's ConvertTo-Json (JavaScriptSerializer) and PowerShell 7's
    (System.Text.Json) produce different bytes for the same object: 4- vs 2-space
    indent, a double vs single space after the colon, and a `'` escape for
    apostrophes under 5.1 only. The generators run under either host (maintainers use
    pwsh; the drift check shells out from a 5.1 test process), so a host-dependent
    serializer makes the committed file drift. This writer emits one fixed shape — a
    two-space indent, `": "` after a key, apostrophes and non-ASCII kept literal, UTF-8
    without BOM — so the same object always produces the same bytes on any host.
.EXAMPLE
    ConvertTo-AtlasCanonicalJson -InputObject $catalog
#>
function ConvertTo-AtlasCanonicalJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowNull()] $InputObject
    )

    $builder = New-Object System.Text.StringBuilder
    $null = Write-AtlasJsonValue -Builder $builder -Value $InputObject -Depth 0
    return $builder.ToString()
}

function Write-AtlasJsonValue {
    param(
        [Parameter(Mandatory = $true)][System.Text.StringBuilder]$Builder,
        [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()] $Value,
        [int]$Depth
    )

    if ($null -eq $Value) {
        $null = $Builder.Append('null')
        return
    }
    if ($Value -is [bool]) {
        $null = $Builder.Append($(if ($Value) { 'true' } else { 'false' }))
        return
    }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [int64] -or $Value -is [int16] -or
        $Value -is [uint32] -or $Value -is [uint64] -or $Value -is [uint16] -or $Value -is [byte]) {
        $null = $Builder.Append(([string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $Value)))
        return
    }
    if ($Value -is [string] -or $Value -is [char]) {
        $null = $Builder.Append((ConvertTo-AtlasJsonString -Text ([string]$Value)))
        return
    }

    # Ordered and plain dictionaries keep their key order; the generators build
    # [ordered] tables so the output matches the authored order.
    if ($Value -is [System.Collections.IDictionary]) {
        $keys = @($Value.Keys)
        if ($keys.Count -eq 0) {
            $null = $Builder.Append('{}')
            return
        }
        $indent = ' ' * (($Depth + 1) * 2)
        $closeIndent = ' ' * ($Depth * 2)
        $null = $Builder.Append("{`n")
        for ($index = 0; $index -lt $keys.Count; $index++) {
            $key = $keys[$index]
            $null = $Builder.Append($indent)
            $null = $Builder.Append((ConvertTo-AtlasJsonString -Text ([string]$key)))
            $null = $Builder.Append(': ')
            $null = Write-AtlasJsonValue -Builder $Builder -Value $Value[$key] -Depth ($Depth + 1)
            if ($index -lt $keys.Count - 1) { $null = $Builder.Append(',') }
            $null = $Builder.Append("`n")
        }
        $null = $Builder.Append($closeIndent).Append('}')
        return
    }

    # A PSObject whose base object is a PSCustomObject: emit its note/property members
    # in their existing order, exactly as ConvertTo-Json would, but in a fixed shape.
    if ($Value.PSObject.BaseObject -is [System.Management.Automation.PSCustomObject]) {
        $properties = @($Value.PSObject.Properties | Where-Object { $_.IsGettable })
        if ($properties.Count -eq 0) {
            $null = $Builder.Append('{}')
            return
        }
        $indent = ' ' * (($Depth + 1) * 2)
        $closeIndent = ' ' * ($Depth * 2)
        $null = $Builder.Append("{`n")
        for ($index = 0; $index -lt $properties.Count; $index++) {
            $property = $properties[$index]
            $null = $Builder.Append($indent)
            $null = $Builder.Append((ConvertTo-AtlasJsonString -Text ([string]$property.Name)))
            $null = $Builder.Append(': ')
            $null = Write-AtlasJsonValue -Builder $Builder -Value $property.Value -Depth ($Depth + 1)
            if ($index -lt $properties.Count - 1) { $null = $Builder.Append(',') }
            $null = $Builder.Append("`n")
        }
        $null = $Builder.Append($closeIndent).Append('}')
        return
    }

    # Arrays and other enumerables (note: a string was already handled above).
    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @($Value)
        if ($items.Count -eq 0) {
            $null = $Builder.Append('[]')
            return
        }
        $indent = ' ' * (($Depth + 1) * 2)
        $closeIndent = ' ' * ($Depth * 2)
        $null = $Builder.Append("[`n")
        for ($index = 0; $index -lt $items.Count; $index++) {
            $null = $Builder.Append($indent)
            $null = Write-AtlasJsonValue -Builder $Builder -Value $items[$index] -Depth ($Depth + 1)
            if ($index -lt $items.Count - 1) { $null = $Builder.Append(',') }
            $null = $Builder.Append("`n")
        }
        $null = $Builder.Append($closeIndent).Append(']')
        return
    }

    # Anything else (a decimal, double or DateTime the catalogs do not use) as its
    # invariant text, so it still emits something stable rather than throwing.
    $null = $Builder.Append((ConvertTo-AtlasJsonString -Text ([string]::Format(
                    [Globalization.CultureInfo]::InvariantCulture, '{0}', $Value))))
}

# Quotes and escapes a string the same way on every host: quote, backslash and control
# characters escaped; every other character (apostrophes, accented letters, CJK) kept
# literal because the file is written UTF-8 without BOM.
function ConvertTo-AtlasJsonString {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $builder = New-Object System.Text.StringBuilder
    $null = $builder.Append('"')
    foreach ($char in $Text.ToCharArray()) {
        $code = [int]$char
        if ($char -eq '"') { $null = $builder.Append('\"') }
        elseif ($char -eq '\') { $null = $builder.Append('\\') }
        elseif ($code -eq 8) { $null = $builder.Append('\b') }
        elseif ($code -eq 12) { $null = $builder.Append('\f') }
        elseif ($code -eq 10) { $null = $builder.Append('\n') }
        elseif ($code -eq 13) { $null = $builder.Append('\r') }
        elseif ($code -eq 9) { $null = $builder.Append('\t') }
        elseif ($code -lt 0x20) { $null = $builder.Append('\u').Append($code.ToString('x4', [Globalization.CultureInfo]::InvariantCulture)) }
        else { $null = $builder.Append($char) }
    }
    $null = $builder.Append('"')
    return $builder.ToString()
}
