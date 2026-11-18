@{
    Name        = 'Set Taskbar to Align Left'
    # Windows 11 only (build 22000+): TaskbarAl (centered taskbar) is a Windows 11 value.
    MinBuild    = 22000
    Description = 'Sets taskbar to align left instead of centered'
    Registry    = @(
        @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAl'; Type = 'DWord'; Data = 0 }
    )
}
