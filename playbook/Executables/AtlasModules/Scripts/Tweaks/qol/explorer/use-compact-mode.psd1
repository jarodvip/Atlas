@{
    Name        = 'Use Compact Mode'
    # Windows 11 only (build 22000+): UseCompactMode is a Windows 11 Explorer value.
    MinBuild    = 22000
    Description = 'Sets compact mode in File Explorer'
    Registry    = @(
        @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'UseCompactMode'; Type = 'DWord'; Data = 1 }
    )
}
