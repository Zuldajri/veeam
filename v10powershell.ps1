[CmdletBinding()]

# Modify the $VCCISOURI with the latest link 

Param(
    [string] $VMName, 
    [string] $GuestOSName,
    [string] $StorageAccountName,
    [string] $StorageAccountKey,
    [string] $USERNAME,
    [string] $PASSWORD
 )

#Variables
$url = "http://download.veeam.com/VeeamBackup&Replication_10.0.0.4461.iso"
$output = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\VeeamBackupReplication.iso"

#Get VCC iso
(New-Object System.Net.WebClient).DownloadFile($url, $output)
Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

#Initialize Data Disks
Get-Disk | ` 
Where partitionstyle -eq 'raw' | ` 
Initialize-Disk -PartitionStyle GPT -PassThru | ` 
New-Partition -AssignDriveLetter -UseMaximumSize | ` 
Format-Volume -FileSystem ReFS -NewFileSystemLabel "datadisk" -Confirm:$false




$iso = Get-ChildItem -Path "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\VeeamBackupReplication.iso"
Mount-DiskImage $iso.FullName

Write-Output -InputObject "[$($VMName)]:: Installing Veeam Unattended"
  
$setup = $(Get-DiskImage -ImagePath $iso.FullName | Get-Volume).DriveLetter +':' 
$setup


$source = $setup


$Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.DriveLetter -like "F*"}
$VeeamDrive = $DriveLetter.DriveLetter


  #region: Variables
