[CmdletBinding()]

Param(
  [string] $GuestOSName,
  [string] $StorageAccountName,
  [string] $StorageAccountKey,
  [string] $USERNAME,
  [string] $PASSWORD
 )


# Modify the $url 
#Variables
$url = "http://download.veeam.com/VeeamBackupOffice365_4.0.0.2516.zip"
$output = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\VeeamBackupOffice365_4.0.0.2516.zip"

#Get Veeam Backup for Office 365 zip
(New-Object System.Net.WebClient).DownloadFile($url, $output)


#Initialize Data Disks
Get-Disk | ` 
Where partitionstyle -eq 'raw' | ` 
Initialize-Disk -PartitionStyle GPT -PassThru | ` 
New-Partition -AssignDriveLetter -UseMaximumSize | ` 
Format-Volume -FileSystem ReFS -NewFileSystemLabel "datadisk" -Confirm:$false

Expand-Archive C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\VeeamBackupOffice365_4.0.0.2516.zip -DestinationPath C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\ -Force

$source = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension"

### Veeam Backup Office 365
$MSIArguments = @(
"/i"
"$source\Veeam.Backup365_4.0.0.2516.msi"
"/qn"
"/norestart"
"ADDLOCAL=BR_OFFICE365,CONSOLE_OFFICE365,PS_OFFICE365"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

Sleep 60

### Veeam Explorer for Microsoft Exchange
$MSIArguments = @(
"/i"
"$source\VeeamExplorerForExchange_10.0.0.443.msi"
"/qn"
"/norestart"
"ADDLOCAL=BR_EXCHANGEEXPLORER,PS_EXCHANGEEXPLORER"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

Sleep 60


### Veeam Explorer for Microsoft SharePoint
$MSIArguments = @(
"/i"
"$source\VeeamExplorerForSharePoint_10.0.0.443.msi"
"/qn"
"/norestart"
"ADDLOCAL=BR_SHAREPOINTEXPLORER,PS_SHAREPOINTEXPLORER"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

Sleep 60


#Create a credential
#log "Creating credentials"
$fulluser = "$($GuestOSName)\$($USERNAME)"
$secpasswd = ConvertTo-SecureString $PASSWORD -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential($fulluser, $secpasswd)
$seckey = ConvertTo-SecureString $StorageAccountKey -AsPlainText -Force




$Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.DriveLetter -like "F*"}
$VeeamDrive = $DriveLetter.DriveLetter
$repo = "$($VeeamDrive)\backup repository"
New-Item -ItemType Directory -path $repo -ErrorAction SilentlyContinue



$scriptblock= {
Import-Module Veeam.Archiver.PowerShell
Connect-VBOServer
$proxy = Get-VBOProxy 
Add-VBOAzureBlobAccount -Name $Using:StorageAccountName -SharedKey $Using:seckey
$account = Get-VBOAzureBlobAccount 
$connection = New-VBOAzureBlobConnectionSettings -Account $account -RegionType Global
$container = Get-VBOAzureBlobContainer -ConnectionSettings $connection
Add-VBOAzureBlobFolder -Container $container -Name "Veeam"
$folder = Get-VBOAzureBlobFolder -Container $container
Add-VBOAzureBlobObjectStorageRepository -Folder $folder -Name "VBORepository"
$objectstorage = Get-VBOObjectStorageRepository
Add-VBORepository -Proxy $proxy -Name "Default Backup Repository 1" -Path "F:\backup repository" -ObjectStorageRepository $objectStorage -Description "Default Backup Repository 1" -RetentionType ItemLevel
$repository = Get-VBORepository -Name "Default Backup Repository"
Remove-VBORepository -Repository $repository -Confirm:$false
}

$session = New-PSSession -cn $env:computername -Credential $mycreds 
	Invoke-Command -Session $session -ScriptBlock $scriptblock 
	Remove-PSSession -VMName $env:computername
