<#
	.SYNOPSIS
	Creates symmetric block policies for all segments in the Information Barriers portal, with an exclusion list.	
 
    .DESCRIPTION
    Requires the ExchangeOnlineManagement module:
        Install-Module -Name ExchangeOnlineManagement
        Import-Module -Name ExchangeOnlineManagement
    Assumes that there are no "Allow" policies and that you want to bulk block each Segment from each other.
    There is an option to exclude Segments so that custom policies can be created manually instead.

    .PARAMETER Exclusions
    Specifies the prefix of segments that are allowed to talk to any other segment. Supports regex and wildcards. Combine multiple segment names with a '|' for example: corp*|sales|accounting

    .PARAMETER GlobalAllow
    Creates a single allow policy from one segment to all other segments. Does not support wildcards. Must use the exact Segment Name.

    .PARAMETER GlobalAllowExclusions
    Specifies the prefix of segments to exclude from the GlobalAllow Policy. Supports regex and wildcards. Combine multiple segment names with a '|' for example: corp*|sales|accounting
    Value is ignored if GlobalAllow parameter is not set.

    .PARAMETER ApplyPolicy
    Enter $false to manually apply policy later. This can be helpful when troubleshooting new policies.

    .PARAMETER LogPath
    Specifies the directory to generate log files. Default is:  C:\Temp\InformationBarriers

    .PARAMETER Connect
    Creates a new EXO session by default.

    .PARAMETER Disconnect
    Closes the EXO session by default.

    .EXAMPLE
    .\Set-InformationBarriers-SymmetricBlockPolicies.ps1 -Exclusions 'Global' -GlobalAllow 'Global'

    .EXAMPLE
    .\Set-InformationBarriers-SymmetricBlockPolicies.ps1 -Exclusions 'Global*|HR' -GlobalAllow 'Global' -GlobalAllowExclusions 'Global|HR*|Isolated' -LogPath 'C:\logs' -connect $false -disconnect $false -ApplyPolicy $false

    .NOTES
    AUTHOR
    Dan Chemistruck

    Authored Date
    06/15/2022

    MIT License

    Copyright (c) 2022 Microsoft
    
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
    [Parameter(Mandatory=$false,
        HelpMessage="Enter the prefix of segments that are allowed to talk to any other segment. Supports regex and wildcards. Combine multiple segment names with a '|' for example: corp*|sales")]
        [ValidateLength(0,256)]
        [String]$Exclusions=$null,

    [Parameter(Mandatory=$false,
        HelpMessage="Enter the exact Segment name to be used for a global allow policy.")]
        [Parameter (Mandatory = $true,ParameterSetName = "GlobalAllow")]
        [ValidateLength(0,256)]
        [String]$GlobalAllow=$null,

    [Parameter(Mandatory=$false,
        ParameterSetName = "GlobalAllow",
        HelpMessage="Enter the prefix of segments to exclude from the GlobalAllow policy. Supports regex and wildcards. Combine multiple segment names with a '|' for example: corp*|sales")]
        [ValidateLength(0,256)]
        [String]$GlobalAllowExclusions=$null,

    [Parameter(Mandatory=$false,
        HelpMessage='Enter $false to manually apply policy later.')]
        [boolean]$ApplyPolicy = $true,

    [Parameter(Mandatory=$false,
        HelpMessage='Enter $true to connect to Exchange Online or false if you already have a session established.')]
        [boolean]$Connect = $true,

    [Parameter(Mandatory=$false,
        HelpMessage='Enter $true to disconnect from Exchange Online.')]
        [boolean]$Disconnect = $true,

    [Parameter(Mandatory=$false,
        HelpMessage="Directory to output log files to")]
        [String]$LogPath="C:\Temp\InformationBarriers"
)
Begin
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (!(test-path $LogPath)){
        New-Item -Path $LogPath -ItemType directory
    }
    $LogPath = join-path $LogPath "InformationBarriers-Logs.csv"

    #Import the Exchange Online Management module or installs it, and connects to Exchange Online.
    if ($Connect){
        try {
            write-host Importing ExchangeOnlineManagement -foregroundcolor: yellow
            Import-Module ExchangeOnlineManagement -ErrorAction SilentlyContinue
        }
        catch {
            write-host ExchangeOnlineManagement Module is not installed.
            Install-Module -Name ExchangeOnlineManagement -Confirm $false
            Import-Module ExchangeOnlineManagement
        }
        Connect-IPPSSession
    }
}

