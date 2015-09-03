$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$WorkingFolder = 'D:\Nana\Test'
$ContentFolder = 'D:\Content\'
$Credential = Get-Credential Administrator

@{
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
                # name of the VMType
                Name            = 'TestVM'

                # location for the source vhd
                VhdSource       = 'D:\VHD\Golden\Nana-Test.vhd'

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

                # This is the modules folder. Everything under this folder
                # will be copied to $Env:ProgramFiles\WindowsPowerShell\Modules
                VMModulesFolder = "$ContentFolder\Modules"

                #The folders to inject into this vhd. These will be
                #available under \content
                VMFoldersToCopy = @(
                                        $ContentFolder
                                    )

              }
            )
        }
    )
}