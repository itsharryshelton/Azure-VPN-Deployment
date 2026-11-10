<#
.SYNOPSIS
    Adds a VPN Connection to the Azure VPN Client.
.DESCRIPTION
    Adds a VPN Connection to the Azure VPN Client. Replaces a current VPN Connection if it has the same name. Does not remove other existing VPN Connections.

    Rasphone Data is pulled from %LOCALAPPDATA%\Packages\Microsoft.AzureVpn_[VERSION ID MIGHT CHANGE]\LocalState\rasphone.pbk

    SECURITY NOTE: The ThirdPartyProfileInfo lines are the profile XML encoded as hex, and that includes the gateway's server secret. Handle the script as sensitive (Intune/RMM, not email or a public share).


.PARAMETER ScriptLogLocation
    The directory in which you would like the log file
.PARAMETER LogFileName
    The name (with extension) you would like for the log file 
.PARAMETER AzureVPNClientDirectory
    The full path to the directory in which the Azure VPN Client stores information.
.PARAMETER LocalStateDirectory
    The full path to the directory where the log files directory and rasphone.pbk file are stored.
.PARAMETER RASPhoneFile
    The full path of the rasphone.pbk file used by Azure VPN Client.
.PARAMETER NewVPNHeader
    The header in the rasphone.pbk file for the the VPN that will be added or replaced. This should match the first line of the RASPhoneEntry.
.PARAMETER RASPhoneEntry
    The full entry that will be added to the rasphone.pbk file.
.INPUTS
    None
.OUTPUTS
    Log file stored in C:\ExampleFolder\Add-AzureVPNConnection\Add-AzureVPNConnection.log
#>
param(
[string]$ScriptLogLocation = "C:\ExampleFolder\Add-AzureVPNConnection",
[string]$LogFileName = "Add-AzureVPNConnection.log",
[string]$AzureVPNClientDirectory = "$env:LOCALAPPDATA\Packages\Microsoft.AzureVpn_8wekyb3d8bbwe",
[string]$LocalStateDirectory = (Join-Path $AzureVPNClientDirectory "LocalState"),
[string]$RASPhoneFile = (Join-Path $LocalStateDirectory "rasphone.pbk"),
[string]$NewVPNHeader = "[CUSTOMER NAME - Client VPN]",
[string]$RASPhoneEntry =
@'
==== REPLACE ME WITH THE FULL ENTRY FOR THE VPN CONNECTION YOU WANT TO ADD =====
Do not remove the first line (the header) or the last line (the empty line). The header should match the NewVPNHeader parameter.


'@
)

# Logging + Install Checks
Start-Transcript -Path (Join-Path $ScriptLogLocation $LogFileName) -Append
$IsInstalled = Test-Path -LiteralPath $AzureVPNClientDirectory
$VPNsExist = Test-Path -LiteralPath $RASPhoneFile

if($IsInstalled -and !$VPNsExist){ # Installed but no VPNs configured
    Write-Host "The Azure VPN Client is installed and no VPNs exist. Creating the rasphone.pbk file and adding this connection."
    # Create the rasphone.pbk file with the connection information
    $Utf8Encoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($RASPhoneFile, $RASPhoneEntry, $Utf8Encoding)
}
elseif($IsInstalled -and $VPNsExist){ # Installed and VPNs Exist
    Write-Host "The Azure VPN Client is installed and some VPNs exist. Adding this VPN connection."
    $BackupFileNameBase = "rasphone_backup"
    $BackupFileExtension = ".pbk"
    $i=0
    Do{
        $i++
        $iFormatted = "{0:D2}" -f [int32]$i
        $BackupFileName = "$BackupFileNameBase$iFormatted$BackupFileExtension"
        $FullBackupPath = Join-Path $LocalStateDirectory $BackupFileName  
    }While(Test-Path -LiteralPath $FullBackupPath)
    
    #Create a new backup with the unused backup name
    Copy-Item -LiteralPath $RASPhoneFile -Destination $FullBackupPath

    # Load the file's content into an array
    $FileContent = Get-Content -LiteralPath $FullBackupPath
    
    # Loop through the content one line at a time to find the different VPN setups
    #   Each VPN has a "header" like [VPN Name] then is followed by the settings
    $CurrentVPNs = @()
    For($i=0;$i -lt $FileContent.count;$i++){
        # If this line of the file is a VPN "header" then add that VPN to the array of VPNs
        if($FileContent[$i] -like "[[]*[]]"){
            $CurrentVPNs += [PSCustomObject]@{
                Header = $FileContent[$i]
                StartLine = $i
                EndLine = $null
            }
            # Update the EndLine of the previous VPN if this isn't the first VPN found
            if($CurrentVPNs.count -gt 1){
                $CurrentVPNs[$CurrentVPNs.count-2].EndLine = $i-1
            }
        }
        # If this is the last line of the file, update the last VPNs EndLine
        if($i -eq $FileContent.Count-1){
            $CurrentVPNs[$CurrentVPNs.count-1].EndLine = $i
        }
    }

    # Check if any of the current VPNs have the same name as the new VPN, if not add them to the new array
    $NewVPNs = $null
    Foreach($VPN in $CurrentVPNs){
        if($VPN.Header -ne $NewVPNHeader){
            $NewVPNs += $FileContent[$VPN.StartLine..$VPN.EndLine]
        }
        elseif($VPN.Header -eq $NewVPNHeader){
            $Utf8Encoding = New-Object System.Text.UTF8Encoding $False
            [System.IO.File]::WriteAllLines($RASPhoneFile, $RASPhoneEntry, $Utf8Encoding)
        }
        else{
            Write-Error -Message "Something unexpected happened."
        }

        # Overwrite the existing file with the new VPN information
        $Utf8Encoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($RASPhoneFile, $RASPhoneEntry, $Utf8Encoding)
        if($NewVPNs){
            $NewVPNs | Out-File -LiteralPath $RASPhoneFile -Encoding "UTF8" -Append -Force
        }
    }
}
elseif(!$IsInstalled){ # Client isn't installed
    Write-Host "The Azure VPN Client is not installed. Creating the directories, the rasphone.pbk file, and adding this connection."
    
    if(Test-Path -Path $LocalStateDirectory){
        Write-Host "The LocalState directory already exists."
    }
    else{
        Write-Host "Creating the LocalState directory."
        New-Item -ItemType Directory -Path $LocalStateDirectory
    }
    # Create a rasphone.pbk file with the connection information
    $Utf8Encoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($RASPhoneFile, $RASPhoneEntry, $Utf8Encoding)
}
else{
    Write-Error -Message "Something unexpected happened."
}

# Stop Logging
Stop-Transcript