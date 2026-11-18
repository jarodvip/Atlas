@{
    Name        = 'Hide Gallery in File Explorer'
    # Windows 11 only (build 22000+): File Explorer Gallery is a Windows 11 feature.
    MinBuild    = 22000
    Description = 'Hides the ''Gallery'' picture view in the File Explorer navigation pane'
    Registry    = @(
        @{ Path = 'HKCU\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'; Name = 'System.IsPinnedToNameSpaceTree'; Type = 'DWord'; Data = 0 }
    )
}
