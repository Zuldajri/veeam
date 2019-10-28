[CmdletBinding()]

# Modify the $VCCISOURI with the latest link from https://github.com/exospheredata/veeam#cookbooks 

Param(
    [string]$VMName, 
    [string]$GuestOSName,
    [string]$USERNAME,
    [string]$PASSWORD
)

#Variables
$url = "http://download.veeam.com/VeeamBackup&Replication_9.5.4.2866.Update4b_.iso"
$output = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.5\Downloads\0\VeeamBackupReplication.iso"

#Get VCC iso
(New-Object System.Net.WebClient).DownloadFile($url, $output)
Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

#Initialize Data Disks
Get-Disk | ` 
Where partitionstyle -eq 'raw' | ` 
Initialize-Disk -PartitionStyle MBR -PassThru | ` 
New-Partition -AssignDriveLetter -UseMaximumSize | ` 
Format-Volume -FileSystem NTFS -NewFileSystemLabel "datadisk" -Confirm:$false

$iso = Get-ChildItem -Path "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.5\Downloads\0\VeeamBackupReplication.iso"
Mount-DiskImage $iso.FullName
