#Variables
$URI = "http://download.veeam.com/VeeamBackup&Replication_9.5.4.2615.Update4.iso"

#Get VCC iso
Invoke-WebRequest -UseBasicparsing -Uri $URI -OutFile VeeamBackupReplication.iso

$disks = Get-Disk | sort number
$letters = 70..89 | ForEach-Object { [char]$_ }
$count = 0
$labels = "data1","data2"

foreach ($disk in $disks) {
       $driveLetter = $letters[$count].ToString()
       $disk | 
       New-Partition -UseMaximumSize -DriveLetter $driveLetter |
       Format-Volume -FileSystem NTFS -NewFileSystemLabel $labels[$count] -Confirm:$false -Force
    $count++
    }

    $iso = Get-ChildItem -Path "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.3\Downloads\0\VeeamBackupReplication.iso"

