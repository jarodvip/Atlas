[CmdletBinding(DefaultParameterSetName = 'File')]
param(
    # Saved Markdown responses, one per official page: the Windows 11 page (25H2/26H2)
    # and the consolidated page (22H2 and older). Both are required, because a catalog
    # that names a supported family as supported while carrying none of its rows would
    # silently disable that family's offline checks. Use -Refresh to fetch both live.
    [Parameter(Mandatory, ParameterSetName = 'File')][string]$MarkdownPath,
    [Parameter(Mandatory, ParameterSetName = 'File')][string]$ConsolidatedMarkdownPath,
    [Parameter(ParameterSetName = 'Refresh')][switch]$Refresh,
    [datetime]$AsOfDate = [datetime]::UtcNow.Date,
    [string]$OutputPath = (Join-Path $PSScriptRoot '../../playbook/Executables/AtlasModules/Scripts/Compatibility/windows-releases.json')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../playbook/Executables/AtlasModules/Scripts/Compatibility/Windows-Release.ps1')
. (Join-Path $PSScriptRoot 'AtlasCatalogJson.ps1')

$families = @(Get-AtlasWindowsReleaseFamily)
$pages = @(Get-AtlasWindowsReleaseFamily | Select-Object -ExpandProperty Page -Unique)
# The two document URLs, taken from the family table so a page move is one edit.
$windows11Page = @($pages | Where-Object { $_ -like '*windows11-release-information' })[0]
$consolidatedPage = @($pages | Where-Object { $_ -notlike '*windows11-release-information' })[0]

$pageText = [ordered]@{}
if ($Refresh) {
    foreach ($page in $pages) {
        $pageText[$page] = Get-AtlasWindowsReleaseMarkdown -Page ([uri]$page)
    }
}
else {
    $pageText[$windows11Page] = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $MarkdownPath).Path)
    $pageText[$consolidatedPage] = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ConsolidatedMarkdownPath).Path)
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
        if (-not $commit -or -not $updated) { throw "Official source metadata is missing on $page; review the source format." }
        $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($markdown)))).Replace('-', '')
        foreach ($family in @($families | Where-Object Page -eq $page)) {
            try {
                $releaseRows += @(ConvertFrom-AtlasWindowsReleaseMarkdown -Markdown $markdown -AsOfDate $AsOfDate -Build $family.Build)
            }
            catch {
                # A family whose only rows are future-dated has no published release at
                # this cutoff (ConvertFrom-AtlasWindowsReleaseMarkdown throws). Record no
                # rows for it rather than abort the whole page; a missing section or a
                # malformed table is still fatal, because it means the format changed.
                if ([string]$_.Exception.Message -like 'No published *') { continue }
                throw
            }
        }
        $sources += [ordered]@{ url = $page; commit = $commit; sha256 = $hash; updatedAt = $updated }
    }
}
finally { $sha.Dispose() }
if (@($releaseRows).Count -eq 0) { throw 'No published releases were read from the supplied sources.' }

$catalog = [ordered]@{
    schemaVersion = 3
    product = 'Windows'
    # Every supported family is declared; a family with no published row at this cutoff
    # simply has none of its versions in `releases`, which the NoRefresh check treats as
    # "older than an unknown newest", never as evidence against the build.
    supportedReleases = @(foreach ($family in $families) { [ordered]@{ release = $family.Release; build = $family.Build } })
    sources = @($sources)
    asOfDate = $AsOfDate.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    releases = @($releaseRows | Sort-Object { [version]$_.version })
}
$text = (ConvertTo-AtlasCanonicalJson -InputObject $catalog).Replace("`r`n", "`n") + "`n"
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), $text, [Text.UTF8Encoding]::new($false))
Write-Output "Wrote $(@($releaseRows).Count) published versions for builds $(($families | ForEach-Object { $_.Build }) -join ', '). Review the catalog diff before publishing."
