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
                $RegType = $ParentKey.GetValueKind($Match)
                If ($RegType -eq "ExpandString")
                {
                    #RegEx to generate an unexpanded string to use for correcting
                    $ValueRegEx = '(^(?!\u0022).*\.[Ee][Xx][Ee](?<!\u0022))(.*$)'
                    #Get the value without expanding the environmental names
                    $Value = $ParentKey.GetValue($Match, $Null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                    $Value -match $ValueRegEx
                }
                #Uses the matches from the RegEx to build a new entry encapsulating the exe path with double quotes
                $Correction = "$([char]34)$($Matches[1])$([char]34)$($Matches[2])"
                #Attempt to correct the entry
                Try { $ParentKey.SetValue("$Match", "$Correction", [Microsoft.Win32.RegistryValueKind]::$RegType) }
                Catch { Write-Debug "Unable to write to $ParentKey" }
            }
        }
    }
    $ParentKey.Close()
}
$Registry.Close()