$fulluser = "$($GuestOSName)\$($USERNAME)"
$secpasswd = ConvertTo-SecureString $PASSWORD -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential($fulluser, $secpasswd)
$CatalogPath = "$($VeeamDrive)\VbrCatalog"
$vPowerPath = "$($VeeamDrive)\vPowerNfs"

 #region: logdir
 $logdir = "$($VeeamDrive)\logdir"
 $trash = New-Item -ItemType Directory -path $logdir  -ErrorAction SilentlyContinue
 #endregion

  ## Global Prerequirements
  Write-Host "Installing Global Prerequirements ..." -ForegroundColor Yellow
  ### 2012 System CLR Types
  Write-Host "    Installing 2012 System CLR Types ..." -ForegroundColor Yellow
  $MSIArguments = @(
      "/i"
      "$source\Redistr\x64\SQLSysClrTypes.msi"
      "/qn"
      "/norestart"
      "/L*v"
      "$logdir\01_CLR.txt"
  )
  Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

  if (Select-String -path "$logdir\01_CLR.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

  ### 2012 Shared management objects
  Write-Host "    Installing 2012 Shared management objects ..." -ForegroundColor Yellow
  $MSIArguments = @(
      "/i"
      "$source\Redistr\x64\SharedManagementObjects.msi"
      "/qn"
      "/norestart"
      "/L*v"
      "$logdir\02_Shared.txt"
  )
  Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

  if (Select-String -path "$logdir\02_Shared.txt" -pattern "Installation success or error status: 0.") {
      Write-Host "    Setup OK" -ForegroundColor Green
      }
      else {
          throw "Setup Failed"
          }

  ### SQL Express
          ### Info: https://msdn.microsoft.com/en-us/library/ms144259.aspx
          Write-Host "    Installing SQL Express ..." -ForegroundColor Yellow
          $Arguments = "/HIDECONSOLE /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /FEATURES=SQLEngine,SNAC_SDK /INSTANCENAME=VEEAMSQL2016 /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$fulluser`" `"Builtin\Administrators`" /TCPENABLED=1 /NPENABLED=1 /UpdateEnabled=0"
          Start-Process "$source\Redistr\x64\SqlExpress\2016SP2\SQLEXPR_x64_ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow
  
  ## Veeam Backup & Replication
  Write-Host "Installing Veeam Backup & Replication ..." -ForegroundColor Yellow
  ### Backup Catalog
  Write-Host "    Installing Backup Catalog ..." -ForegroundColor Yellow
  $trash = New-Item -ItemType Directory -path $CatalogPath -ErrorAction SilentlyContinue
  $MSIArguments = @(
      "/i"
      "$source\Catalog\VeeamBackupCatalog64.msi"
      "/qn"
      "ACCEPT_THIRDPARTY_LICENSES=1"
      "/L*v"
      "$logdir\04_Catalog.txt"
      "VM_CATALOGPATH=$CatalogPath"
      "VBRC_SERVICE_USER=$fulluser"
      "VBRC_SERVICE_PASSWORD=$PASSWORD"
  )
  Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

  if (Select-String -path "$logdir\04_Catalog.txt" -pattern "Installation success or error status: 0.") {
      Write-Host "    Setup OK" -ForegroundColor Green
      }
      else {
          throw "Setup Failed"
          }


 ### Backup Server
 Write-Host "    Installing Backup Server ..." -ForegroundColor Yellow
 $trash = New-Item -ItemType Directory -path $vPowerPath -ErrorAction SilentlyContinue
 $MSIArguments = @(
     "/i"
     "$source\Backup\Server.x64.msi"
     "/qn"
     "ACCEPT_THIRDPARTY_LICENSES=1"
     "/L*v"
     "$logdir\05_Backup.txt"
     "ACCEPTEULA=YES"
     "VBR_SERVICE_USER=$fulluser"
     "VBR_SERVICE_PASSWORD=$PASSWORD"
     "PF_AD_NFSDATASTORE=$vPowerPath"
     "VBR_SQLSERVER_SERVER=$env:COMPUTERNAME\VEEAMSQL2016"
 )
 Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

 if (Select-String -path "$logdir\05_Backup.txt" -pattern "Installation success or error status: 0.") {
     Write-Host "    Setup OK" -ForegroundColor Green
     }
     else {
         throw "Setup Failed"
         }

 ### Backup Console
 Write-Host "    Installing Backup Console ..." -ForegroundColor Yellow
 $MSIArguments = @(
     "/i"
     "$source\Backup\Shell.x64.msi"
     "/qn"
     "/L*v"
     "$logdir\06_Console.txt"
     "ACCEPTEULA=YES"
     "ACCEPT_THIRDPARTY_LICENSES=1"
 )
 Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

 if (Select-String -path "$logdir\06_Console.txt" -pattern "Installation success or error status: 0.") {
     Write-Host "    Setup OK" -ForegroundColor Green
     }
     else {
         throw "Setup Failed"
         }



### Explorers
Write-Host " Installing Explorer For ActiveDirectory ..." -ForegroundColor Yellow
$MSIArguments = @(
"/i"
"$source\Explorers\VeeamExplorerForActiveDirectory.msi"
"/qn"
"/L*v"
"$logdir\07_ExplorerForActiveDirectory.txt"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
if (Select-String -path "$logdir\07_ExplorerForActiveDirectory.txt" -pattern "Installation success or error status: 0.") {
Write-Host " Setup OK" -ForegroundColor Green
}
else {
throw "Setup Failed"
}



Write-Host " Installing Explorer For Exchange ..." -ForegroundColor Yellow
$MSIArguments = @(
"/i"
"$source\Explorers\VeeamExplorerForExchange.msi"
"/qn"
"/L*v"
"$logdir\08_VeeamExplorerForExchange.txt"
"ADDLOCAL=BR_EXCHANGEEXPLORER,PS_EXCHANGEEXPLORER"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
if (Select-String -path "$logdir\08_VeeamExplorerForExchange.txt" -pattern "Installation success or error status: 0.") {
Write-Host " Setup OK" -ForegroundColor Green
}
else {
throw "Setup Failed"
}

Write-Host " Installing Explorer For SQL ..." -ForegroundColor Yellow
$MSIArguments = @(
"/i"
"$source\Explorers\VeeamExplorerForSQL.msi"
"/qn"
"/L*v"
"$logdir\09_VeeamExplorerForSQL.txt"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
if (Select-String -path "$logdir\09_VeeamExplorerForSQL.txt" -pattern "Installation success or error status: 0.") {
Write-Host " Setup OK" -ForegroundColor Green
}
else {
throw "Setup Failed"
}

Write-Host " Installing Explorer For SharePoint ..." -ForegroundColor Yellow
$MSIArguments = @(
"/i"
"$source\Explorers\VeeamExplorerForSharePoint.msi"
"/qn"
"/L*v"
"$logdir\11_VeeamExplorerForSharePoint.txt"
"ADDLOCAL=BR_SHAREPOINTEXPLORER,PS_SHAREPOINTEXPLORER"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
if (Select-String -path "$logdir\11_VeeamExplorerForSharePoint.txt" -pattern "Installation success or error status: 0.") {
Write-Host " Setup OK" -ForegroundColor Green
}
else {
throw "Setup Failed"
}

$scriptblock= {
Add-PSSnapin VeeamPSSnapin
Connect-VBRServer
Add-VBRAzureBlobAccount -Name $Using:StorageAccountName -SharedKey $Using:StorageAccountKey
$account = Get-VBRAzureBlobAccount 
$connect = Connect-VBRAzureBlobService -Account $account -RegionType Global
$container = Get-VBRAzureBlobContainer -Connection $connect | Where {$_.name -Match "bootdiagnostics-$Using:GuestOSName*"}
New-VBRAzureBlobFolder -Container $container -Connection $connect -Name "VeeamObject"
New-VBRAzureBlobFolder -Container $container -Connection $connect -Name "VeeamExternal"
$folder1 = Get-VBRAzureBlobFolder -Container $container -Connection $connect -Name "VeeamObject"
$folder2 = Get-VBRAzureBlobFolder -Container $container -Connection $connect -Name "VeeamExternal"
Add-VBRAzureBlobRepository -AzureBlobFolder $folder1 -Connection $connect
Add-VBRAzureExternalRepository -Name "AzureExternalRepo" -Description "New external repository" -AzureBlobFolder $folder2 -Connection $connect
}

$session = New-PSSession -cn $env:computername -Credential $mycreds 
	Invoke-Command -Session $session -ScriptBlock $scriptblock 
	Remove-PSSession -VMName $env:computername
