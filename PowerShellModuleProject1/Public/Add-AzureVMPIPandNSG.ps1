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
            [Parameter(Mandatory = $false, Position = 2)] [string] $NSGName = $VMName + "-NSG-001", 
            [Parameter(Mandatory = $false, Position = 3)] [boolean] $NSGCreateIfNotExist = $true,
            [Parameter(Mandatory = $false, Position = 4)] [string[]] $AllowedIPList = @(), 
            [Parameter(Mandatory = $false, Position = 5)] [int[]] $AllowedTCPPortList = @(3389), 
            [Parameter(Mandatory = $false, Position = 6)] [boolean] $ListVMsIfNotFound = $false, 
            [Parameter(Mandatory = $false, Position = 7)] [string] $URIGetOwnPIP = "http://myexternalip.com/raw", 
            [Parameter(Mandatory = $false, Position = 8)] [int] $StartingPriorityNumber = 200
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

    $NICName = $NICResource.Name
    $NIC = Get-AzureRMNetworkInterface -Name $NICName -ResourceGroupName $NICResource.ResourceGroupName 
    $IPConfigName = $NICResource.Properties.IPconfigurations[0].Name

    $IPConfig = Get-AzureRmNetworkInterfaceIpConfig -Name $IPConfigName -NetworkInterface $NIC
    
    If ($IPConfig.PublicIpAddress -ne $null)
        {
            Write-Host "NIC = $NICName Already has Public IP Address"
        }
    Else
        {
            Write-Host "NIC = $NICName has no public IP Address"
        }


    #3. Get / Create NSG 
    $NSGs = Get-AzureRmNetworkSecurityGroup 
    $NSG = $NSGs | Where {$_.Name -eq $NSGName}
    If ($NSG -ne $null)
        {
            Write-Host "NSGName = $NSGName already exists deleting"
            Remove-AzureRmNetworkSecurityGroup -Name $NSGName -ResourceGroupName $NICResource.ResourceGroupName -Force
        }

    Write-Host ("Creating NSGName = $NSGName in ResourceGroup = " + ($NICResource.ResourceGroupName) + " in region = " + ($NICResource.Location))
    $NSG = New-AzureRmNetworkSecurityGroup -Name $NSGName -ResourceGroupName $NICResource.ResourceGroupName -Location $NICResource.Location

    
    #4 . Add rule to NSG
    Write-Host "Getting your public IP Address from $URIGetOwnPIP"
    $MyIpAddress = Invoke-RestMethod -Method GET -uri $URIGetOwnPIP
    Write-Host "Current Public IP Address = $MyIpAddress"

    $CIDR = $MyIpAddress.Trim() + "/32"
    Write-Host "CIDR = $CIDR"

    Write-Host ""
    $CurrentPriorityNumber = $StartingPriorityNumber 
    ForEach ($TCPPort in $AllowedTCPPortList)
        {
            Write-Host "`tProcessing Port = $TCPPort"
            $RuleName = "Allow_Port_" + $TCPPort + "_To_" + $MyIpAddress.Replace(".", "_")
            $Description = "Allow access to Port $TCPPort from $MyIPAddress"
            
            $NewRuleConfig = Add-AzureRMNetworkSecurityRuleConfig -NetworkSecurityGroup $NSG -Name $RuleName -Description $Description -Protocol Tcp -SourcePortRange "*" -DestinationPortRange $TCPPort -SourceAddressPrefix $CIDR -DestinationAddressPrefix "*" -Access Allow -Priority $CurrentPriorityNumber -Direction Inbound -Verbose | Set-AzureRmNetworkSecurityGroup 
            $NewRuleConfig 
            $CurrentPriorityNumber++

        }

    
    $NIC.NetworkSecurityGroup = $NSG 
    Write-Host "Applying NSG to NIC Name = $NICName" 
    $NIC | Set-AzureRmNetworkInterface 
   # $NSG

}


$NSG = Add-AzureVMPIPandNSG -VMName "CV-SRV-DOCK-001" -ListVMsIfNotFound $true 


