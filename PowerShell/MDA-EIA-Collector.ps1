<#
.SYNOPSIS
    Downloads files from Azure Blob storage, processes the JSON files into the proper schema for Defender for Cloud Apps, uploads the result to a local FTP instance running on the log collector, and then deletes all the logs.

.DESCRIPTION
    This script has two dependencies that must be installed separately: AzCopy and the On-premises Docker log collector.
    https://gist.github.com/aessing/236ef7bba66d724c6de4992ac77b7b60
    https://learn.microsoft.com/en-us/defender-cloud-apps/discovery-docker-windows
    This VM can be run in Azure but it requires nested virtualization. D2s_v3 without Trusted Launch is the cheapest supported VM as aof November 2024.

    #### IMPORTANT!!! You must manually run the next line once to store your FTP password securely before creating the scheduled task to run this script! Only change the "LogCollectorPassword" below. ####
    [System.Environment]::SetEnvironmentVariable("FTP_PASSWORD", "LogCollectPassword", "User")

    Then you must run the following to cache your storage account token:
    AzCopy Login

    The Scheduled task must be run as the user account that cached both of these tokens. The user's password must be stored with the scheduled task.

.PARAMETER storageAccountName
    The name of the Azure storage account.

.PARAMETER containerName
    The name of the Azure Blob storage container.

.PARAMETER destinationPath
    The local path where files will be downloaded and processed. Default is "C:\temp\MDA".

.PARAMETER ftpUserName
    The username for the FTP server. Default is "discovery".

.PARAMETER ftpPassword
    The password for the FTP server.

.PARAMETER logCollectorName
    The name of the log collector to be used in the FTP URI. To find out the collector name, connect to the root of your FTP server.

.EXAMPLE
    .\MDA-EIA-Collector.ps1

.AUTHOR
    Dan Chemistruck

.LICENSE
    MIT License

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
[CmdletBinding()]
param (
        [Parameter(Mandatory=$false, HelpMessage="The name of the Azure storage account.")]
            [string]$storageAccountName = "fitusw2entralogcollector",

        [Parameter(Mandatory=$false, HelpMessage="The name of the Azure Blob storage container.")]
            [string]$containerName = "insights-logs-networkaccesstrafficlogs",

        [Parameter(Mandatory=$false, HelpMessage="The local path where files will be downloaded and processed.")]
            [string]$destinationPath = "C:\temp\MDA",

        [Parameter(Mandatory=$false, HelpMessage="The name of the log collector created in Microsoft Defender for Cloud Apps.")]
            [string]$logCollectorName = "Entra_Internet_Access"
    )
#### IMPORTANT!!! You must manually run the next line once to store your FTP password securely before creating the scheduled task to run this script! Only change the "LogCollectorPassword" below. ####
# [System.Environment]::SetEnvironmentVariable("FTP_PASSWORD", "LogCollectPassword", "User")
[SecureString]$ftpPassword = ConvertTo-SecureString $([System.Environment]::GetEnvironmentVariable("FTP_PASSWORD", "User")) -AsPlainText -Force
$ftpUserName = "discovery"                                                          # The username for the Log Collector's FTP server running in WSL.
$sourceUrl = "https://$storageAccountName.blob.core.windows.net/$containerName"     # Construct the source URL.
$csvFilePath = "$destinationPath\MDA.csv"                                           # Define the path to the output CSV file.
$ftpUri = "ftp://127.0.0.1/$logCollectorName/mda.csv"                               # Construct the FTP URI with the log collector name.
$eventLogSource = "MDA-Log-Collector-Script"                                        # The Source name that will appear in Event Viewer.
$serviceName = "com.docker.service"                                                 # The name of the Docker Service.
$processPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"                  # Docker Desktop install path.

# Function to write to the Windows Event Log
function Write-EventLogEntry {
    param (
        [string]$message,
        [string]$eventType = "Information"
    )
    if (-not (Get-EventLog -LogName Application -Source $eventLogSource -ErrorAction SilentlyContinue)) {
        New-EventLog -LogName Application -Source $eventLogSource
    }
    Write-EventLog -LogName Application -Source $eventLogSource -EntryType $eventType -EventId 1 -Message $message
}

function Get-EntraLogs {
    try {
        # Run AzCopy to download all files, ignoring folder structure
        $azCopyResult = azcopy copy "$sourceUrl/*" $destinationPath --recursive
        if ($azCopyResult -match "error") {
            throw
        }
        Write-EventLogEntry -message "Entra logs downloaded successfully. `n$azCopyResult"

        #Delete all files in the Azure Blob storage container
        $azCopyResult = azcopy rm "$sourceUrl" --recursive
        if ($azCopyResult -match " error") {
            throw
        }
        Write-EventLogEntry -message "Entra logs deleted from Azure Blob storage successfully. `n$azCopyResult"
    }
    catch {
        Write-EventLogEntry -message "An error occurred during AzCopy operations: $azCopyResult" -eventType "Error"
        throw
    }
}