Process
{
    # Gathers all segments (and filters out segments on the Exclusions list) and policies.
    $segments = Get-OrganizationSegment|sort name
    $allowedSegments = $segments
    if(!($Exclusions -eq $null)){
        $segments = $segments| where{$_.Name -notmatch $Exclusions}
    }
    $policies = Get-InformationBarrierPolicy
    # Adds all filtered segments to existing policies or creates a new policy.
    $i=0
    Foreach ($segment in $segments)
    {
        $progress=$segment.name
        [INT]$CurrentOperation = ($i/$segments.count)*100
        Write-Progress -Activity "Reviewing policy for $progress"  -PercentComplete $CurrentOperation
        # Define segments to exlcude block list. This includes the current segment a$nd other segments with the same prefix, which is identified with a '-'.
        $blockedsegments = $segments | where{$_.Name -notmatch $segment.name -and $_.name.split('-')[0] -notmatch $segment.name.split('-')[0]}
        $name = "Block " + $segment.name + " to non-corporate segments"
        write-host Block Segment: $progress -foregroundcolor: magenta
        # Find out if there is an existing policy and update it.
        if($policies|where {$_.assignedsegment -eq $segment.name}) {
            Write-Progress -Activity "Reviewing policy for $progress" -CurrentOperation  "Updating existing policy." -PercentComplete $CurrentOperation
            $guid = $policies|where {$_.assignedsegment -eq $segment.name}|select guid,name
            try{
                Set-InformationBarrierPolicy -id $guid.guid -SegmentsBlocked $blockedsegments.name -State Active -force -ErrorAction stop

                $logName = $guid.name
                $logObject = new-object PSObject
                $logObject| add-member -membertype NoteProperty -name "Policy" -Value $logName
                $logObject| add-member -membertype NoteProperty -name "Error" -Value "Success"
                $logObject| add-member -membertype NoteProperty -name "Step" -Value "Updating Existing Policy"
                $logObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
                $logObject| export-csv $LogPath -nti -append -force     
            }
            catch{
                $errName = $guid.name
                Write-warning "Error with updating exising policy $errName. $_.Exception.Message"
                $errorObject = new-object PSObject
                $errorObject| add-member -membertype NoteProperty -name "Policy" -Value $errName
                $errorObject| add-member -membertype NoteProperty -name "Error" -Value $_.Exception.Message
                $errorObject| add-member -membertype NoteProperty -name "Step" -Value "Updating Existing Policy"
                $errorObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
                $errorObject| export-csv $LogPath -nti -append -force
            }
        }
        # Otherwise, create a new policy.
        else {
            Write-Progress -Activity "Reviewing policy for $progress" -CurrentOperation "Creating new policy:  $name." -PercentComplete $CurrentOperation
            try{
                New-InformationBarrierPolicy -Name $name -AssignedSegment $segment.name -SegmentsBlocked $blockedsegments.name -State Active -force -ErrorAction stop

                $logObject = new-object PSObject
                $logObject| add-member -membertype NoteProperty -name "Policy" -Value $name
                $logObject| add-member -membertype NoteProperty -name "Error" -Value "Success"
                $logObject| add-member -membertype NoteProperty -name "Step" -Value "Creating New Policy"
                $logObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
                $logObject| export-csv $LogPath -nti -append -force     
            }
            catch{
                Write-warning "Error with creating new policy $name. $_.Exception.Message"
                $errorObject = new-object PSObject
                $errorObject| add-member -membertype NoteProperty -name "Policy" -Value $name
                $errorObject| add-member -membertype NoteProperty -name "Error" -Value $_.Exception.Message
                $errorObject| add-member -membertype NoteProperty -name "Step" -Value "Creating New Policy"
                $errorObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
                $errorObject| export-csv $LogPath -nti -append -force
            }  
        }
        $i++
    }

    # If a Segment has been added to GlobalAllow, then create an allow policy.
    if (!($GlobalAllow -eq $null)){
        $progress=$GlobalAllow
        if(!($GlobalAllowExclusions -eq $null)){
            $allowedSegments = $allowedSegments| where{$_.Name -notmatch $GlobalAllowExclusions}
        }
        $name = "Allow " + $GlobalAllow + " to all segments"
        write-host Allow Segment: $progress -foregroundcolor: magenta
        # Find out if there is an existing policy and update it.
        if($policies|where {$_.assignedsegment -eq $GlobalAllow}) {
            Write-Progress -Activity "Reviewing Allow policy for $progress" -CurrentOperation "Updating existing policy."
            $guid = $policies|where {$_.assignedsegment -eq $GlobalAllow}|select guid,name
            try{
                Set-InformationBarrierPolicy -id $guid.guid -SegmentsAllowed $allowedSegments.name -State Active -force -ErrorAction stop

                $logName = $guid.name
                $logObject = new-object PSObject
                $logObject| add-member -membertype NoteProperty -name "Policy" -Value $logName
                $logObject| add-member -membertype NoteProperty -name "Error" -Value "Success"
                $logObject| add-member -membertype NoteProperty -name "Step" -Value "Updating Existing Policy"
                $logObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
                $logObject| export-csv $LogPath -nti -append -force     
            }
            catch{
                $errName = $guid.name
                Write-warning "Error with updating exising policy $errName. $_.Exception.Message"
                $errorObject = new-object PSObject
                $errorObject| add-member -membertype NoteProperty -name "Policy" -Value $errName
                $errorObject| add-member -membertype NoteProperty -name "Error" -Value $_.Exception.Message
                $errorObject| add-member -membertype NoteProperty -name "Step" -Value "Updating Existing Policy"
                $errorObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
                $errorObject| export-csv $LogPath -nti -append -force
            }
        }
        # Otherwise, create a new policy.
        else {
            Write-Progress -Activity "Reviewing Allow policy for $progress" -CurrentOperation "Creating new Allow policy: $name." 
            try{
                New-InformationBarrierPolicy -Name $name -AssignedSegment $GlobalAllow -SegmentsAllowed $AllowedSegments.name -State Active -force -ErrorAction stop

                $logObject = new-object PSObject
                $logObject| add-member -membertype NoteProperty -name "Policy" -Value $name
                $logObject| add-member -membertype NoteProperty -name "Error" -Value "Success"
                $logObject| add-member -membertype NoteProperty -name "Step" -Value "Creating New Policy"
                $logObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
                $logObject| export-csv $LogPath -nti -append -force     
            }
            catch{
                Write-warning "Error with creating new policy $name. $_.Exception.Message"
                $errorObject = new-object PSObject
                $errorObject| add-member -membertype NoteProperty -name "Policy" -Value $name
                $errorObject| add-member -membertype NoteProperty -name "Error" -Value $_.Exception.Message
                $errorObject| add-member -membertype NoteProperty -name "Step" -Value "Creating New Policy"
                $errorObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
                $errorObject| export-csv $LogPath -nti -append -force
            }  
        }
    }
}

