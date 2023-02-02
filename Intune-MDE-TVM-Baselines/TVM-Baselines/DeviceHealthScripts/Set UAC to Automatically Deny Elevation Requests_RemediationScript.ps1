$RegistryKeys = @(
    # Set UAC to automatically deny elevation requests on standard accounts.
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System";
        Name = "ConsentPromptBehaviorUser";
        Value = "0";
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
