<# 
 .Synopsis
  Adds Public IP and restricive NSG to given VM. Idea is that can get public access tempoarily to VM , restrict to just current public IP of the caller. Lazy, cheaper, slightly less secure alternative to using Point to Site (P2S).  

 .Description
  Bit dangerious when in Internet Cafes etc, designed as a quick and dirty fix really should be using Point to Site or similar. 

  Prequisites
  -----------
  - AzureRM Cmdlets
  - Ports are allowed through firewall / Router - often Port 3389 is blocked 

  Change Log
  ----------
  v1.00 Andy Ball 11/03/2017 Base Version. 
  v1.01 Andy Ball 11/03/2017 Generates a .ps1 file to delete PIP and NSG when u r done

  Limitations
  ----------
  - Currently just deletes the NSG if it exists , as its deemed temporary

  Backlog 
  --------
  - have an expiry date / time , hook into Azure Automation or web job
  - or have global Azure Automation script - remove Public IP from NICs / VMs unless PublicFacing tag is true 
  - allow Current IP Address to be passed in , in case the url for looking up is blocked (this has happened)
  - Luxury version to put a Load balancer in front redirecting from port 443 to 3389 (or do NETSH Port mapping on client)
  - maybe backup existing NSG config if already exists as gets currently gets deleted if exists. 
  
 .Parameter VMName
 Name of VM to connect to 
  
 .Parameter PIPName
 Name of Public IP Address to be added to VMs NIC. Defaults to VMName-PIP-001
  
 .Parameter NSGName
 Name of NSG to add to the VMs NIC. Defaults to VMName-NSG-001

 .Parameter NSGCreateIfNotExist
 if true (default) will create the NSG

 .Parameter AllowedIPList
 By default just allows access / adds to NSG for the callers public ip address , add additional addresses here. 

 .Parameter AllowedTCPPortList
 Array of TCP Ports to allow access to VM. Currently will combine this with public facing ip address of the caller.  

 .Parameter ListVMsIfNotFound
 If true (default) will list out VMs if VMName param is found not to exist

 .Parameter URIGetOwnPIP 
 URI used to get callers public ip address (used to add to NSG with /32). Defaults to "http://myexternalip.com/raw", 

 .Parameter StartingPriorityNumber
 Priority number to start adding Allows to in NSG. Defaults to 200. 

 .StartVM
 Boolean. If true (default) will Start the VM if not running

 .ConnectToVM
 Boolean. If true (default) will RDP usings Mstsc.exe to the Public IP Address 
 
 
 .Example
 # Use defaults , will just grant access to port 3389 to current public IP Address, Start and Connect to VM via MSTSC

    Add-CVAzureVMPIPandNSG -VMName "CV-SRV-DOCK-001" -ListVMsIfNotFound $true 

 .Example
  443 too 
  Add-CVAzureVMPIPandNSG -VMName "CV-SRV-DOCK-001" -ListVMsIfNotFound $true -AllowedTCPPortList 443,3389

 .Example 

