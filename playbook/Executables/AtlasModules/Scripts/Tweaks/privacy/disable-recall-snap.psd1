@{
    Name        = 'Disable Recall Snapshots'
    # Windows 11 only (build 22000+): Windows 10 has no Recall or WindowsAI policy.
    MinBuild    = 22000
    Description = 'Disables snapshots of Recall (24H2+)'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Type = 'DWord'; Data = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'AllowRecallEnablement'; Type = 'DWord'; Data = 0 }
    )
}
