#Variables
$url = "http://download.veeam.com/VeeamBackup&Replication_9.5.4.2615.Update4.iso"
$output = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Downloads\0\VeeamBackupReplication.iso"

#Get VCC iso
(New-Object System.Net.WebClient).DownloadFile($url, $output)
Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

#Initialize Data Disks
Get-Disk | ` 
Where partitionstyle -eq 'raw' | ` 
Initialize-Disk -PartitionStyle MBR -PassThru | ` 
New-Partition -AssignDriveLetter -UseMaximumSize | ` 
Format-Volume -FileSystem NTFS -NewFileSystemLabel "datadisk" -Confirm:$false

$iso = Get-ChildItem -Path "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Downloads\0\VeeamBackupReplication.iso"

