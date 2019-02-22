#Variables
$URI = "http://download.veeam.com/VeeamBackup&Replication_9.5.4.2615.Update4.iso"

#Get VCC iso
Invoke-WebRequest -UseBasicparsing -Uri $URI -OutFile VeeamBackupReplication.iso

Get-Disk | ` 
Where partitionstyle -eq 'raw' | ` 
Initialize-Disk -PartitionStyle MBR -PassThru | ` 
New-Partition -AssignDriveLetter -UseMaximumSize | ` 
Format-Volume -FileSystem NTFS -NewFileSystemLabel "datadisk" -Confirm:$false

$iso = Get-ChildItem -Path "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Downloads\0\VeeamBackupReplication.iso"

