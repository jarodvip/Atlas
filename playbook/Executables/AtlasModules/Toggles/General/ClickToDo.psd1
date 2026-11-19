@{
    Name        = 'ClickToDo'
    Description = 'Click To Do through the Windows AI DisableClickToDo policy.'
    Elevation   = 'Admin'
    # Click To Do and the WindowsAI policy are Windows 11 features.
    MinBuild    = 22000
    States      = @(
        @{
            Name       = 'Disable'
            StateValue = 0
            Launcher   = '3. General Configuration\AI Features\Click To Do\Disable Click To Do (default).cmd'
            Reboot     = 'None'
            Registry   = @(
                @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableClickToDo'; Type = 'DWord'; Data = 1 }
            )
        }
        @{
            Name       = 'Enable'
            StateValue = 1
            Launcher   = '3. General Configuration\AI Features\Click To Do\Enable Click To Do.cmd'
            Reboot     = 'None'
            Registry   = @(
                @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableClickToDo'; Operation = 'Delete' }
            )
        }
    )
}
