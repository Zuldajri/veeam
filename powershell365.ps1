[CmdletBinding()]

Param(
  [string] $USERNAME,
  [string] $GuestOSName,
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

$fulluser = "$($GuestOSName)\$($USERNAME)"


#Configure logging
function log
{
   param([string]$message)
   "`n`n$(get-date -f o)  $message" 
}

try
{
	#Enable CredSSP	
	Enable-WSManCredSSP -Role Server –Force
	Enable-WSManCredSSP -Role Client -DelegateComputer ("*."+$adDomainName) -Force
	Enable-PSRemoting –force
	Set-Item WSMan:\localhost\Client\TrustedHosts * -Force

	#Set policy "Allow delegating fresh credentials with NTLM-only server authentication" 
	$allowed = @('WSMAN/*.'+ $adDomainName)
	$key = 'hklm:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
	if (!(Test-Path $key)) {
		md $key
	}  
	New-ItemProperty -Path $key -Name AllowFreshCredentialsWhenNTLMOnly  -Value 1 -PropertyType Dword -Force    
	$key = Join-Path $key 'AllowFreshCredentialsWhenNTLMOnly'
	if (!(Test-Path $key)) {
		md $key
	}
	$i = 1
	$allowed |% {
		# Script does not take into account existing entries in this key
		New-ItemProperty -Path $key -Name $i -Value $_ -PropertyType String -Force
		$i++
	}

    #Create a credential
    log "Creating credentials"
    $secpasswd = ConvertTo-SecureString $adminPassword -AsPlainText -Force
    $AdminUser = $adminUsername + "@" + $adDomainName
    $mycreds = New-Object System.Management.Automation.PSCredential ($AdminUser, $secpasswd)

    #Impersonate user
    log "Impersonate user '$AdminUser'"
    .\New-ImpersonateUser.ps1 -Credential $mycreds






Connect-VBOServer 
$Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.DriveLetter -like "F*"}
$VeeamDrive = $DriveLetter.DriveLetter
$repo = "$($VeeamDrive)\backup repository"
New-Item -ItemType Directory -path $repo -ErrorAction SilentlyContinue
$proxy = Get-VBOProxy

Add-VBORepository -Proxy $proxy -Name "Default Backup Repository 1" -Path "F:\backup repository" -Description "Default Backup Repository 1" -RetentionType ItemLevel
  





 
