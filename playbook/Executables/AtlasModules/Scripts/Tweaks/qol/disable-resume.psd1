@{
    Name        = 'Disable Cross Device Resume'
    # CrossDeviceResume and the DisableCrossDeviceResume MDM default are Windows 11.
    MinBuild    = 22000
    Description = 'Disables the CrossDeviceResume process that resumes activities across devices'
    # These are the same two values the PhoneLink toggle's Disable state owns. Deferring
    # to that toggle's recorded choice (VerifyWithToggle) keeps a user who enabled Phone
    # Link from having these silently set back to disabled by an install default, and
    # lets health verify against the toggle instead of a second, independent owner.
    Registry    = @(
        @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'; Name = 'IsResumeAllowed'; Type = 'DWord'; Data = 0; VerifyWithToggle = @{ Name = 'PhoneLink'; State = 1; Type = 'DWord'; Data = 1 } }
        @{ Path = 'HKCU\SOFTWARE\Microsoft\PolicyManager\default\Connectivity\DisableCrossDeviceResume'; Name = 'Value'; Type = 'DWord'; Data = 1; VerifyWithToggle = @{ Name = 'PhoneLink'; State = 1; Type = 'DWord'; Data = 0 } }
    )
}
