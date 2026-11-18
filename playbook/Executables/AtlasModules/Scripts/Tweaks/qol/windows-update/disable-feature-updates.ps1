# Pins Windows Update to the installed Windows release, so it offers no feature update.
# Atlas Manager moves Windows between releases by retargeting this pin.
$ErrorActionPreference = 'Stop'
. ([IO.Path]::Combine($PSScriptRoot, '..', '..', '..', 'Preparation', 'WindowsTransition.ps1'))

# Win32_OperatingSystem.Caption is reliable: it distinguishes Windows 10 and Windows 11
# (unlike the registry ProductName, which still reads "Windows 10" on Windows 11). Atlas
# supports Windows 11 and Windows 10 22H2, so both are pinned, each with its own product.
$os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
$productName = if ($os.Caption -match 'Windows 11') { 'Windows 11' }
elseif ($os.Caption -match 'Windows 10') { 'Windows 10' }
else { throw "Refusing to pin the feature-update target: OS caption '$($os.Caption)' is not Windows 10 or Windows 11." }

$currentVersion = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
if ([string]::IsNullOrWhiteSpace($currentVersion.DisplayVersion)) {
    throw 'Windows DisplayVersion was empty; cannot set TargetReleaseVersionInfo.'
}

Set-AtlasFeatureUpdateTarget -Release $currentVersion.DisplayVersion -ProductVersion $productName
