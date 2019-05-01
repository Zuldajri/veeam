[CmdletBinding()]

# Modify the $url 


#Variables
$url = "http://download.veeam.com/VeeamBackupOffice365_3.0.0.422.zip"
$output = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Downloads\0\VeeamBackupOffice365_3.0.0.422.zip"

#Get Veeam Backup for Office 365 zip
(New-Object System.Net.WebClient).DownloadFile($url, $output)
Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

#Initialize Data Disks
Get-Disk | ` 
Where partitionstyle -eq 'raw' | ` 
Initialize-Disk -PartitionStyle MBR -PassThru | ` 
New-Partition -AssignDriveLetter -UseMaximumSize | ` 
Format-Volume -FileSystem NTFS -NewFileSystemLabel "datadisk" -Confirm:$false

Expand-Archive VeeamBackupOffice365_3.0.0.422.zip -DestinationPath C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Downloads\0\ -Force

  
  ## Veeam Backup Office 365
  
  msiexec /i Veeam.Backup365_3.0.0.422.msi /qn ADDLOCAL=BR_OFFICE365,CONSOLE_OFFICE365, PS_OFFICE365 ACCEPT_THIRDPARTY_LICENSES=1 ACCEPT_EULA=1
  
  ## Veeam Explorer for Microsoft Exchange
  msiexec /i VeeamExplorerForExchange_3.0.0.422.msi /qn ADDLOCAL=BR_EXCHANGEEXPLORER, PS_EXCHANGEEXPLORER ACCEPT_THIRDPARTY_LICENSES=1 ACCEPT_EULA=1
  
  ## Veeam Explorer for Microsoft SharePoint
  msiexec /i VeeamExplorerForSharePoint_3.0.0.422.msi /qn ADDLOCAL=BR_SHAREPOINTEXPLORER, PS_SHAREPOINTEXPLORER ACCEPT_THIRDPARTY_LICENSES=1 ACCEPT_EULA=1
  
  
