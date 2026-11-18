# Whether a Windows build is a public release. This says nothing about whether the
# installation or media is genuine. Dot-sourcing only defines functions; the network
# is used only when the bundled catalog cannot decide.
#
# Two official pages are read, because neither lists the other's releases:
# - Windows 11 release information: 25H2 (26200) and 26H2 (26300).
# - The consolidated Windows release information: 22H2 (19045) and older.
# Microsoft keeps both under learn.microsoft.com/release-health, as Markdown.

# Supported build families: OS build -> release name, and the page whose table lists
# that release. Must stay in step with the app's BUILD_FAMILIES and the bundled
# catalog's supportedReleases.
function Get-AtlasWindowsReleaseFamily {
    return @(
        [pscustomobject]@{
            Build    = 19045
            Release  = '22H2'
            Page     = 'https://learn.microsoft.com/en-us/windows/release-health/release-information'
        }
        [pscustomobject]@{
            Build    = 26200
            Release  = '25H2'
            Page     = 'https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information'
        }
        [pscustomobject]@{
            Build    = 26300
            Release  = '26H2'
            Page     = 'https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information'
        }
    )
}

function Get-AtlasWindowsReleaseFamilyForBuild {
    param([Parameter(Mandatory = $true)][int]$Build)
    return @(Get-AtlasWindowsReleaseFamily | Where-Object Build -eq $Build | Select-Object -First 1)
}

function ConvertFrom-AtlasWindowsReleaseMarkdown {
    <#
    .SYNOPSIS
        Reads the General Availability rows of one supported release from its table.

    .DESCRIPTION
        The section heading is `Version <Release> (OS build <Build>)`. Windows 11 pages
        group every 24H2-or-newer release, and the consolidated page groups 22H2 and
        older. The table ends at the next `Version ...` heading, so a row never leaks
        between sections, and only a completely published row (available on or before
        `AsOfDate`) is returned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Markdown,
        [datetime]$AsOfDate = [datetime]::UtcNow.Date,
        [ValidateSet(19045, 26200, 26300)][int]$Build = 26200
    )
    $family = Get-AtlasWindowsReleaseFamilyForBuild -Build $Build
    if ($null -eq $family) { throw "Build $Build is not a supported Windows release family." }
    $releaseName = [string]$family.Release
    $Markdown = $Markdown.Replace("`r`n", "`n")
    $headingText = [regex]::Escape("Version $releaseName (OS build $Build)")
    $heading = [regex]::Match($Markdown, "(?m)^\s*(?:\*\*|#{1,6}\s*)?$headingText(?:\*\*)?\s*$")
    if (-not $heading.Success) { throw "The official $releaseName release section is missing." }
    $section = $Markdown.Substring($heading.Index + $heading.Length)
    $nextHeading = [regex]::Match($section, '(?m)^\s*(?:\*\*|#{1,6}\s*)?Version [^\r\n]+$')
    if ($nextHeading.Success) { $section = $section.Substring(0, $nextHeading.Index) }
    if ($section -notmatch '\|\s*Servicing option\s*\|\s*Update type\s*\|\s*Availability date\s*\|\s*Build\s*\|\s*KB article\s*\|') {
        throw 'The official release table has an unexpected format.'
    }
    $seen = @{}
    $rows = foreach ($line in ($section -split '\r?\n')) {
        if ($line -notmatch '^\|\s*General Availability Channel\s*\|') { continue }
        $row = [regex]::Match($line, "^\|\s*General Availability Channel\s*\|\s*([^|]*)\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*($Build\.\d+)\s*\|\s*([^|]*)\|\s*$")
        if (-not $row.Success) { throw 'A General Availability release row is malformed.' }
        $date = [datetime]::ParseExact($row.Groups[2].Value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        $version = [version]("10.0." + $row.Groups[3].Value)
        if ($seen.ContainsKey($version.ToString())) { throw 'Duplicate release versions need review.' }
        $seen[$version.ToString()] = $true
        if ($date.Date -gt $AsOfDate.Date) { continue }
        $kbText = $row.Groups[4].Value.Trim()
        $kb = $null
        if ($kbText) {
            $kbMatch = [regex]::Match($kbText, '^\[(KB\d+)\]\(https://support\.microsoft\.com/(?:help/\d+|[^\s)]+)\)$')
            if (-not $kbMatch.Success) { throw 'The release KB reference has an unexpected format.' }
            $kb = $kbMatch.Groups[1].Value
        }
        [pscustomobject][ordered]@{
            version = $version.ToString()
            availableDate = $date.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
            updateType = $row.Groups[1].Value.Trim()
            kb = $kb
        }
    }
    if (-not @($rows).Count) { throw "No published $releaseName General Availability releases were found." }
    @($rows | Sort-Object { [version]$_.version })
}

# Tests mock this to serve fixed responses.
function New-AtlasWindowsReleaseRequest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][uri]$Uri)
    [Net.HttpWebRequest]::Create($Uri)
}

