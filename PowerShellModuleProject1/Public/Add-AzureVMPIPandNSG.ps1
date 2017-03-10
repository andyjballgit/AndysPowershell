<# 
 .Synopsis
  Adds Public IP and restricive NSG to given VM. Idea is that can get public access tempoarily to VM , restrict to just current public IP of whoever calls. 

 .Description
  Blah Blah 

  Prequisites
  -----------
  - AzureRM Cmdlets

  Change Log
  ----------
  v1.00 Andy Ball 10/03/2017 Base Version - not even working yet. 

  Backlog 
  --------
  -
  -

 .Parameter VMName
  
 .Parameter PIPName
  
 .Parameter AllowedIPList

 .Parameter AllowedTCPPortList
 
 .Example

 .Example

 .Example 

#>
Function Add-AzureVMPIPandNSG
{
    Param
        (
            [Parameter(Mandatory = $true, Position = 0)]  [string] $VMName,
            [Parameter(Mandatory = $false, Position = 1)] [string] $PIPName = $VMName + "-PIP-001", 
            [Parameter(Mandatory = $false, Position = 2)] [string[]] $AllowedIPList = @(), 
            [Parameter(Mandatory = $false, Position = 3)] [int[]] $AllowedTCPPortList = @(3389), 
            [Parameter(Mandatory = $false, Position = 4)] [boolean] $ListVMsIfNotFound = $false 

        )

    $ErrorActionPreference = "Stop"

    # 1. Get all Vms so we can validate it exists / use it
    Write-Host "Getting All VMs"
    $VMs = Get-AzureRMVM 

    $VM = $VMs | Where {$_.Name -eq $VMName}
    If ($VM -eq $null)
        {
            Write-Warning "VMName = $VMName does not exist. Quitting..."
            If($ListVMsIfNotFound)
                {
                    $VMs | Select Name, ResourceGroupName | Out-String 
                }
            Break 
        }

    #2. Check for existing PIP 
    $NICId = $VM.NetworkProfile.NetworkInterfaces[0].Id

    $NICResource = Get-AzureRMResource -ResourceId $NICId
    $NICResource.Properties
}


Add-AzureVMPIPandNSG -VMName "CV-SRV-DOCK-001" -ListVMsIfNotFound $true 