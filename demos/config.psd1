@{
    #Node specific data
    #allnodes is an array of hashtables, one per node
    AllNodes = @( 
       @{NodeName = "*"
         Features = @("Windows-Server-Backup","PowerShell","SNMP-Service")
         FeaturesRemove = @("Telnet-Client","PowerShell-v2","BranchCache")
         },
       @{NodeName = "SRV1"; Role = "FilePrint","Test"},
       @{NodeName = "SRV2"; Role = "Web"}
    )
    
    #non-node Specific data. No code allowed
    NonNodeData = @{Services = "bits","remoteregistry","wuauserv"}
}