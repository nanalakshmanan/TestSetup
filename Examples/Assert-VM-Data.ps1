$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$WorkingFolder = 'D:\Nana\Test'
$ModulesFolder = 'D:\Content\Modules'

@{
    AllNodes = @(
        @{
            NodeName = 'localhost';
            Role     = 'HyperVHost'      # HyperVHost as the role identifies
                                         # every Hyper-V host node for which
                                         # this configuration will be compiled

            # VMType is an array of hashtables
            # each entry contains data for VMs created from a single
            # vhd source

            VMType = @(
              @{
                # the switch for all VMs
                SwitchName      = 'DemoInternalSwitch'

                # path where diff vhds will be created
                VhdPath         = "$WorkingFolder\Vhd"

                # path where VM data will be stored
                VMPath          = "$WorkingFolder\VM"

                # location for the source vhd
                VhdSource       = 'D:\VHD\Golden\w2k12r2-amd64-serverdatacenter-en_us.vhd'

                # VMName is an array and will be combined with namebase to 
                # create VM names like Nana-Test-DC, Nana-Test-WS, etc

                VMNameBase        = 'Nana-Test'
                VMName            = @('1', '2')
                VMIPAddress       = @('192.168.1.1', '192.168.1.2')
                VMStartupMemory   = 8GB
                VMState           = 'Running'
                VMUnattendPath    = "$ScriptPath\unattend.xml"
                VMUnattendCommand = "$ScriptPath\unattend.cmd"

                # Administrator credentials
                VMAdministratorCredentials = (Get-Credential)

                #The folders to inject into this vhd. These will be
                #available under \content
                VMFoldersToCopy = @(
                                        $ModulesFolder
                                    )

              }
            )
        }
    )
}