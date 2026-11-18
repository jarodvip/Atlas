@{
    Name        = 'Disable Windows 11 Settings Banner'
    # Windows 11 only (build 22000+): The ValueBanner Settings page is a Windows 11 feature.
    MinBuild    = 22000
    Description = 'Disables the Windows 11 Settings banner (ValueBanner), which normally displays ''advertisements'' such as Microsoft 365 on non-Enterprise editions'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\ValueBanner.IdealStateFeatureControlProvider'; Name = 'ActivationType'; Type = 'DWord'; Data = 0 }
    )
}