function Convert-EntraLogs {
    try {
        # Get all JSON files from the root path and its subdirectories
        $jsonFiles = Get-ChildItem -Path $destinationPath -Recurse -Filter *.json

        # Initialize an array to store all parsed data
        $allData = @()

        # Loop through each JSON file and parse it
        foreach ($file in $jsonFiles) {
            $jsonData = Get-Content -Path $file.FullName | ConvertFrom-Json

            # Define the columns to keep
            $columnsToKeep = @(
                @{Name="Timestamp"; Expression={
                    # Parse the timestamp and format it to the desired format
                    $dateTime = [DateTime]::ParseExact($_.time, "yyyy-MM-ddTHH:mm:ss.fffffffK", [System.Globalization.CultureInfo]::InvariantCulture)
                    $dateTime.ToString("yyyy-MM-dd'T'HH:mm:ss.ffffff'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
                }},
                @{Name="SourceIP"; Expression={$_.properties.SourceIp}},
                @{Name="DestinationIP"; Expression={$_.properties.DestinationIp}},
                @{Name="DestinationURL"; Expression={$_.properties."DestinationFQDN"}},
                @{Name="User"; Expression={$_.properties.UserPrincipalName}},
                @{Name="TrafficOut"; Expression={$_.properties.SentBytes}},
                @{Name="TrafficIn"; Expression={$_.properties.ReceivedBytes}},
                @{Name="TrafficBytes"; Expression={$_.properties.SentBytes + $_.properties.ReceivedBytes}},
                @{Name="AllowDeny"; Expression={$_.properties.Action}}
            )

            # Select the required columns and add to the array
            $selectedData = $jsonData | Select-Object $columnsToKeep
            $allData += $selectedData
        }
        
        # Convert the data to CSV format without the header
        $csvContent = $allData | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1

        # Write the CSV content to the file
        $csvContent | Add-Content -Path $csvFilePath
        Write-EventLogEntry -message "JSON files processed and $csvFilePath created successfully. Total records processed: $($csvContent.count)"
    }
    catch {
        Write-EventLogEntry -message "An error occurred during JSON parsing: $_" -eventType "Error"
        throw
    }
    # Check the record count
    if ($csvContent.Count -eq 0) {
        Remove-Item -Path "$destinationPath\*" -Recurse -Force
        Write-EventLogEntry -message "No records to process. Stopping script." -eventType "Error"
        throw "No records found in the CSV content."
    }
}

function Copy-ToFTP {
    # Check if the Docker Service is already running.
    try {
       
        $service = Get-Service -Name $serviceName -ErrorAction Stop
    
        # Check if the service is running
        if ($service.Status -ne 'Running') {
            # Start the service if it is not running
            Start-Service -Name $serviceName -ErrorAction Stop
            Write-EventLogEntry -message "Service '$serviceName' was not running and has been started." -eventType "error"
    
            # Loop to check if the service has started
            while ($true) {
                Start-Sleep -Seconds 5
                $service = Get-Service -Name $serviceName -ErrorAction Stop
                if ($service.Status -eq 'Running') {
                    Write-EventLogEntry -message "Service '$serviceName' is now running." -eventType "Information"
                    break
                }
            }
        } else {
            Write-EventLogEntry -message "Service '$serviceName' is already running." -eventType "Information"
        }
    }
    catch {
        Write-EventLogEntry -message "An error occurred: $_" -eventType "Error"
    }

    # Check if Docker Desktop is running.
    try {
        $process = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
    
        if (-not $process) {
            # Start the process if it is not running
            Start-Process -FilePath $processPath -ErrorAction Stop
            Write-EventLogEntry -message "Process 'Docker Desktop' was not running and has been started." -eventType "error"
    
            # Loop to check if the process has started
            while ($true) {
                Start-Sleep -Seconds 5
                $process = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
                if ($process) {
                    Write-EventLogEntry -message "Process 'Docker Desktop' is now running." -eventType "Information"
                    break
                }
            }
        } else {
            Write-EventLogEntry -message "Process 'Docker Desktop' is already running." -eventType "Information"
        }
    }
    catch {
        Write-EventLogEntry -message "An error occurred: $_" -eventType "Error"
    }

    # Upload the CSV file to the FTP server
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $webclient = New-Object System.Net.WebClient
        $webclient.Credentials = New-Object System.Net.NetworkCredential($ftpUserName, $ftpPassword)
        $webclient.UploadFile($ftpUri, $csvFilePath)
        Write-EventLogEntry -message "$csvFilePath file uploaded to $ftpUri successfully."
    }
    catch {
        Write-EventLogEntry -message "An error occurred during FTP upload: $_" -eventType "Error"
        throw
    }
    # Delete all local files after processing
    try{
        
        Remove-Item -Path "$destinationPath\*" -Recurse -Force
        Write-EventLogEntry -message "$destinationPath deleted successfully."
    }
    catch {
        Write-EventLogEntry -message "An error occurred during local file deletion: $_" -eventType "Error"
        throw
    }    
}

Get-EntraLogs -ErrorAction Stop
Convert-EntraLogs -ErrorAction Stop
Copy-ToFTP -ErrorAction Stop
