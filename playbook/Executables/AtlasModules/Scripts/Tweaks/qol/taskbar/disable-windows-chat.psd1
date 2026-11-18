@{
    Name        = 'Disable Windows Chat'
    # The Teams/chat taskbar button and its ChatIcon policy are Windows 11 features.
    MinBuild    = 22000
    Description = 'Disables Windows Chat (the Teams chat taskbar button) as it is not commonly used'
    Registry    = @(
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat'; Name = 'ChatIcon'; Type = 'DWord'; Data = 3 }
        @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarMn'; Type = 'DWord'; Data = 0 }
    )
}
