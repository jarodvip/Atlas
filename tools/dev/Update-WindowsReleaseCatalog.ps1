[CmdletBinding(DefaultParameterSetName = 'File')]
param(
    # Saved Markdown responses, one per official page. Either name the file for the
    # Windows 11 page (25H2/26H2) via -MarkdownPath and the consolidated page
    # (22H2 and older) via -ConsolidatedMarkdownPath, or fetch both with -Refresh.
    [Parameter(ParameterSetName = 'File')][string]$MarkdownPath,
    [Parameter(ParameterSetName = 'File')][string]$ConsolidatedMarkdownPath,
    [Parameter(ParameterSetName = 'Refresh')][switch]$Refresh,
    [datetime]$AsOfDate = [datetime]::UtcNow.Date,
    [string]$OutputPath = (Join-Path $PSScriptRoot '../../playbook/Executables/AtlasModules/Scripts/Compatibility/windows-releases.json')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../playbook/Executables/AtlasModules/Scripts/Compatibility/Windows-Release.ps1')

$families = @(Get-AtlasWindowsReleaseFamily)
$pages = @(Get-AtlasWindowsReleaseFamily | Select-Object -ExpandProperty Page -Unique)

$pageText = [ordered]@{}
if ($Refresh) {
    foreach ($page in $pages) {
        $pageText[$page] = Get-AtlasWindowsReleaseMarkdown -Page ([uri]$page)
    }
}
else {
    if (-not $MarkdownPath) { throw 'Pass -MarkdownPath (Windows 11 page) or -Refresh.' }
    $pageText['https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information'] =
        [IO.File]::ReadAllText((Resolve-Path -LiteralPath $MarkdownPath).Path)
    if ($ConsolidatedMarkdownPath) {
        $pageText['https://learn.microsoft.com/en-us/windows/release-health/release-information'] =
            [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ConsolidatedMarkdownPath).Path)
    }
}

$sources = @()
$releaseRows = @()
$sha = [Security.Cryptography.SHA256]::Create()
try {
    foreach ($page in $pages) {
        if (-not $pageText.Contains($page)) { continue }
        $markdown = [string]$pageText[$page]
        # Provenance comes from the page's own front matter.
        $commit = [regex]::Match($markdown, '(?m)^git_commit_id: ([0-9a-f]{40})\s*$').Groups[1].Value
        $updated = [regex]::Match($markdown, '(?m)^updated_at: ([^\r\n]+)').Groups[1].Value.Trim()
        if (-not $updated) { throw "Official source metadata is missing on $page; review the source format." }
        $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($markdown)))).Replace('-', '')
        $sources += [ordered]@{ url = $page; commit = $commit; sha256 = $hash; updatedAt = $updated }
        foreach ($family in @($families | Where-Object Page -eq $page)) {
            $releaseRows += @(ConvertFrom-AtlasWindowsReleaseMarkdown -Markdown $markdown -AsOfDate $AsOfDate -Build $family.Build)
        }
    }
}
finally { $sha.Dispose() }
if (@($releaseRows).Count -eq 0) { throw 'No published releases were read from the supplied sources.' }

$catalog = [ordered]@{
    schemaVersion = 3
    product = 'Windows'
    supportedReleases = @(foreach ($family in $families) { [ordered]@{ release = $family.Release; build = $family.Build } })
    sources = @($sources)
    asOfDate = $AsOfDate.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    releases = @($releaseRows | Sort-Object { [version]$_.version })
}
$text = ($catalog | ConvertTo-Json -Depth 5).Replace("`r`n", "`n") + "`n"
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), $text, [Text.UTF8Encoding]::new($false))
Write-Output "Wrote $(@($releaseRows).Count) published versions for builds $(($families | ForEach-Object { $_.Build }) -join ', '). Review the catalog diff before publishing."
