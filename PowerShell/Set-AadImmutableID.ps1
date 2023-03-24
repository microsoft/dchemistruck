<#
    .SYNOPSIS
    Calculates the ImmutableID for a list of AD DS users, then sets the ImmutableID in Azure AD via UPN matching.

    .Description
    This script requires Domain Admin access and Azure AD Admin permissions. Run the script from a domain-joined machine with access to AD DS.
    CSV file requires single column labeled: userprincipalname

    .PARAMETER filename
    Specify the File path to a CSV with a single column named: UserPrincipleName

    .PARAMETER ExportPath
    Specify the folder path to store logs in CSV format.

    .EXAMPLE
    Set-AadImmutableID.ps1 -filename "C:\temp\upn.csv" -exportPath "C:\Temp"

    .NOTES
    AUTHOR
    Dan Chemistruck

    MIT License

    Copyright (c) 2023 Dan Chemistruck
    
    All rights reserved.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
#>
[CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact='Medium')]
Param(
	[Parameter(Mandatory=$true,
			HelpMessage="Specify the File path to a CSV with a single column named: UserPrincipleName")]
	[Alias('file')]
	[string]$filename,
	
	[Parameter(Mandatory=$false,
			HelpMessage="Specify the folder path to store logs in CSV format.")]
			[String]$exportPath = (get-location).path
)

Begin
{
    # Import the Active Directory and MSOnline modules
    import-module ActiveDirectory
    import-module MSOnline
    # Connect to the MSOnline service
    connect-msolservice

    # Import a list of users from a CSV file. These users will have their ImmutableID updated in Azure AD.
    $immutableUsers = Import-Csv $filename
    # Create the variables to calculate the completion progress.
    $userCount = $($immutableUsers|Measure-Object).count
    $progressCounter=0
    #Set Logging paths.
    $immutableIdExport = $exportPath + "\ImmutableID.csv"
    $immutableIdErrors = $exportPath + "\ImmutableID-Errors.csv"
    $immutableIdList = @()
    $immutableLog = @()
    $errorLogs = @()
}

Process
{
   
    foreach ($user in $immutableUsers)
    {
        $percentComplete = ($progressCounter/$userCount)*100
        Write-Progress -Activity "Calculating ImmutableID" -CurrentOperation $user.UserPrincipalName -PercentComplete $percentComplete

        #Get the ObjectGUID for the Current User.
        $upn=$user.UserPrincipalName
        $currentUser = Get-ADUser -Filter "userPrincipalName -eq '$upn'" -properties ObjectGUID

        #Calculate the ImmutableID for the current user based on the ObjectGUID.
        if ($currentUser)
        {
            $immutableID = [system.convert]::ToBase64String($currentUser.ObjectGUID.tobytearray())
            $userObject = new-object psobject
            $userObject | add-member -name userprincipalname -type noteproperty -value $user.UserPrincipalName
            $userObject | add-member -name immutableID -type noteproperty -value  $immutableID
            $immutableIdList += $userObject
            $progressCounter++
        }
        else
        {
            #Create Error Log.
            $logName = $user.UserPrincipalName
            $logObject = new-object PSObject
            $logObject| add-member -membertype NoteProperty -name "UserPrincipalName" -Value $logName
            $logObject| add-member -membertype NoteProperty -name "Error" -Value "User does not exist in AD DS."
            $logObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
            $errorLogs += $logObject
        }
    }
}

End
{
    $progressCounter=0

    foreach ($user in $immutableIdList)
    {
        $percentComplete = ($progressCounter/$userCount)*100
        Write-Progress -Activity "Setting ImmutableID" -CurrentOperation $user.userprincipalname -PercentComplete $percentComplete

        try {
            #Log the old ane new ImmutableID for the user.
            $oldImmutableId = $(Get-MsolUser -UserPrincipalName $user.userprincipalname |Select-Object ImmutableID).ImmutableID
            $userLogObject = new-object psobject
            $userLogObject | add-member -name userprincipalname -type noteproperty -value $user.UserPrincipalName
            $userLogObject | add-member -name NewImmutableID -type noteproperty -value  $user.immutableID
            $userLogObject | add-member -name OldImmutableID -type noteproperty -value  $oldImmutableId
            $immutableLog += $userLogObject
            #Set the Immutable ID for the current user in Azure AD.
            Set-MsolUser -UserPrincipalName $user.userprincipalname -ImmutableId $user.immutableID    
        }
        catch {
            #Create Error Log.
            $logName = $user.UserPrincipalName
            $logObject = new-object PSObject
            $logObject| add-member -membertype NoteProperty -name "UserPrincipalName" -Value $logName
            $logObject| add-member -membertype NoteProperty -name "Error" -Value "User does not exist in Azure AD."
            $logObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
            $errorLogs += $logObject
        }
        $progressCounter++
    }
    #Export the logs to CSV.
    $immutableLog | export-csv $immutableIdExport -NoTypeInformation
    $errorLogs | export-csv $immutableIdErrors -NoTypeInformation
    #On your Azure AD Connect server, sync your users by running: start-adsyncsynccycle -policytype Delta
}
