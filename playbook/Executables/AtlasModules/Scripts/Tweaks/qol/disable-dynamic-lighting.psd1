@{
    Name        = 'Disable Dynamic Lighting'
    # Windows 11 only (build 22000+): Dynamic Lighting and the Lighting settings arrived with Windows 11.
    MinBuild    = 22000
    Description = 'Disables Dynamic Lighting by default'
    Registry    = @(
        @{ Path = 'HKCU\Software\Microsoft\Lighting'; Name = 'AmbientLightingEnabled'; Type = 'DWord'; Data = 0 }
    )
}
