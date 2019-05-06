[CmdletBinding()]

Param(
  [string]$USERNAME,
  [string]$GuestOSName,
  [string]$PASSWORD
 )

#Configure logging
function log
{
   param([string]$message)
   "`n`n$(get-date -f o)  $message" 
}

try
{
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


#Enable CredSSP	
Enable-WSManCredSSP -Role Server –Force
#Enable-WSManCredSSP -Role Client -DelegateComputer $GuestOSName -Force
Enable-PSRemoting –force
Set-Item WSMan:\localhost\Client\TrustedHosts * -Force

#Set policy "Allow delegating fresh credentials with NTLM-only server authentication" 
$allowed = @('WSMAN/'+ $GuestOSName)
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
    $secpasswd = ConvertTo-SecureString $PASSWORD -AsPlainText -Force
    $mycreds = New-Object System.Management.Automation.PSCredential ($fulluser, $secpasswd)

    #Impersonate user
    log "Impersonate user '$fulluser'"
    .\New-ImpersonateUser.ps1 -Credential $mycreds


$Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.DriveLetter -like "F*"}
$VeeamDrive = $DriveLetter.DriveLetter
$repo = "$($VeeamDrive)\backup repository"
New-Item -ItemType Directory -path $repo -ErrorAction SilentlyContinue

  
$scriptblock= {
Connect-VBOServer
$proxy = Get-VBOProxy 
Add-VBORepository -Proxy $proxy -Name "Default Backup Repository 1" -Path "F:\backup repository" -Description "Default Backup Repository 1" -RetentionType ItemLevel
}

$session = New-PSSession -cn $env:computername -Credential $mycreds -Authentication Credssp
	Invoke-Command -Session $session -ScriptBlock $scriptblock
	Remove-PSSession -VMName $env:computername

}
catch
{
    log "ERROR: Exception caught - '$_.Exception.Message' - '$_.Exception.ItemName'"
    throw
}
finally
{
    log "End Impersonate user '$AdminUser'"
    remove-ImpersonateUser
    log "All Done"
}


 
