@{
    Name        = 'Set Unpinned Control Center Items'
    # The Cast/NearShare entries and ProjectL2 toggle list are Windows 11's. Windows 10
    # uses different quick actions (Connect, Location, ScreenClipping), which this
    # Windows 11 action set doesn't describe, so leave Windows 10 untouched.
    MinBuild    = 22000
    Description = 'Disables unused control center items by default for QoL'
    Registry    = @(
        @{ Path = 'HKCU\Control Panel\Quick Actions\Control Center\Unpinned'; Name = 'Microsoft.QuickAction.Cast'; Type = 'None' }
        @{ Path = 'HKCU\Control Panel\Quick Actions\Control Center\Unpinned'; Name = 'Microsoft.QuickAction.NearShare'; Type = 'None' }
        @{ Path = 'HKCU\Control Panel\Quick Actions\Control Center\QuickActionsStateCapture'; Name = 'Toggles'; Type = 'String'; Data = 'Toggles,Microsoft.QuickAction.BlueLightReduction:false,Microsoft.QuickAction.Accessibility:false,Microsoft.QuickAction.ProjectL2:false' }
    )
    # Reload the user's shell only after the signed-in user's HKCU pass succeeds.
    PostUserRegistryRefresh = 'ExplorerRefresh'
}
