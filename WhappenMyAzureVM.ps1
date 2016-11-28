<# 
 .Synopsis
  For a given VM Name and Resource Group name will load up the Boot Diagnostics Web page so can see status

 .Description
  See above

  Prequisites - currently requires Azure Powershell cmdlets installed. 

  Change Log
  ----------
  v1.00 Andy Ball 23\11\2016 Base Version 
  v1.01 Andy Ball 27\11\2016 If VM Name not found , output a list of all VMs
  v1.02 Andy Ball 28\11\2016 Add CheckAllSubscription

  Backlog 
  --------
  - Option so just generates URL without doing Get-AzureRMVM , so don't have to have Azure Cmdlets installed
  - Cmdlet Binding so can pipe.
  

 .Parameter VMName
  Name of the Azure VM
  
 .Parameter ResourceGroupName 
  Resource Group the VM resides in 

  .Parameter CheckAllSubscriptions
  If true , searches for VMName in all Subscriptions you have access to
  
 .Example
 WhappenMyAzureVM -VMName "MyVM" -ResourceGroupName "ItsResourceGroupName"
 
#>
Function WhappenMyAzureVM
{
    Param
    (
     [Parameter (Mandatory = $true , Position = 0)] [string] $VMName,
     [Parameter (Mandatory = $false , Position = 1)] [string] $ResourceGroupName, 
     [Parameter (Mandatory = $false , Position = 2)] [boolean] $CheckAllSubscriptions = $false

    )

   #Requires -Modules AzureRM.Profile
    
    $AllVms = @()
    $ErrorActionPreference = "Stop"
    $VMFound = $false 
    
    # Get the current Subscription so we don't have to bother checking it again / can switch back to it if we search throough other subs
    $CurrentRMContext = Get-AzureRMContext 
    $OriginalSubscriptionName = $CurrentRMContext.Subscription.SubscriptionName
    
    Write-Host "Getting VMs in current Subscription = $OriginalSubscriptionName"
    $VMs = Get-AzureRMVM | Select @{Name = "SubscriptionName" ; Expression = {$OriginalSubscriptionName}}, *
    $VM = $VMs | Where {$_.Name -eq $VMName} # -AND $_.ResourceGroupName -eq $ResourceGroupName}
    If ($VM -eq $null)
    {
        If ($CheckAllSubscriptions)
            {
                Write-Host "CheckAllSubscriptions is true, Getting List of Subscriptions"
                # Add the current Subscriptions VMs to all 
                $AllVMs += $VMs | Select @{Name = "SubscriptionName" ; Expression = {$OriginalSubscriptionName}}, *
                $Subscriptions = Get-AzureRMSubscription | Where {$_.SubscriptionName -ne $OriginalSubscriptionName}
          
                ForEach ($Sub in $Subscriptions)
                    {
                            $VM = $null
                            $SubscriptionName = $Sub.SubscriptionName 
                            Write-Host "`tChecking SubscriptionName = $SubscriptionName"
                            $ThisSub = Select-AzureRMSubscription -SubscriptionName $SubscriptionName
                            $VMs = Get-AzureRMVM 
                            $AllVMs += $VMs | Select @{Name = "SubscriptionName" ; Expression = {$SubscriptionName}}, *
                            $VM = $VMs | Where {$_.Name -eq $VMName}
                            If ($VM -ne $null)
                                {
                                    # Set to true so break out of the For
                                    $VMFound = $True
                                    break
                                }
      
                    }

                If ($SubscriptionName -ne $OriginalSubscriptionName)
                    {
                        Write-Host "Switching back from $SubscriptionName to $OriginalSubscriptionName"
                        $ThisSub = Select-AzureRMSubscription -SubscriptionName $OriginalSubscriptionName
                    }
                # reuse this var so can use in output if not found
                $Vms = $AllVMs
            }

    } #VM is null

    # Finally load the web page if found .. 
    If ($VMFound)
        {
            Write-Host "`tVM Found !" -ForegroundColor Green 
            $URL = "https://portal.azure.com/#resource/" + $VM.Id + "/bootDiagnostics"
            Start-Process -FilePath $URL
        }
    # Dump VM list if not.
    Else
        {
            Write-Host "Cannot find VM = $VMName heres whats available :" 
            $VMs | Select Name, ResourceGroupName, SubscriptionName | Sort Name, ResourceGroupName 
        }
}

WhappenMyAzureVM -VMName "LBE-SV-IIST-001" -CheckAllSubscriptions $false 

# -ResourceGroupName "MyResourceGroupName"