function Get-AtlasWindowsReleaseMarkdown {
    <#
    .SYNOPSIS
        Reads the Markdown form of one official release page.

    .DESCRIPTION
        Stable builds pass -Page for each page they must consult. The Windows 11 page
        carries 25H2 and 26H2; the consolidated page carries 22H2 and older, so both
        are read when every supported release must be refreshed. Only learn.microsoft.com
        over HTTPS is accepted, redirects stay on that origin, and the body is limited.
    #>
    [CmdletBinding()]
    param(
        [uri]$Page = [uri]'https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information'
    )
    $uri = $Page
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $timeoutMs = 15000
    $limit = 1MB
    for ($redirect = 0; $redirect -le 3; $redirect++) {
        if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'learn.microsoft.com' -or $uri.Port -ne 443 -or $uri.UserInfo) {
            throw 'Release information redirected outside its official HTTPS origin.'
        }
        $remaining = $timeoutMs - [int]$clock.ElapsedMilliseconds
        if ($remaining -le 0) { throw 'Release information request timed out.' }
        $request = New-AtlasWindowsReleaseRequest -Uri $uri
        $request.AllowAutoRedirect = $false
        $request.Timeout = $remaining
        $request.ReadWriteTimeout = $remaining
        $request.Accept = 'text/markdown'
        $request.UserAgent = 'Atlas-WindowsReleasePolicy/1.0'
        $request.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate
        $response = $null
        try {
            $response = $request.GetResponse()
            $status = [int]$response.StatusCode
            if ($status -in @(301, 302, 303, 307, 308)) {
                $uri = [uri]::new($uri, [string]$response.Headers['Location'])
                continue
            }
            if ($status -ne 200 -or $response.ContentType -notmatch '^text/markdown(?:;|$)' -or $response.ContentLength -gt $limit) {
                throw 'Release information response was not Markdown within the size limit.'
            }
            $stream = $response.GetResponseStream()
            $buffer = New-Object byte[] 8192
            $body = New-Object IO.MemoryStream
            try {
                while ($true) {
                    $remaining = $timeoutMs - [int]$clock.ElapsedMilliseconds
                    if ($remaining -le 0) { throw 'Release information request timed out.' }
                    if ($stream.CanTimeout) { $stream.ReadTimeout = $remaining }
                    $count = $stream.Read($buffer, 0, $buffer.Length)
                    if ($count -eq 0) { break }
                    if ($body.Length + $count -gt $limit) { throw 'Release information exceeded the size limit.' }
                    $body.Write($buffer, 0, $count)
                }
                return [Text.UTF8Encoding]::new($false, $true).GetString($body.ToArray())
            } finally { $body.Dispose(); $stream.Dispose() }
        } finally { if ($null -ne $response) { $response.Dispose() }; $request.Abort() }
    }
    throw 'Release information exceeded the redirect limit.'
}

function Get-AtlasWindowsReleaseStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][version]$Version,
        [AllowEmptyString()][string]$BuildLabEx = '',
        # Decide from the bundled catalog alone, never Microsoft's live page.
        [switch]$NoRefresh
    )
    if ($BuildLabEx -match '(?i)(?:^|[._-])prerelease(?:[._-]|$)') { return 'Preview' }
    $family = Get-AtlasWindowsReleaseFamilyForBuild -Build $Version.Build
    if ($Version.Major -ne 10 -or $Version.Minor -ne 0 -or $null -eq $family -or $Version.Revision -lt 1) { return 'Unknown' }
    try {
        $catalog = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'windows-releases.json') -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($catalog.schemaVersion -eq 3 -and @($catalog.supportedReleases.build) -contains $Version.Build) {
            foreach ($release in $catalog.releases) {
                if ($release.version -eq $Version.ToString() -and [datetime]::ParseExact($release.availableDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture).Date -le [datetime]::UtcNow.Date) {
                    return 'Released'
                }
            }
            if ($NoRefresh) {
                # Without the live page, only a revision newer than every listed one
                # of its build is taken as an update the catalog predates. Older
                # unlisted revisions, such as pre-release flights, stay unknown.
                $newest = @($catalog.releases | ForEach-Object { [version]$_.version } | Where-Object { $_.Build -eq $Version.Build } | Sort-Object) | Select-Object -Last 1
                if ($null -ne $newest -and $Version -gt $newest) { return 'Released' }
            }
        }
    } catch { Write-Verbose "The bundled Windows release catalog could not be read: $_" }
    if ($NoRefresh) { return 'Unknown' }
    try {
        $cached = Get-Variable -Name AtlasWindowsReleasedVersions -Scope Script -ErrorAction SilentlyContinue
        if ($null -eq $cached) {
            # One read per official page: the Windows 11 page for 25H2/26H2 and the
            # consolidated page for 22H2. A page that fails to load contributes no
            # versions for its builds rather than failing the other page's lookup.
            $versions = New-Object 'Collections.Generic.List[string]'
            $pages = @(Get-AtlasWindowsReleaseFamily | Select-Object -ExpandProperty Page -Unique)
            foreach ($page in $pages) {
                try {
                    $markdown = Get-AtlasWindowsReleaseMarkdown -Page ([uri]$page)
                    foreach ($buildFamily in @(Get-AtlasWindowsReleaseFamily | Where-Object Page -eq $page)) {
                        foreach ($release in @(ConvertFrom-AtlasWindowsReleaseMarkdown -Markdown $markdown -Build $buildFamily.Build)) {
                            $versions.Add([string]$release.version)
                        }
                    }
                }
                catch { Write-Verbose "Windows release information is unavailable for '$page': $_" }
            }
            if ($versions.Count -eq 0) { return 'Unknown' }
            $script:AtlasWindowsReleasedVersions = @($versions)
        }
        if ($script:AtlasWindowsReleasedVersions -contains $Version.ToString()) { return 'Released' }
        # Read, but left out: most often a Release Preview build, or an update the
        # page doesn't list yet.
        return 'Unlisted'
    } catch { Write-Verbose "Windows release information is unavailable: $_" }
    # Neither missing enrollment indicators nor a failed lookup proves an Insider build.
    'Unknown'
}
