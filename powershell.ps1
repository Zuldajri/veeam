#Variables
$URI = "http://download.veeam.com/VeeamBackup&Replication_9.5.4.2615.Update4.iso"

#Get VCC iso
Invoke-WebRequest -UseBasicparsing -Uri $URI -OutFile VeeamBackupReplication.iso