#>
Function Add-CVAzureVMPIPandNSG
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
            [Parameter(Mandatory = $false, Position = 8)] [int] $StartingPriorityNumber = 200,
            [Parameter(Mandatory = $false, Position = 9)] [int] $StartVM = $true,
            [Parameter(Mandatory = $false, Position = 10)] [int] $ConnectToVM = $true, 
            [Parameter(Mandatory = $false, Position = 11)] [string] $RemovePIPandNSGFilename = "c:\temp\RemovePIPAndNSG.ps1"
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
            $PIPResource = Get-AzureRMResource -ResourceId $IPConfig.PublicIpAddress.Id
            $PIPName = $PIPResource.Name 
            $PIPResourceGroupName = $PIPResource.ResourceGroupName 
            Write-Host "NIC = $NICName Already has Public IP Address, Name = $PIPName, ResourceGroupName = $PIPResourceGroupName"            
        }
    Else
        {
            Write-Host "NIC = $NICName has no public IP Address, creating $PIPName"
            $PIP = New-AzureRmPublicIpAddress -Name $PIPName -ResourceGroupName $VM.ResourceGroupName -Location $VM.Location -AllocationMethod Dynamic -DomainNameLabel $VMName.ToLower() -Force
            $NIC.IpConfigurations[0].PublicIpAddress = $PIP
            $NIC | Set-AzureRmNetworkInterface
        }


    #3. Remove NSG Binding if already exist otherwise get a Badrequest error when trying to delete NSG
    If ($NIC.NetworkSecurityGroup -ne $null)
        {
            Write-Host "NIC = $NICName has NSG. Removing."
            $NIC.NetworkSecurityGroup = $null 
            $NIC | Set-AzureRmNetworkInterface | Out-Null
        }

    #4. Get / Create NSG 
    $NSGs = Get-AzureRmNetworkSecurityGroup 
    $NSG = $NSGs | Where {$_.Name -eq $NSGName}
    If ($NSG -ne $null)
        {
            Write-Host "NSGName = $NSGName already exists deleting"
            
            Remove-AzureRmNetworkSecurityGroup -Name $NSGName -ResourceGroupName $NICResource.ResourceGroupName -Force
        }

    Write-Host ("Creating NSGName = $NSGName in ResourceGroup = " + ($NICResource.ResourceGroupName) + " in region = " + ($NICResource.Location))
    $NSG = New-AzureRmNetworkSecurityGroup -Name $NSGName -ResourceGroupName $NICResource.ResourceGroupName -Location $NICResource.Location

    
    #5 . Get Current Public IP So can add it to NSG
    Write-Host "Getting your public IP Address from $URIGetOwnPIP"
    $MyIpAddress = Invoke-RestMethod -Method GET -uri $URIGetOwnPIP
    $MyIPAddress = $MyIPAddress.Trim()

    Write-Host "Your current Internet Facing IP Address = $MyIpAddress"

    # ie added to AllowedIPList which so we process both IPs provided and current public facing ip address
    $AllowedIPList += $MyIpAddress
    

    #6. Now roll through all IPs , then all Ports for them and add 
    ForEach($AllowedIPAddress in $AllowedIPList)
    {
        $CIDR = $AllowedIPAddress.Trim() + "/32"
        Write-Verbose "Processing CIDR = $CIDR"

        #6. Roll through all ports
        $CurrentPriorityNumber = $StartingPriorityNumber 
        ForEach ($TCPPort in $AllowedTCPPortList)
            {
                $RuleName = "Allow_Port_" + $TCPPort + "_From_" + $MyIpAddress.Replace(".", "_")
                $Description = "Allow access to Port $TCPPort from $CIDR"
                Write-Host "`tCreating RuleName = $RuleName, Description = $Description for TCP Port = $TCPPort"
                $NewRuleConfig = Add-AzureRMNetworkSecurityRuleConfig -NetworkSecurityGroup $NSG -Name $RuleName -Description $Description -Protocol Tcp -SourcePortRange "*" -DestinationPortRange $TCPPort -SourceAddressPrefix $CIDR -DestinationAddressPrefix "*" -Access Allow -Priority $CurrentPriorityNumber -Direction Inbound -Verbose | Set-AzureRmNetworkSecurityGroup 
                $CurrentPriorityNumber++
            }
    }

    #7. Bind NSG to NIC
    $NIC.NetworkSecurityGroup = $NSG 
    Write-Host "Applying NSG to NIC Name = $NICName" 
    $NIC | Set-AzureRmNetworkInterface | Out-Null 
   
    #8. StartVM if Required
    If($StartVM)
        {
            Write-Host ("Starting VM = $VMName @ " + (Get-Date))
            $VM | Start-AzureRmVM
        }

    #9. RDP to VM if required 
    If($ConnectToVM)
        {
            Write-Host "Connecting to VM = $VMName. Getting IPAddress for PIP Name = $PIPName, RG = $PIPResourceGroupName"
            $PIPAddress = Get-AzureRmPublicIpAddress -Name $PIPName -ResourceGroupName $PIPResourceGroupName 
            If ($PIPAddress -eq $null)
                {
                    Write-Warning "Cannot find $PIPName"
                    Break
                }

            $VMsPublicIPAddress = $PIPAddress.IpAddress
            If($VMsPublicIPAddress -eq $null)
                {
                    Write-Warning "IPAddress is null for some reason. Quitting..."
                    Break 
                }
            Else
                {
                    $CMDArgs = "/v:" + $VMsPublicIPAddress
                    Write-Host "Running Command = mstsc , with params = $CMDArgs"
                    Start-Process -FilePath mstsc.exe -ArgumentList $CMDArgs 
                }

        }


    #10. Finally return commands to allow to be tidied when finished
    $RemoveText = "Run commands below to tidy up:" + "`r`n"
    $RemoveText = "`$ErrorActionPreference = " + """" + "Stop" + """" + "`r`n"
    $RemoveText += "`$NIC = Get-AzureRMNetworkInterface -Name $NICName -ResourceGroupName " + ($NIC.ResourceGroupName) + "`r`n"
    $RemoveText += "`$IPConfigName = `$NIC.IPconfigurations[0].Name" + "`r`n"
    $RemoveText += "`$IPConfig = Get-AzureRmNetworkInterfaceIpConfig -Name `$IPConfigName -NetworkInterface `$NIC" + "`r`n"
    $RemoveText += "`$IPConfig.PublicIpAddress = `$null" + "`r`n"
    $RemoveText += "`$NIC.NetworkSecurityGroup = `$null" + "`r`n" 
    $RemoveText += "`$NIC | Set-AzureRMNetworkInterface" + "`r`n"
    $RemoveText += "Remove-AzureRMPublicIPAddress -Name $PIPName -ResourceGroupName $PIPResourceGroupName -Force" + "`r`n"
    $RemoveText += "Remove-AzureRmNetworkSecurityGroup -Name $NSGName -ResourceGroupName " + $NICResource.ResourceGroupName + " -Force"

    $RemoveDir = Split-Path $RemovePIPandNSGFilename -Parent
    If ((Test-Path $RemoveDir) -eq $false)
        {
            Write-Host "Creating Directory = $RemoveDir"
            New-Item -Path $RemoveDir -ItemType "Directory"
        }
    Write-Host "Writing delete commands to $RemovePIPAndNSGFileName"
    $RemoveText | Out-File -FilePath $RemovePIPandNSGFilename -Force
}
