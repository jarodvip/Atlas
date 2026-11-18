@{
    Name        = 'Remove Windows 11 Printing Context Menu Entries'
    # The AppX Print class is the Windows 11 shell menu; Windows 10's print verbs are
    # different, so leave Windows 10's context menu untouched.
    MinBuild    = 22000
    Description = 'Applies the Windows 11 AppX class values from the Printing Disable context-only action.'
    Registry    = @(
        @{ Path = 'Registry::HKEY_CLASSES_ROOT\AppX4ztfk9wxr86nxmzzq47px0nh0e58b8fw\Shell\Print'; Name = 'LegacyDisable'; Type = 'String'; Data = '' }
        @{ Path = 'Registry::HKEY_CLASSES_ROOT\AppX4ztfk9wxr86nxmzzq47px0nh0e58b8fw\Shell\Print'; Name = 'ProgrammaticAccessOnly'; Type = 'String'; Data = '' }
        @{ Path = 'Registry::HKEY_CLASSES_ROOT\AppX4ztfk9wxr86nxmzzq47px0nh0e58b8fw\Shell\Print'; Name = 'HideBasedOnVelocityId'; Type = 'DWord'; Data = 6527944 }
        @{ Path = 'Registry::HKEY_CLASSES_ROOT\AppX4ztfk9wxr86nxmzzq47px0nh0e58b8fw\Shell\PrintTo'; Name = 'LegacyDisable'; Type = 'String'; Data = '' }
        @{ Path = 'Registry::HKEY_CLASSES_ROOT\AppX4ztfk9wxr86nxmzzq47px0nh0e58b8fw\Shell\PrintTo'; Name = 'ProgrammaticAccessOnly'; Type = 'String'; Data = '' }
        @{ Path = 'Registry::HKEY_CLASSES_ROOT\AppX4ztfk9wxr86nxmzzq47px0nh0e58b8fw\Shell\PrintTo'; Name = 'HideBasedOnVelocityId'; Type = 'DWord'; Data = 6527944 }
    )
}
