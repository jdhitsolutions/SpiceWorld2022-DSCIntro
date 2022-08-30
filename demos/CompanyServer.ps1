Configuration CompanyServer {

#computer names will come from configuration data
    Param()

    #always import this
    Import-DscResource -ModuleName PSDesiredStateConfiguration -ModuleVersion 1.1
    #import required modules
    Import-DSCResource -ModuleName ComputerManagementDSC -ModuleVersion 8.5.0

    Node $AllNodes.Nodename {
        
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
            Name        = 'CorpWork'
            Path        = 'C:\Work'
            Ensure      = 'Present'
            DependsOn   = '[File]Work'
            Description = 'Corporate work share'
            FullAccess  = 'Company\Domain Admins'
        }
       
 
        #$node is a built-in variable to represent each node in $AllNodes
        $Node.features.foreach({
            #create the configuration element dynamically
                WindowsFeature $_ {
                    Name                 = $_
                    Ensure               = 'Present'
                    IncludeAllSubFeature = $True
                } #end WindowsFeature resource
            })
        $Node.featuresRemove.foreach({
                WindowsFeature $_ {
                    Name                 = $_
                    Ensure               = 'Absent'
                    IncludeAllSubFeature = $True
                } #end WindowsFeature resource
            })

        $ConfigurationData.NonNodeData.Services.foreach({
                Service $_ {
                    Name        = $_
                    StartupType = "Automatic"
                    State       = "Running"
                }
            }) #foreach service
    } #close all nodes

    Node $allnodes.Where({ $_.role -eq 'FilePrint' }).Nodename {

        WindowsFeature FileServices {
            Name                 = "File-Services"
            Ensure               = "Present"
            IncludeAllSubFeature = $True
        }

        WindowsFeature PrintServices {
            Name                 = "Print-Services"
            Ensure               = "Present"
            IncludeAllSubFeature = $True
        }

    } #close node

    Node $allnodes.Where({ $_.role -eq 'Test' }).Nodename {

        WindowsFeature RSAT-AD-Powershell {
            Name                 = "RSAT-AD-PowerShell"
            Ensure               = "Present"
            IncludeAllSubFeature = $True
        }

    } #close node
} #close configuration