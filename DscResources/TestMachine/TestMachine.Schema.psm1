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
            SwitchName        = 'DemoInternalSwitch'
            SwitchType        = 'Internal'
            SwitchIPv4Address = '192.168.1.100'

            # VMType is an array of hashtables
            # each entry contains data for VMs created from a single
            # vhd source

            VMType = @(
              @{
                # path where diff vhds will be created
                VhdPath         = "$WorkingFolder\Vhd"

                # path where VM data will be stored
                VMPath          = "$WorkingFolder\VM"

                # location for the source vhd
                VhdSource       = 'D:\VHD\Golden\Nana-Test.vhd'

                # VMName is an array and will be combined with namebase to 
                # create VM names like Nana-Test-DC, Nana-Test-WS, etc

                VMNameBase        = 'Nana-Test'
                VMName            = @('1')
                VMIPAddress       = @('192.168.1.1')
                VMStartupMemory   = 16GB
                VMState           = 'Running'
                VMUnattendPath    = "$ScriptPath\unattend.xml"
                VMUnattendCommand = "$ScriptPath\unattend.cmd"

                # Administrator credentials
                VMAdministratorCredentials = (Get-Credential)

                #The folders to inject into this vhd. These will be
                #available under \content
                VMFoldersToCopy = @(
                                        $ContentFolder
                                    )

              }
            )
        }
    )
#>
configuration TestMachine
{
    Import-DscResource -Module xHyper-V, xNetworking, nHyperV, cHostsFile

    Node $AllNodes.Where{$_.Role -eq 'HyperVHost'}.NodeName
    {

        # One virtual switch overall - ensure switch
        xVMSwitch VirtualSwitch
        {
            Ensure    = 'Present'
            Name      = $Node.SwitchName
            Type      = $Node.SwitchType
        }

        foreach($VMType in $Node.VMType)
        {            
            # working folder where VM will be created
            File VMPath
            {
                DestinationPath = "$($VMType.VMPath)"
                Ensure          = 'Present'
                Type            = 'Directory'
            }

            #Working folder where the diff VHDs are created
            File BaseVhdPath
            {
                DestinationPath = "$($VMType.VhdPath)\Base"
                Ensure          = 'Present'
                Type            = 'Directory'
            }

            File InstanceVhdPath
            {
                DestinationPath = "$($VMType.VhdPath)\Instance"
                Ensure          = 'Present'
                Type            = 'Directory'
            }

            File SourceVhd
            {
                SourcePath      = "$($VMType.VhdSource)"
                DestinationPath = "$($VMType.VhdPath)\Base\$($VMType.VMNameBase).vhd"
                Type            = 'File'
                DependsOn       = '[File]BaseVhdPath'
            }

            #Create the diff VHD for this type
            $SourceVhdPath   = "$($VMType.VhdPath)\base\$($VMType.VMNameBase).vhd"
            $BaseVMName    = "$($VMType.VMNameBase)"

            xVHD $BaseVMName
            {
                  Name       = "$BaseVMName.Base"
                  Path       = "$($VMType.VhdPath)\Base"
                  ParentPath = $SourceVhdPath
                  Ensure     = 'Present'
                  DependsOn  = '[File]SourceVhd'
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

            $BaseVhdPath  = "$($VMType.VhdPath)\Base\$BaseVMName.base.vhd"
            
            #Inject required files into the Base VHD
            xVhdFile "$BaseVMName.Inject"
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
                    Path       = "$($VMType.VhdPath)\Instance\"
                    ParentPath = $BaseVhdPath
                    Ensure     = 'Present'
                    DependsOn  = "[xVhdFile]$BaseVMName.Inject"
                }              

                $InstanceVhdPath = "$($VMType.VhdPath)\Instance\$VMName.vhd"
             
                # create the required unattend.xml in the Vhd
                nUnattend "Vhd_$VMName.Inject"
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
                    VhdPath       = "$($VMType.VhdPath)\Instance\$VMName.vhd"
                    Path          = "$($VMType.VMPath)"
                    SwitchName    = $Node.SwitchName
                    StartupMemory = $VMType.VMStartupMemory
                    State         = $VMType.VMState
                    Ensure        = 'Present'
                    DependsOn     = "[nUnattend]VHD_$VMName.Inject", '[xVMSwitch]VirtualSwitch', "[cHostsFileEntry]Entry_$VMName"
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
             nWaitForVMIPAddress WaitForIP
             {
                VMName     =   $AllNames
                PseudoKey  =   'WaitForIP'
                Dependson  =   $DependsOnArray
             }

             # set the IP Address of the switch at the very end
             # only then CIM session seems to work - not sure why
             xIPAddress switchIPAddress
             {
                IPAddress      = $Node.SwitchIPv4Address
                InterfaceAlias = '*vet*'
                DependsOn      = '[xVMSwitch]VirtualSwitch', '[nWaitForVMIPAddress]WaitForIP'
             }
       }
    }
}

Export-ModuleMember TestMachine