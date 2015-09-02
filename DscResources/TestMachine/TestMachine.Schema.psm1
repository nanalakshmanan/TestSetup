<#
    This configuration expects a structured object within
    its $Node entry (passed via ConfigurationData)

    Here is the structure

    AllNodes = @(
        @{
            NodeName = 'localhost';
            Role     = 'HyperVHost'      # HyperVHost as the role identifies
                                         # every Hyper-V host node for which
                                         # this configuration will be compiled

            # One switch can be created overall
            SwitchName        = 'DemoSwitchInternal'
            SwitchType        = 'Internal'
            SwitchIPv4Address = '192.168.1.10'

            # path where diff vhds will be created
            VhdPath         = "$WorkingFolder\Vhd"

            # path where VM data will be stored
            VMPath          = "$WorkingFolder\VM"

            # VMType is an array of hashtables
            # each entry contains data for VMs created from a single
            # vhd source

            VMType = @(
              @{
                # Name for this VMType
                Name            = 'TestVM'

                # path where diff vhds will be created
                VhdPath         = "$WorkingFolder\Vhd\Test"

                # path where VM data will be stored
                VMPath          = "$WorkingFolder\VM\Test"

                # location for the source vhd
                VhdSource       = 'D:\VHD\Golden\Base.vhd'

                # VMName is an array and will be combined with namebase to 
                # create VM names like Nana-Test-DC, Nana-Test-WS, etc

                VMNameBase        = 'Nana-Test'
                VMName            = @('1')
                VMIPAddress       = @('192.168.1.1')
                VMStartupMemory   = 4GB
                VMState           = 'Running'
                VMUnattendPath    = "$ScriptPath\unattend.xml"
                VMUnattendCommand = "$ScriptPath\unattend.cmd"

                # Administrator credentials
                VMAdministratorCredentials = $Credential

                #The folders to inject into this vhd. These will be
                #available under \content
                VMFoldersToCopy = @(
                                        $ContentFolder
                                    )
              }

        }
    )
#>
configuration TestMachine
{    
    Import-DscResource -Module xHyper-V, xNetworking, nHyper-V, cHostsFile,  PSDesiredStateConfiguration

    Node $AllNodes.Where{$_.Role -eq 'HyperVHost'}.NodeName
    {
        # One virtual switch overall - ensure switch
        xVMSwitch VirtualSwitch
        {
            Ensure    = 'Present'
            Name      = $Node.SwitchName
            Type      = $Node.SwitchType
        }

        # working folder where VM will be created
        File VMPath
        {
            DestinationPath = "$($Node.VMPath)"
            Ensure          = 'Present'
            Type            = 'Directory'
        }

        #Working folder where the diff VHDs are created
        File BaseVhdPath
        {
            DestinationPath = "$($Node.VhdPath)\Base"
            Ensure          = 'Present'
            Type            = 'Directory'
        }

        File InstanceVhdPath
        {
            DestinationPath = "$($Node.VhdPath)\Instance"
            Ensure          = 'Present'
            Type            = 'Directory'
        }
        
        foreach($VMType in $Node.VMType)
        {         
            $VMTypeName = $VMType.Name
            File "$($VMTypeName)_SourceVhd"
            {
                SourcePath      = "$($VMType.VhdSource)"
                DestinationPath = "$($Node.VhdPath)\Base\$($VMType.VMNameBase).vhd"
                Type            = 'File'
                DependsOn       = '[File]BaseVhdPath'
            }

            #Create the diff VHD for this type
            $SourceVhdPath   = "$($Node.VhdPath)\base\$($VMType.VMNameBase).vhd"
            $BaseVMName    = "$($VMType.VMNameBase)"

            xVHD $BaseVMName
            {
                  Name       = "$BaseVMName.Base"
                  Path       = "$($Node.VhdPath)\Base"
                  ParentPath = $SourceVhdPath
                  Ensure     = 'Present'
                  DependsOn  = "[File]$($VMTypeName)_SourceVhd"
            }

            #Copy required modules and any additional content specified
            $FileDirectoryToCopy = @()

            foreach($SourceFolder in $VMType.VMFoldersToCopy) 
            {
                $DestinationFolder = $SourceFolder.Substring($SourceFolder.IndexOf(':\') + 2)
                $DestinationFolder = 'Content\' + $DestinationFolder
                
                $FileDirectoryToCopy += @(
                            MSFT_xFileDirectory {
                                                  SourcePath = $SourceFolder
                                                  DestinationPath = $DestinationFolder
                                                  Ensure = 'Present'
                                                  Recurse = $true
                                                 
                                              }
                                      )
            }

            $BaseVhdPath  = "$($Node.VhdPath)\Base\$BaseVMName.base.vhd"
            
            #Inject required files into the Base VHD
            xVhdFile "$($BaseVMName)_Inject"
            {
                  VhdPath       = $BaseVhdPath
                  FileDirectory = $FileDirectoryToCopy
                  CheckSum      = 'ModifiedDate'
                  DependsOn     = "[xVHD]$BaseVMName"
            }

            $i = 0
            foreach($VMDiffName in $VMType.VMName)
            {            
                $VMName = "$BaseVMName-$VMDiffName"

                #Create a diff VHD from the base VHD
                XVHD "VHD_$VMName"
                {
                    Name       = "$VMName.vhd" 
                    Path       = "$($Node.VhdPath)\Instance\"
                    ParentPath = $BaseVhdPath
                    Ensure     = 'Present'
                    DependsOn  = "[xVhdFile]$($BaseVMName)_Inject"
                }              

                $InstanceVhdPath = "$($Node.VhdPath)\Instance\$VMName.vhd"
             
                # create the required unattend.xml in the Vhd
                nUnattend "Vhd_$VMName_Inject"
                {
                    VhdPath                  = $InstanceVhdPath
                    AdministratorCredentials = $VMType.VMAdministratorCredentials
                    IPV4Address              = $VMType.VMIPAddress[$i]
                    UnattendCommand          = $VMType.VMUnattendCommand
                    ComputerName             = $VMName 
                    DependsOn                = "[xVHD]VHD_$VMName"
                }

                # Create entry for VM in hosts file
                cHostsFileEntry "Entry_$VMName"
                {
                    Ensure    = 'Present'
                    ipAddress = $VMType.VMIPAddress[$i]
                    hostName  = $VMName
                }
                $i++

                #Create VM
                xVMHyperV "$VMName"
                {
                    Name          = $VMName
                    VhdPath       = "$($Node.VhdPath)\Instance\$VMName.vhd"
                    Path          = "$($Node.VMPath)"
                    SwitchName    = $Node.SwitchName
                    StartupMemory = $VMType.VMStartupMemory
                    State         = $VMType.VMState
                    Ensure        = 'Present'
                    DependsOn     = "[nUnattend]VHD_$VMName_Inject", '[xVMSwitch]VirtualSwitch', "[cHostsFileEntry]Entry_$VMName"
                }
             }

             $AllNames = @()
             $DependsOnArray = @()
             foreach($VMDiffName in $VMType.VMName)
             {            
                $VMName = "$BaseVMName-$VMDiffName"
                $AllNames += $VMName
                $DependsOnArray += "[xVMHyperV]$VMName"
             }

             # wait for all the VMs to come up
             nWaitForVMIPAddress "$($VMTypeName)_WaitForIP"
             {
                VMName     =   $AllNames
                PseudoKey  =   "$($VMTypeName)_WaitForIP"
                Dependson  =   $DependsOnArray
             }             
       }

        $DependsOnArray = @()
        foreach($VMType in $Node.VMType)
        {
            $DependsOnArray += "[nWaitForVMIPAddress]$($VMType.Name)_WaitForIP"
        }
        $DependsOnArray += '[xVMSwitch]VirtualSwitch'

        # set the IP Address of the switch at the very end
        # only then CIM session seems to work - not sure why
        xIPAddress switchIPAddress
        {
            IPAddress      = $Node.SwitchIPv4Address
            InterfaceAlias = '*vet*'
            DependsOn      = $DependsOnArray
        }
    }
}

Export-ModuleMember TestMachine
