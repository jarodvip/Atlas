@{
    Name        = 'Don''t Show Office Files'
    # Windows 11 only (build 22000+): The Home/Quick Access cloud-file list is Windows 11 only.
    MinBuild    = 22000
    Description = 'Don''t show Office files in Quick Access (Home)'
    Registry    = @(
        @{ Path = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'ShowCloudFilesInQuickAccess'; Type = 'DWord'; Data = 0 }
    )
}
