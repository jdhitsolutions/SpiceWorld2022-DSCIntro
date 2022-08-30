#requires -version 5.1

# Run this from a Windows 10 or Windows 11 client under Windows PowerShell 5.1

#demo files at https://github.com/jdhitsolutions/SpiceWorld2022-DSCIntro

return "This is a demo script file."

<# demo prep

Invoke-Command { 
 [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

 Install-Module PowerShellGet -force

 Remove-DscConfigurationDocument -Stage Previous
 Remove-DscConfigurationDocument -Stage Current

 #my test servers had the module copied not installed
 $p = 'C:\Program Files\WindowsPowerShell\Modules\ComputerManagementDSC'
 if (Test-Path $p) {
   Remove-Item $p -force -recurse
 }

} -computername SRV1,SRV2

Invoke-Command { 
 Get-Module ComputerManagementDSC -ListAvailable
} -computername SRV1,SRV2

#>


#region DSC Resources

cls

#the newer version of this module requires PowerShell 6
Import-Module PSDesiredStateConfiguration -RequiredVersion 1.1
Get-Command -module PSDesiredStateConfiguration

Get-DscResource
Get-DscResource WindowsFeature
Get-DscResource WindowsFeature -Syntax

#what resources are in an existing DSC resource module
Get-DscResource -module ComputermanagementDSC

#find resources online
#no wildcards :-(
Find-DSCResource -name smbshare
Find-DSCResource -module ComputerManagementDSC 
Find-Module ComputerManagementDSC -OutVariable cm
start $cm.projecturi
cls
#use tags
Find-DscResource -Tag activedirectory

Find-DscResource -Tag PowerShell
Install-Module powershellModule -force

Get-DscResource PSModuleResource -Syntax

Uninstall-Module PowershellModule

cls

#endregion
#region Creating a basic config

psedit .\basic.ps1

#we don't have time to look at configuring with credentials

. .\basic.ps1
Get-Command -CommandType Configuration
help BasicServer

cls

#endregion
#region Deploying resources

#deploy modules however you want
Invoke-command -ComputerName SRV1 -ScriptBlock { 
 [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 Install-PackageProvider -Name nuget -ForceBootstrap -Force
 Install-Module ComputerManagementDSC -RequiredVersion 8.5.0 -force -Repository PSGallery
 Get-Module ComputerManagementDSC -ListAvailable | Select Name,Version
}

cls
#endregion
#region Deploying the configuration

#build the mof
BasicServer -Computername SRV1 -OutputPath .
psedit .\BasicServer\SRV1.mof

Start-DscConfiguration -path .\BasicServer -ComputerName SRV1 -Wait -Verbose -force

cls
#endregion
#region Getting and Testing configuration status

Get-DscConfigurationStatus -CimSession SRV1 -all
Test-DscConfiguration -ComputerName SRV1
Test-DscConfiguration -ComputerName SRV1 -Detailed | Format-List

Get-DscConfiguration -CimSession SRV1

cls
#endregion
#region The LCM

#get settings
Get-DscLocalConfigurationManager -CimSession SRV1
#configure settings

psedit .\basic-lcm.ps1
. .\basic-lcm.ps1
#build the meta-mof
BasicServerLCM -Computername SRV1 -OutputPath .

#push meta-mof first
Set-DscLocalConfigurationManager -Path .\BasicServerLCM -ComputerName SRV1 -Force -Verbose
Get-DscLocalConfigurationManager -CimSession SRV1
#push configuration
Start-DscConfiguration -path .\BasicServerLCM -ComputerName SRV1 -Wait -Verbose -force

Get-DscConfigurationStatus -CimSession SRV1

cls
#endregion
#region configuration data

psedit .\CompanyServer.ps1
psedit .\config.psd1

. .\CompanyServer.ps1
help CompanyServer
CompanyServer -ConfigurationData .\config.psd1 -OutputPath .
psedit .\CompanyServer\SRV1.mof

#verify resources
Invoke-Command { Get-Module ComputermanagementDSC -list } -computername SRV1,SRV2
Invoke-Command {  
 [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 Install-PackageProvider -Name nuget -ForceBootstrap -Force
 Install-Module ComputerManagementDSC -RequiredVersion 8.5.0 -force -Repository PSGallery
 Get-Module ComputerManagementDSC -ListAvailable | Select Name,Version
} -computername SRV2

Start-DscConfiguration -Path .\CompanyServer -Wait -Force -Verbose
Test-DscConfiguration -ComputerName SRV1,SRV2 -Detailed

cls
#endregion
#region Logging and Troubleshooting

Get-WinEvent -ListLog *dsc*

Get-WinEvent Microsoft-Windows-DSC/Operational -ComputerName srv1 -MaxEvents 10 -OutVariable log
$log | format-list

Enter-PSSession -ComputerName SRV1 

dir C:\Windows\System32\Configuration\ConfigurationStatus | sort lastwritetime

dir C:\Windows\System32\Configuration\ConfigurationStatus\*details.json| sort lastwritetime |
Select -last 1 | Get-Content -Encoding Unicode | ConvertFrom-Json

cls

#documents
cd C:\windows\system32\Configuration
dir
get-content .\Current.mof

help Remove-DscConfigurationDocument

Remove-DscConfigurationDocument -Stage Current -WhatIf

exit

cls
#endregion
#region Invoke-DSCResource

Help Invoke-DSCResource

Get-DscResource file -Syntax

#needs to run ON the remote server
enter-pssession -ComputerName SRV2
cd \

#define a hashtable of DSC resource properties
$p = @{
DestinationPath = "C:\Work"
Ensure = "Present"
Type = "Directory"
}

Invoke-DscResource -Name file -Method Test -Property $p -ModuleName PSDesiredStateConfiguration -Verbose
Invoke-DscResource -Name file -Method Get -Property $p -ModuleName PSDesiredStateConfiguration -Verbose

$q = @{
DestinationPath = "c:\work\foo.txt"
Ensure = "present"
type = "file"
contents = "I am the walrus"
}

Invoke-DscResource -Name file -Method Test -Property $q -ModuleName PSDesiredStateConfiguration -Verbose
Invoke-DscResource -Name file -Method Set -Property $q -ModuleName PSDesiredStateConfiguration -Verbose
#re-test
Invoke-DscResource -Name file -Method Get -Property $q -ModuleName PSDesiredStateConfiguration -Verbose

Get-DscConfigurationStatus
dir c:\work 
get-content C:\work\foo.txt
exit

cls
#endregion

<#
Reset demo for SRV1
Invoke-command -computername SRV1 -scriptblock {
 remove-smbshare CorpWork -Force
 remove-item c:\work -Force -recurse
 Remove-WindowsFeature File-Services,print-Services,RSAT-AD-Tools,Windows-Server-Backup,SNMP-Service
 Add-WindowsFeature PowerShell-V2
 set-service bits -StartupType manual
 restart-computer -force
}

#>