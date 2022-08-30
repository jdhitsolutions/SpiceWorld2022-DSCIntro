configuration BasicServer {
    Param([string[]]$Computername)

    #always import this
    Import-DscResource -ModuleName PSDesiredStateConfiguration -ModuleVersion 1.1
    #import required modules - pay attention to versioning
    Import-DSCResource -ModuleName ComputerManagementDSC -ModuleVersion 8.5.0

    Node $Computername {

        File Work {
            Ensure          = 'Present'
            DestinationPath = 'C:\Work'
            Type            = 'Directory'
        }

        File Readme {
            Ensure          = 'Present'
            DependsOn       = '[File]Work'
            DestinationPath = 'C:\work\Readme.txt'
            Contents        = 'Company work items go in this folder.'
            Type            = 'File'
        }

        smbShare Work {
            Name         = 'CorpWork'
            Path         = 'C:\Work'
            Ensure       = 'Present'
            DependsOn    = '[File]Work'
            Description  = 'Corporate work share'
            FullAccess   = 'Company\Domain Admins'
        }

        WindowsFeature PSv2 {
            Name = 'PowerShell-V2'
            Ensure = 'Absent'
        }

        WindowsFeature Backup {
            Name = 'Windows-Server-Backup'
            Ensure = 'Present'
        }
    } #node

} #configuration