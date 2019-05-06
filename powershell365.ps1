[CmdletBinding()]

Param(
  [string] $USERNAME,
  [string]$GuestOSName,
  [string] $PASSWORD
 )

# Modify the $url 

#Variables
$url = "http://download.veeam.com/VeeamBackupOffice365_3.0.0.422.zip"
$output = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Downloads\0\VeeamBackupOffice365_3.0.0.422.zip"

#Get Veeam Backup for Office 365 zip
(New-Object System.Net.WebClient).DownloadFile($url, $output)

#Initialize Data Disks
Get-Disk | ` 
Where partitionstyle -eq 'raw' | ` 
Initialize-Disk -PartitionStyle MBR -PassThru | ` 
New-Partition -AssignDriveLetter -UseMaximumSize | ` 
Format-Volume -FileSystem NTFS -NewFileSystemLabel "datadisk" -Confirm:$false

Expand-Archive C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Downloads\0\VeeamBackupOffice365_3.0.0.422.zip -DestinationPath C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Downloads\0\ -Force

$source = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Downloads\0\"

### Veeam Backup Office 365
$MSIArguments = @(
"/i"
"$source\Veeam.Backup365_3.0.0.422.msi"
"/qn"
"ADDLOCAL=BR_OFFICE365,CONSOLE_OFFICE365,PS_OFFICE365"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

### Veeam Explorer for Microsoft Exchange
$MSIArguments = @(
"/i"
"$source\VeeamExplorerForExchange_3.0.0.422.msi"
"/qn"
"ADDLOCAL=BR_EXCHANGEEXPLORER,PS_EXCHANGEEXPLORER"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

### Veeam Explorer for Microsoft SharePoint
$MSIArguments = @(
"/i"
"$source\VeeamExplorerForSharePoint_3.0.0.422.msi"
"/qn"
"ADDLOCAL=BR_SHAREPOINTEXPLORER,PS_SHAREPOINTEXPLORER"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

#Create a credential
#log "Creating credentials"
$secpasswd = ConvertTo-SecureString $PASSWORD -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential("$env:USERDOMAIN\$USERNAME", $secpasswd)

#Impersonate user
#log "Impersonate user '$AdminUser'"
#.\New-ImpersonateUser.ps1 -Credential $mycreds


Connect-VBOServer -Credential $mycreds
$Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.DriveLetter -like "F*"}
$VeeamDrive = $DriveLetter.DriveLetter
$repo = "$($VeeamDrive)\backup repository"
New-Item -ItemType Directory -path $repo -ErrorAction SilentlyContinue
$proxy = Get-VBOProxy

Add-VBORepository -Proxy $proxy -Name "Default Backup Repository 1" -Path "F:\backup repository" -Description "Default Backup Repository 1" -RetentionType ItemLevel
  





 
