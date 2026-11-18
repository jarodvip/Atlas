@{
    Name        = 'Disable Cross Device Resume'
    # CrossDeviceResume and the DisableCrossDeviceResume MDM default are Windows 11.
    MinBuild    = 22000
    Description = 'Disables the CrossDeviceResume process that resumes activities across devices'
    Registry    = @(
        @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'; Name = 'IsResumeAllowed'; Type = 'DWord'; Data = 0 }
        @{ Path = 'HKCU\SOFTWARE\Microsoft\PolicyManager\default\Connectivity\DisableCrossDeviceResume'; Name = 'Value'; Type = 'DWord'; Data = 1 }
    )
}
