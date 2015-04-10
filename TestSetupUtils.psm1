function Get-VMIPv4Address
{
  param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]
    $Name
  )
  
  $VM = Get-VM -Name $Name
  $VM.NetworkAdapters[0].IPAddresses[0]
}

Export-ModuleMember Get-VMIPv4Address 