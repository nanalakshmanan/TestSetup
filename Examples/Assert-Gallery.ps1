$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$ConfigData = (& "$ScriptPath\Assert-Gallery-Data.ps1")
$WorkingFolder = 'D:\Nana\Test'

Import-Module "$ScriptPath\..\DscResources\TestMachine" -Force

Remove-Item -Recurse -Force "$WorkingFolder\CompiledConfigurations\TestMachine" 2> $null
TestMachine -OutputPath "$WorkingFolder\CompiledConfigurations\TestMachine" -ConfigurationData $ConfigData -verbose

Start-DscConfiguration -Wait -Force -Path "$WorkingFolder\CompiledConfigurations\TestMachine" -Verbose