$BaseKeys = "HKLM:\System\CurrentControlSet\Services",                                  #Services
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",                #32bit Uninstalls
            "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"     #64bit Uninstalls
#Blacklist for keys to ignore
$IgnoreList = $Null
#Create an ArrayList to store results in
$Values = New-Object System.Collections.ArrayList
#Discovers all registry keys under the base keys
$DiscKeys = Get-ChildItem -Recurse -Directory $BaseKeys -Exclude $IgnoreList -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty Name | %{($_.ToString().Split('\') | Select-Object -Skip 1) -join '\'}
#Open the local registry
$Registry = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Default')
ForEach ($RegKey in $DiscKeys)
{
    #Open each key with write permissions
    Try { $ParentKey = $Registry.OpenSubKey($RegKey, $True) }
    Catch { Write-Debug "Unable to open $RegKey" }
    #Test if registry key has values
    If ($ParentKey.ValueCount -gt 0)
    {
        $MatchedValues = $ParentKey.GetValueNames() | ?{ $_ -eq "ImagePath" -or $_ -eq "UninstallString" }
        ForEach ($Match in $MatchedValues)
        {
            #RegEx that matches values containing .exe with a space in the exe path and no double quote encapsulation
            $ValueRegEx = '(^(?!\u0022).*\s.*\.[Ee][Xx][Ee](?<!\u0022))(.*$)'
            $Value = $ParentKey.GetValue($Match)
            #Test if value matches RegEx
            If ($Value -match $ValueRegEx)
            {
                $ParentKey.Close()
                $Registry.Close()
                exit 1
            }
        }
    }
    $ParentKey.Close()
}
$Registry.Close()