End
{
    # After creating or updating each policy, this will apply the new policies. This may take several hours to complete.
    if($ApplyPolicy){
        try{
            Start-InformationBarrierPoliciesApplication -ErrorAction stop

            $logObject = new-object PSObject
            $logObject| add-member -membertype NoteProperty -name "Policy" -Value "Apply All Policies"
            $logObject| add-member -membertype NoteProperty -name "Error" -Value "Success"
            $logObject| add-member -membertype NoteProperty -name "Step" -Value "Applying Policy"
            $logObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
            $logObject| export-csv $LogPath -nti -append -force     
        }
        catch{
            Write-warning "Error with applying all policies. $_.Exception.Message"
            $errorObject = new-object PSObject
            $errorObject| add-member -membertype NoteProperty -name "Policy" -Value "Apply All Policies"
            $errorObject| add-member -membertype NoteProperty -name "Error" -Value $_.Exception.Message
            $errorObject| add-member -membertype NoteProperty -name "Step" -Value "Applying Policy"
            $errorObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
            $errorObject| export-csv $LogPath -nti -append -force
        }
    }
    else{
        write-host "NOTICE: Policies not applied. To apply manually, run:  Start-InformationBarrierPoliciesApplication" -ForegroundColor Yellow -BackgroundColor DarkMagenta
        $errorObject = new-object PSObject
        $errorObject| add-member -membertype NoteProperty -name "Policy" -Value "Apply All Policies"
        $errorObject| add-member -membertype NoteProperty -name "Error" -Value "Applying policies skipped by parameter input."
        $errorObject| add-member -membertype NoteProperty -name "Step" -Value "Applying Policy"
        $errorObject| add-member -membertype NoteProperty -name "Time" -Value $(get-date -Format yyyy-MM-dd_HH:mm:ss)
        $errorObject| export-csv $LogPath -nti -append -force
    }
    # Disconnects from Exchange Online
    if ($Disconnect){
        Disconnect-ExchangeOnline -confirm:$false
    }
}
