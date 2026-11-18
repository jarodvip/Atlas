# Windows release eligibility

Atlas 0.6 installs on, and builds ISOs from, Windows releases in Microsoft's General
Availability release history: Windows 11 25H2 and 26H2, and Windows 10 22H2. This page
is for testers and maintainers.

## Supported releases

| Release | Build | Status |
| --- | --- | --- |
| Windows 11 25H2 | `26200` | Supported |
| Windows 11 26H2 | `26300` | Release-candidate testing. Passed on `26300.9457`: fresh x64 Hyper-V installation, post-reboot settings readback, app-removal inventory, runtime checks, component-store health scan. Not established: physical devices, ARM64, GPU-dependent features, upgrade paths. |
| Windows 10 22H2 | `19045` | Supported as Windows 10's final release. Atlas installs after a fresh Windows 10 22H2 installation; there is no newer Windows 10 to update to. Not established: physical devices, GPU-dependent features. |

The build number alone is not enough: Insider flights have used these numbers too.
The app reads the running system's build and update revision (UBR); ISO inspection
reads DISM's four-part image version, including its service-pack build/revision
(`SPBuild`). Edition and architecture are checked separately.

| Result | Meaning |
| --- | --- |
| `Released` | The complete version is in the public General Availability table with an availability date no later than today. |
| `Preview` | A supplied BuildLabEx contains a delimited `prerelease` branch marker. |
| `Unlisted` | Microsoft's release information was read, and the complete version isn't in its General Availability tables. Most often a Release Preview build, or an update the page doesn't list yet. Atlas says so and suggests checking again once Microsoft lists it. |
| `Unknown` | Eligibility could not be established: unavailable release information, an unexpected response format, or an unlisted version checked offline. Not evidence of an Insider installation. |

- Public optional non-security updates qualify, even when Microsoft calls them
  "Preview".
- A build once offered to Insiders can later become public, so historical Insider
  lists never override published General Availability entries.
- Enrollment and flight-signing settings do not prove the installed image's channel.

## Architectures

ISO creation and USB writing accept x64 and ARM64 client images; all editions in one
image must share an architecture. The builder writes the matching
`processorArchitecture` into the answer file and verifies the UEFI loader:
`bootx64.efi` for x64, which keeps BIOS and UEFI boot catalog entries, or
`bootaa64.efi` for ARM64, which is UEFI only.

Network drivers copied from the host must match the image's architecture. Microsoft
documents [servicing ARM64 images from an AMD64 technician PC](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/arm64-device-manufacturing),
but media built on x64 may still need device-specific boot and storage drivers to
boot an ARM device.

## Online lookup

Snapshot versions are checked offline. In stable builds, an unknown version triggers a
size- and time-limited HTTPS request for the Markdown form of Microsoft's release
information. Two official pages are read, one request each, because neither lists the
other's releases:

- [Windows 11 release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information),
  for the matching 25H2 and 26H2 General Availability tables.
- [Consolidated Windows release information](https://learn.microsoft.com/en-us/windows/release-health/release-information),
  for the 22H2 (19045) General Availability table.

A page that fails to load contributes no versions for its builds rather than failing
the other page's lookup; the version stays `Unknown` when no page could be read.

- Only the matching General Availability tables are accepted.
- 15-second deadline and 1 MiB body limit per request. Unexpected content or malformed
  tables give `Unknown` for that page's builds.
- PowerShell follows at most three redirects within the same official HTTPS origin;
  the Rust client rejects redirects.
- Successful lookups are cached in memory only (the app keeps them 15 minutes), never
  in a persistent trust file.

Tester builds never make this request:

- **Running system:** an unlisted revision of a supported build on a release branch is
  accepted.
- **ISO:** an image has no BuildLabEx to show its branch, so ISO inspection calls
  `Get-AtlasWindowsReleaseStatus -NoRefresh`. It accepts an unlisted revision only if
  it is newer than every listed revision of that build. Older unlisted revisions,
  such as pre-release flights, stay `Unknown`.

## What the check does not prove

Eligibility is not an authenticity check. Metadata can be copied or altered,
identical public and Release Preview builds share a version, and offline image
metadata does not establish where every component came from. Keep requiring official
Windows media. Do not describe this check as cryptographic verification or complete
Insider detection.

## Updating the snapshot

The app, the ISO worker and the direct installer, `Install-Atlas.ps1`, share the reviewed
[`windows-releases.json`](../playbook/Executables/AtlasModules/Scripts/Compatibility/windows-releases.json)
snapshot. The app checks it in
[`windows_release.rs`](../app/src/services/windows_release.rs); PowerShell callers use
[`Windows-Release.ps1`](../playbook/Executables/AtlasModules/Scripts/Compatibility/Windows-Release.ps1).
Keep their parsers and classification fixtures consistent when changing the policy.

From the repository root in PowerShell 7:

```powershell
./tools/dev/Update-WindowsReleaseCatalog.ps1 -Refresh
```

For a repeatable update from saved official Markdown responses, give the Windows 11
page and (to refresh Windows 10 22H2 too) the consolidated page:

```powershell
./tools/dev/Update-WindowsReleaseCatalog.ps1 -MarkdownPath '<Windows 11 page>' `
    -ConsolidatedMarkdownPath '<consolidated page>' -AsOfDate '2026-11-14'
```

Review the JSON diff:

- The snapshot records, per source page, the URL, document commit, SHA-256 of the
  response and update timestamp, plus a cutoff date and each release's version, date,
  update type and KB reference. Schema 3 lists every supported release/build pair
  separately from the full-version rows.
- Check new rows against the official page. Keep public optional releases; exclude
  Insider-channel rows and future availability dates.
- Never add a version just because an ISO or a local machine reports it.

After any policy or fixture change, run `tests/Atlas.WindowsRelease.Tests.ps1` through
the repository's Pester runner and the Rust `services::windows_release` tests. The
PowerShell fixtures cover malformed tables, network failures, response limits,
redirect restrictions, snapshot fallback and deterministic generation. They do not
replace installation, servicing or ISO boot validation.
