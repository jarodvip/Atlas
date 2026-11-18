@{
    Name        = 'Show More Pins in Start'
    # Windows 11 only (build 22000+): Start_Layout pins are a Windows 11 Start value.
    MinBuild    = 22000
    Description = 'Shows more pins in the Start Menu, meaning less recommendations'
    Registry    = @(
        @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_Layout'; Type = 'DWord'; Data = 1 }
    )
}
