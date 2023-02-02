$RegistryKeys = @(
    # Disable Flash on Adobe Reader DC
    @{Path = "HKLM:\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown";
        Name = "bEnableFlash";
        Value = "0";
        RegType = "DWORD"},
    # Disable JavaScript on Adobe Reader DC
    @{Path = "HKLM:\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown";
        Name = "bDisableJavaScript";
        Value = "1";
        RegType = "DWORD"},
    # Disable Flash on Adobe Acrobat DC
    @{Path = "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown";
        Name = "bEnableFlash";
        Value = "0";
        RegType = "DWORD"},
    # Disable JavaScript on Adobe Acrobat DC
    @{Path = "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown";
        Name = "bDisableJavaScript";
        Value = "1";
        RegType = "DWORD"}
 )

foreach ($RegistryKey in $RegistryKeys) {
    $RegistryPath = $RegistryKey.Path
    $Name = $RegistryKey.Name
    $Value = $RegistryKey.Value
    $RegType = $RegistryKey.RegType

    If (!(Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType $RegType -Force | Out-Null
}
