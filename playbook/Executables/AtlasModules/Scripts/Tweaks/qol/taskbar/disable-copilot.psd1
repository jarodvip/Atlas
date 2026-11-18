@{
    Name        = 'Disable Microsoft Copilot'
    # Windows 11 only (build 22000+): Copilot and the RemoveMicrosoftCopilotApp policy are Windows 11 only.
    MinBuild    = 22000
    Description = 'Disables Microsoft Copilot as it depends on Edge, as well it collecting data and not being used by most users'
    Registry    = @(
        # Copilot removal is primarily the Copilot AppX phase plus the taskbar unpin in
        # taskbar/config-pins. RemoveMicrosoftCopilotApp (25H2+) additionally uninstalls
        # the Copilot app where supported; only honored on Enterprise/Education, inert
        # elsewhere.
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'RemoveMicrosoftCopilotApp'; Type = 'DWord'; Data = 1; VerifyWithToggle = @{ Name = 'Copilot'; State = 1; Operation = 'Delete' } }
    )
}
