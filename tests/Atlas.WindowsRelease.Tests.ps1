BeforeAll {
    . (Join-Path $PSScriptRoot 'AtlasTestHost.ps1')
    $script:policy = Join-Path $PSScriptRoot '../playbook/Executables/AtlasModules/Scripts/Compatibility/Windows-Release.ps1'
    . $policy
    function New-ReleaseMarkdownFixture {
        param([string]$Version = '26200.9999', [string]$Date = '2025-09-30')
        @"
---
git_commit_id: 0123456789012345678901234567890123456789
updated_at: 2026-08-28T08:57:00.0000000Z
---
**Version 26H2 (OS build 26300)**
| Servicing option | Update type | Availability date | Build | KB article |
| --- | --- | --- | --- | --- |
| General Availability Channel | 2026-09 D | 2026-09-29 | 26300.9550 | [KB5124010](https://support.microsoft.com/help/5124010) |
| General Availability Channel | | 2026-09-29 | 26300.9457 | |
| Release Preview Channel | | 2026-09-29 | 26300.9990 | |

**Version 25H2 (OS build 26200)**

| Servicing option | Update type | Availability date | Build | KB article |
| --- | --- | --- | --- | --- |
| General Availability Channel | 2025-09 D | $Date | $Version | [KB5120998](https://support.microsoft.com/help/5120998) |
| Release Preview Channel | 2025-09 D | 2025-09-30 | 26200.5551 | |

**Version 22H2 (OS build 19045)**
| Servicing option | Update type | Availability date | Build | KB article |
| --- | --- | --- | --- | --- |
| General Availability Channel | 2026-11 D | 2026-11-10 | 19045.7846 | [KB5126657](https://support.microsoft.com/help/5126657) |

**Version 26H1 (OS build 28000)**
| Servicing option | Update type | Availability date | Build | KB article |
| --- | --- | --- | --- | --- |
| General Availability Channel | 2025-09 D | 2025-09-30 | 26200.8888 | |
"@
    }
    # The consolidated page carries Windows 10 (and older); the Windows 11 page carries
    # 24H2 and newer. Neither lists the other, so the lookup reads one Markdown per page.
    function New-ConsolidatedMarkdownFixture {
        param([string]$Version = '19045.7846', [string]$Date = '2026-11-10')
        @"
---
git_commit_id: 9876543210987654321098765432109876543210
updated_at: 2026-11-14T05:21:00.0000000Z
---
**Version 22H2 (OS build 19045)**
| Servicing option | Update type | Availability date | Build | KB article |
| --- | --- | --- | --- | --- |
| General Availability Channel | 2026-11 D | $Date | $Version | [KB5126657](https://support.microsoft.com/help/5126657) |
| Release Preview Channel | 2026-11 D | 2026-11-10 | 19045.9990 | |

**Version 21H2 (OS build 19044)**
| Servicing option | Update type | Availability date | Build | KB article |
| --- | --- | --- | --- | --- |
| General Availability Channel | 2023-07 D | 2023-07-10 | 19044.3296 | |
"@
    }
    function New-ReleaseResponseFixture {
        param([string]$Text, [int]$Status = 200, [long]$Length = -1, [string]$Location = '')
        $response = [pscustomobject]@{
            StatusCode = $Status; ContentType = 'text/markdown; charset=utf-8'; ContentLength = $Length
            Headers = @{ Location = $Location }; Body = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($Text))
            Disposed = $false
        }
        $response | Add-Member ScriptMethod GetResponseStream { $this.Body }
        $response | Add-Member ScriptMethod Dispose { $this.Disposed = $true; $this.Body.Dispose() }
        $request = [pscustomobject]@{
            Response = $response; AllowAutoRedirect = $true; Timeout = 0; ReadWriteTimeout = 0
            Accept = ''; UserAgent = ''; AutomaticDecompression = 0; Aborted = $false
        }
        $request | Add-Member ScriptMethod GetResponse { $this.Response }
        $request | Add-Member ScriptMethod Abort { $this.Aborted = $true }
        $request
    }
}

Describe 'Windows release catalog parser' {
    It 'reads only published 26H2 rows from their matching section' {
        $rows = @(ConvertFrom-AtlasWindowsReleaseMarkdown (New-ReleaseMarkdownFixture) -Build 26300 -AsOfDate ([datetime]'2026-09-30'))
        $rows.version | Should -Be @('10.0.26300.9457','10.0.26300.9550')
        { ConvertFrom-AtlasWindowsReleaseMarkdown ((New-ReleaseMarkdownFixture).Replace('26300.9457','26200.9457')) -Build 26300 } | Should -Throw '*malformed*'
        { ConvertFrom-AtlasWindowsReleaseMarkdown (New-ReleaseMarkdownFixture) -Build 26300 -AsOfDate ([datetime]'2026-09-28') } | Should -Throw '*No published*'
    }
    It 'accepts a public optional preview update and excludes other channels and sections' {
        $rows = @(ConvertFrom-AtlasWindowsReleaseMarkdown (New-ReleaseMarkdownFixture) -AsOfDate ([datetime]'2026-09-07'))
        $rows.Count | Should -Be 1
        $rows[0].version | Should -Be '10.0.26200.9999'
        $rows[0].updateType | Should -Be '2025-09 D'
    }
    It 'handles both CRLF and LF without leaking rows from the next section' {
        $markdown = (New-ReleaseMarkdownFixture).Replace("`r`n", "`n")
        @(ConvertFrom-AtlasWindowsReleaseMarkdown $markdown).Count | Should -Be 1
        @(ConvertFrom-AtlasWindowsReleaseMarkdown ($markdown.Replace("`n", "`r`n"))).Count | Should -Be 1
    }
    It 'does not accept a future release merely because it is in the table' {
        { ConvertFrom-AtlasWindowsReleaseMarkdown (New-ReleaseMarkdownFixture -Date '2099-01-01') } | Should -Throw '*No published*'
    }
    It 'rejects malformed GA versions rather than silently omitting them' {
        { ConvertFrom-AtlasWindowsReleaseMarkdown (New-ReleaseMarkdownFixture -Version 'not-a-build') } | Should -Throw '*malformed*'
    }
    It 'requires the expected official section and table format' {
        { ConvertFrom-AtlasWindowsReleaseMarkdown ((New-ReleaseMarkdownFixture).Replace('Version 25H2', 'Version 99H9')) } | Should -Throw '*section is missing*'
        { ConvertFrom-AtlasWindowsReleaseMarkdown ((New-ReleaseMarkdownFixture).Replace('Servicing option', 'Unreviewed column')) } | Should -Throw '*unexpected format*'
    }
    It 'rejects off-origin KB references' {
        { ConvertFrom-AtlasWindowsReleaseMarkdown ((New-ReleaseMarkdownFixture).Replace('https://support.microsoft.com/', 'https://example.invalid/')) } | Should -Throw '*KB reference*'
    }
    It 'rejects duplicate versions that would make the release evidence ambiguous' {
        $markdown = New-ReleaseMarkdownFixture
        $row = @($markdown -split '\r?\n' | Where-Object { $_ -match '^\| General Availability Channel.*26200\.9999' })[0]
        { ConvertFrom-AtlasWindowsReleaseMarkdown ($markdown.Replace($row, "$row`n$row")) } | Should -Throw '*Duplicate release*'
    }
}

Describe 'Windows release eligibility' {
    BeforeAll {
        # A copy of the policy beside a fixed catalog, so a routine refresh of the bundled
        # one can't change these results. Listed: 26200.100, .200 and .300; 26300.100 and
        # .200; 19045.100.
        $fixtureRoot = Join-Path $TestDrive 'Compatibility'
        $null = New-Item -ItemType Directory -Path $fixtureRoot
        Copy-Item -LiteralPath $policy -Destination $fixtureRoot
        $catalog = [ordered]@{
            schemaVersion = 3
            supportedReleases = @(
                [ordered]@{ release = '22H2'; build = 19045 },
                [ordered]@{ release = '25H2'; build = 26200 },
                [ordered]@{ release = '26H2'; build = 26300 }
            )
            releases = @(foreach ($build in '19045.100', '26200.100', '26200.200', '26200.300', '26300.100', '26300.200') {
                [ordered]@{ version = "10.0.$build"; availableDate = '2025-10-14' }
            })
        }
        [IO.File]::WriteAllText((Join-Path $fixtureRoot 'windows-releases.json'), ($catalog | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
        . (Join-Path $fixtureRoot 'Windows-Release.ps1')
    }
    BeforeEach {
        Remove-Variable AtlasWindowsReleasedVersions -Scope Script -ErrorAction SilentlyContinue
        Mock Get-AtlasWindowsReleaseMarkdown { throw 'offline fixture' }
    }
    It 'recognizes a listed full version offline' {
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.100' | Should -Be 'Released'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.300' | Should -Be 'Released'
        Get-AtlasWindowsReleaseStatus -Version '10.0.19045.100' | Should -Be 'Released'
        Should -Invoke Get-AtlasWindowsReleaseMarkdown -Times 0 -Exactly
    }
    It 'recognizes the listed 26H2 versions offline and still rejects prerelease branches' {
        foreach ($version in '10.0.26300.100','10.0.26300.200') {
            Get-AtlasWindowsReleaseStatus -Version $version | Should -Be 'Released'
            Get-AtlasWindowsReleaseStatus -Version $version -BuildLabEx '26300.1.amd64fre.rs_prerelease' | Should -Be 'Preview'
        }
        Get-AtlasWindowsReleaseStatus -Version '10.0.26300.9999' | Should -Be 'Unknown'
        Should -Invoke Get-AtlasWindowsReleaseMarkdown -Times 2 -Exactly
    }
    It 'rejects an explicit prerelease branch marker without a network lookup' {
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.5551' -BuildLabEx '26200.1.amd64fre.rs_prerelease_flt.250101-0000' | Should -Be 'Preview'
        Should -Invoke Get-AtlasWindowsReleaseMarkdown -Times 0 -Exactly
    }
    It 'does not match an incidental substring as a prerelease branch token' {
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.200' -BuildLabEx '26100.1.amd64fre.notprerelease.240331-1435' | Should -Be 'Released'
    }
    It 'does not classify an unrecognized full version as Insider after a lookup failure' {
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.9999' -BuildLabEx '26100.1.amd64fre.ge_release.240331-1435' | Should -Be 'Unknown'
        Should -Invoke Get-AtlasWindowsReleaseMarkdown -Times 2 -Exactly
    }
    It 'does not query unrelated or incomplete build versions' {
        Get-AtlasWindowsReleaseStatus -Version '10.0.26100.9168' | Should -Be 'Unknown'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200' | Should -Be 'Unknown'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.0' | Should -Be 'Unknown'
        Should -Invoke Get-AtlasWindowsReleaseMarkdown -Times 0 -Exactly
    }
    It 'accepts newly published GA versions and reuses only the successful in-process result' {
        Mock Get-AtlasWindowsReleaseMarkdown { New-ReleaseMarkdownFixture }
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.9999' | Should -Be 'Released'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.9999' | Should -Be 'Released'
        Should -Invoke Get-AtlasWindowsReleaseMarkdown -Times 2 -Exactly
    }
    It 'tells a build the published list leaves out from a failed lookup' {
        Mock Get-AtlasWindowsReleaseMarkdown { New-ReleaseMarkdownFixture }
        # A Release Preview row and an unlisted newer revision alike.
        Get-AtlasWindowsReleaseStatus -Version '10.0.26300.9990' | Should -Be 'Unlisted'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26300.300' | Should -Be 'Unlisted'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26300.300' -NoRefresh | Should -Be 'Released'
        Should -Invoke Get-AtlasWindowsReleaseMarkdown -Times 2 -Exactly
    }
    It 'does not permanently cache a failed lookup' {
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.9999' | Should -Be 'Unknown'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.9999' | Should -Be 'Unknown'
        Should -Invoke Get-AtlasWindowsReleaseMarkdown -Times 4 -Exactly
    }
    It 'decides from the bundled catalog alone without a live lookup' {
        # Newer than every listed revision of its build: an update the catalog predates.
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.301' -NoRefresh | Should -Be 'Released'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26300.201' -NoRefresh | Should -Be 'Released'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.200' -NoRefresh | Should -Be 'Released'
        # Unlisted and older than the newest listed revision, as a pre-release flight is.
        Get-AtlasWindowsReleaseStatus -Version '10.0.26200.299' -NoRefresh | Should -Be 'Unknown'
        Get-AtlasWindowsReleaseStatus -Version '10.0.19045.100' -NoRefresh | Should -Be 'Released'
        Get-AtlasWindowsReleaseStatus -Version '10.0.19045.200' -NoRefresh | Should -Be 'Released'
        Get-AtlasWindowsReleaseStatus -Version '10.0.19045.99' -NoRefresh | Should -Be 'Unknown'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26100.9999' -NoRefresh | Should -Be 'Unknown'
        Get-AtlasWindowsReleaseStatus -Version '10.0.26300.201' -BuildLabEx '26300.1.amd64fre.rs_prerelease' -NoRefresh | Should -Be 'Preview'
        Should -Invoke Get-AtlasWindowsReleaseMarkdown -Times 0 -Exactly
    }
}

Describe 'Bundled Windows release catalog' {
    It 'is read by the policy script for each supported build' {
        $catalog = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $policy) 'windows-releases.json') -Raw | ConvertFrom-Json
        foreach ($build in 19045, 26200, 26300) {
            # Taken from the catalog so a routine refresh keeps this passing.
            $newest = @($catalog.releases | ForEach-Object { [version]$_.version } | Where-Object Build -eq $build | Sort-Object) | Select-Object -Last 1
            $newest | Should -Not -BeNullOrEmpty -Because "the catalog lists build $build"
            Get-AtlasWindowsReleaseStatus -Version $newest -NoRefresh | Should -Be 'Released'
        }
    }
}

Describe 'Limits on the official release transport' {
    BeforeEach {
        $script:requestFixture = New-ReleaseResponseFixture -Text (New-ReleaseMarkdownFixture)
        Mock New-AtlasWindowsReleaseRequest { $script:requestFixture }
    }
    It 'requests Markdown with automatic redirects disabled and a timeout' {
        Get-AtlasWindowsReleaseMarkdown | Should -Match 'Version 25H2'
        $requestFixture.AllowAutoRedirect | Should -BeFalse
        $requestFixture.Accept | Should -Be 'text/markdown'
        $requestFixture.Timeout | Should -BeGreaterThan 0
        $requestFixture.Timeout | Should -BeLessOrEqual 15000
        $requestFixture.Aborted | Should -BeTrue
        $requestFixture.Response.Disposed | Should -BeTrue
    }
    It 'reads the requested page, defaulting to the Windows 11 page' {
        $script:requestedUri = $null
        # Get-AtlasWindowsReleaseMarkdown disposes the response it reads, so each call
        # needs its own fixture; sharing one would make the second read hit a closed stream.
        Mock New-AtlasWindowsReleaseRequest {
            $script:requestedUri = $Uri
            New-ReleaseResponseFixture -Text (New-ReleaseMarkdownFixture)
        }
        Get-AtlasWindowsReleaseMarkdown | Out-Null
        $script:requestedUri.AbsoluteUri | Should -Be 'https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information'
        Get-AtlasWindowsReleaseMarkdown -Page ([uri]'https://learn.microsoft.com/en-us/windows/release-health/release-information') | Out-Null
        $script:requestedUri.AbsoluteUri | Should -Be 'https://learn.microsoft.com/en-us/windows/release-health/release-information'
    }
    It 'does not follow a redirect to <Location>' -TestCases @(
        @{ Location = 'https://example.invalid/releases' }
        @{ Location = 'http://learn.microsoft.com/releases' }
    ) {
        $script:requestFixture = New-ReleaseResponseFixture -Text '' -Status 302 -Location $Location
        { Get-AtlasWindowsReleaseMarkdown } | Should -Throw '*outside its official HTTPS origin*'
        Should -Invoke New-AtlasWindowsReleaseRequest -Times 1 -Exactly
    }
    It 'enforces the decompressed body limit even when no length is declared' {
        $script:requestFixture = New-ReleaseResponseFixture -Text ('x' * (1MB + 1))
        { Get-AtlasWindowsReleaseMarkdown } | Should -Throw '*size limit*'
        $requestFixture.Response.Disposed | Should -BeTrue
    }
    It 'rejects HTML fallback content instead of parsing it as release evidence' {
        $requestFixture.Response.ContentType = 'text/html'
        { Get-AtlasWindowsReleaseMarkdown } | Should -Throw '*not Markdown within the size limit*'
    }
    It 'limits same-origin redirect loops' {
        $script:requestFixture = New-ReleaseResponseFixture -Text '' -Status 302 -Location 'https://learn.microsoft.com/redirect-loop'
        { Get-AtlasWindowsReleaseMarkdown } | Should -Throw '*redirect limit*'
        Should -Invoke New-AtlasWindowsReleaseRequest -Times 4 -Exactly
    }
}

Describe 'Reviewed release catalog regeneration' {
    BeforeAll {
        $script:generator = Join-Path $PSScriptRoot '../tools/dev/Update-WindowsReleaseCatalog.ps1'
        $script:markdownPath = Join-Path $TestDrive 'release-source.md'
        $script:consolidatedPath = Join-Path $TestDrive 'consolidated-source.md'
        [IO.File]::WriteAllText($markdownPath, (New-ReleaseMarkdownFixture), [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($consolidatedPath, (New-ConsolidatedMarkdownFixture), [Text.UTF8Encoding]::new($false))
    }
    It 'reproduces identical catalog bytes from the same saved source and cutoff' {
        $first = Join-Path $TestDrive 'first.json'
        $second = Join-Path $TestDrive 'second.json'
        # Separate PowerShell 7 processes, as maintainers run it: each orders an unordered
        # hashtable differently.
        foreach ($path in $first, $second) {
            $output = & $script:AtlasTestToolsHost -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $generator -MarkdownPath $markdownPath -ConsolidatedMarkdownPath $consolidatedPath -AsOfDate '2026-09-07' -OutputPath $path 2>&1
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        }
        (Get-FileHash $first).Hash | Should -Be (Get-FileHash $second).Hash
        $text = [IO.File]::ReadAllText($first)
        $text.Contains("`r") | Should -BeFalse
        $text | Should -Match '[^\n]\n\z'
        $catalog = $text | ConvertFrom-Json
        $catalog.schemaVersion | Should -Be 3
        $catalog.supportedReleases.build | Should -Be @(19045,26200,26300)
        # At 2026-09-07 the 22H2 row (available 2026-11-10) is a future release and is excluded.
        $catalog.releases.version | Should -Be @('10.0.26200.9999')
        $catalog.asOfDate | Should -Be '2026-09-07'
    }
    It 'generates every supported release family with a source per page' {
        $catalogPath = Join-Path $TestDrive 'both.json'
        $output = & $script:AtlasTestToolsHost -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $generator -MarkdownPath $markdownPath -ConsolidatedMarkdownPath $consolidatedPath -AsOfDate '2026-09-30' -OutputPath $catalogPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        $catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
        $catalog.schemaVersion | Should -Be 3
        $catalog.supportedReleases.build | Should -Be @(19045,26200,26300)
        # The 22H2 row (2026-11-10) is still in the future on 2026-09-30 and is excluded.
        $catalog.releases.version | Should -Be @('10.0.26200.9999','10.0.26300.9457','10.0.26300.9550')
        # Both pages are read; the family order lists 22H2 first, so the consolidated
        # page is the first source. Compare as a set, since the order is not part of
        # the contract, only that each page contributed exactly one source.
        @($catalog.sources).Count | Should -Be 2
        @($catalog.sources.url | Sort-Object) | Should -Be @(
            @(
                'https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information',
                'https://learn.microsoft.com/en-us/windows/release-health/release-information'
            ) | Sort-Object
        )
        # The Windows 11 URL contains 'release-information' too, so match the Windows 11
        # page on its full, distinct suffix and the consolidated page on the exact URL.
        @($catalog.sources | Where-Object { $_.url -like '*windows11-release-information' }).sha256 |
            Should -Be (Get-FileHash $markdownPath -Algorithm SHA256).Hash
        @($catalog.sources | Where-Object { $_.url -eq 'https://learn.microsoft.com/en-us/windows/release-health/release-information' }).sha256 |
            Should -Be (Get-FileHash $consolidatedPath -Algorithm SHA256).Hash
        $catalog.asOfDate | Should -Be '2026-09-30'
    }
    It 'includes the Windows 10 22H2 family once its release is published' {
        $catalogPath = Join-Path $TestDrive 'win10.json'
        $output = & $script:AtlasTestToolsHost -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $generator -MarkdownPath $markdownPath -ConsolidatedMarkdownPath $consolidatedPath -AsOfDate '2026-11-30' -OutputPath $catalogPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        $catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
        $catalog.releases.version | Should -Contain '10.0.19045.7846'
    }
}
