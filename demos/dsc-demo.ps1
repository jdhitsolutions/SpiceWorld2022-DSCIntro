#requires -version 5.1

return "$([char]27)[1;91mThis is a demo script file.$([char]27)[0m"

#region DSC Resources

Get-Command -module PSDesiredStateConfiguration

Get-DscResource | more
Get-DscResource WindowsFeature
Get-DscResource WindowsFeature -Syntax

#what resources are in the module
Get-DscResource -module ComputermanagementDSC

Find-DSCResource smb*
Find-DSCResource -module ComputerManagementDSC 
Find-Module ComputerManagementDSC -OutVariable cm
start $cm.projecturi

#use tags
Find-DscResource -Tag activedirectory

Find-DscResource -Tag PowerShell
Install-Module powershellModule -force

Get-dscresource PSModuleResource -Syntax

# Uninstall-Module PowershellModule

#endregion
#region Creating a basic config

psedit .\basic.ps1

#we don't have time to look at configuring with credentials

. .\basic.ps1
get-command -CommandType Configuration
help BasicServer

#endregion
#region Deploying resources

#deploy modules however you want
Invoke-command -ComputerName SRV1 -ScriptBlock { 
 [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 Install-PackageProvider -Name nuget -ForceBootstrap -Force
 Install-Module ComputerManagementDSC -RequiredVersion 8.5.0 -force -Repository PSGallery
 Get-Module ComputerManagementDSC -ListAvailable
}

#endregion
#region Deploying the configuration

#build the mof
BasicServer -Computername SRV1 -OutputPath .
psedit .\BasicServer\SRV1.mof

Start-DscConfiguration -path .\BasicServer -ComputerName SRV1 -Wait -Verbose -force

#endregion
#region Getting and Testing configuration status

Get-DscConfigurationStatus -CimSession SRV1
Test-DscConfiguration -ComputerName srv1
Test-DscConfiguration -ComputerName srv1 -Detailed | format-list

Get-DscConfiguration -CimSession SRV1
#endregion
#region The LCM

#get settings
Get-DscLocalConfigurationManager -CimSession SRV1
#configure settings

psedit .\basic-lcm.ps1
. .\basic-lcm.ps1
BasicServerLCM -Computername SRV1 -OutputPath .

#push meta mof first
Set-DscLocalConfigurationManager -Path .\BasicServerLCM -ComputerName SRV1 -Force -Verbose
Get-DscLocalConfigurationManager -CimSession SRV1
#push configuration
Start-DscConfiguration -path .\BasicServerLCM -ComputerName SRV1 -Wait -Verbose -force

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
 Get-Module ComputerManagementDSC -ListAvailable
} -computername SRV2

Start-DscConfiguration -Path .\CompanyServer -Wait -Force -Verbose
Test-DscConfiguration -ComputerName SRV1,SRV2 -Detailed

#endregion
#region Logging and Troubleshooting

Get-Winevent -ListLog *dsc*

Get-Winevent Microsoft-Windows-DSC/Operational -ComputerName srv1 -MaxEvents 10 -OutVariable log
$log | format-list

enter-pssession -ComputerName srv1 

dir C:\Windows\System32\Configuration\ConfigurationStatus | sort lastwritetime

dir C:\Windows\System32\Configuration\ConfigurationStatus\*details.json| sort lastwritetime |
Select -last 1 | Get-Content -Encoding Unicode | ConvertFrom-Json

#documents
cd C:\windows\system32\Configuration
dir
get-content .\Current.mof

help Remove-DscConfigurationDocument
Remove-DscConfigurationDocument -Stage Current -WhatIf
exit
#endregion
#region Invoke-DSCResource

Help Invoke-DSCResource

Get-DscResource file -Syntax

#needs to run ON the remote server
enter-pssession -ComputerName SRV1

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

#Get-DscConfigurationStatus -CimSession SRV1
dir c:\work ; 
get-content C:\work\foo.txt

exit

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