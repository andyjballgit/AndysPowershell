<# 
 .Synopsis
  For A Given VM Names or all VMs searches to if backed up by Azure Recovery Services

 .Description
  

  Prequisites
  -----------
  Azure RM Modules. Tested with 2.5.0 AzureRM.RecoveryServices    

  Returns 
  -------
  Table Summary of VMs / Status


  Limitations and Known Issues
  ----------------------------
  See Backlog ! 

  Backlog 
  --------
  - Show VMs not found in the output
  - Show running backups
    
  Change Log
  ----------
  v1.00 Andy Ball 11/02/2017 Base Version
  
 .Parameter VMNames
 1 or more VMs in a string array to query/run backups for . If blank will do the whole subscription
  
 .Parameter SubscriptionName
 Subscription to check - if null then will search current subscriptions
   
 .Parameter GetLatestbackupDetails
 If true will look for latest backup date and status 
  
 .Example
 For 2 servers , searches for them in a Subscription called MySub
 $VMNames = @("Server1", "Server2")
 $res = Get-CVAzureVMBackupStatus -VMNames $VMNames -SubscriptionName "MySub" -GetLatestBackupDetails $true 
 $res | ft

 .Example
 Get status for all VMs in current subscription

 $res = Get-CVBackupStatusForVMs -GetLatestBackupDetails $true 
 $res | ft
 
#>

Function Get-CVAzureVMBackupStatus
{
   Param
        (
            [Parameter(Mandatory = $false, Position = 0)]  [string[]] $VMNames,
            [Parameter(Mandatory = $false, Position = 2)] [string] $SubscriptionName = $null, 
            [Parameter(Mandatory = $false, Position = 6)] [boolean] $GetLatestBackupDetails = $false
        )

    
    $ErrorActionPreference = "Stop"

    # add a dummy record so the compare works when no VMs not found yet
    $VMsFound += $Host | Select @{Name = "VMName" ; Expression = {"Dummy"}},
                                @{Name = "VaultName" ; Expression = {$null}},
                                @{Name = "ProtectionState" ; Expression = {$null}}, 
                                @{Name = "LastBackupStatus" ; Expression = {$null}},
                                @{Name = "LatestRecoveryPoint" ; Expression = {$null}}

    # Get Current Subscription Context
    Write-Host "Getting Current Context / Subscription"
    $CurrentSubscriptionName = (Get-AzureRmContext).Subscription.SubscriptionName
    
    If ($SubscriptionName -ne $null)
        {
            $Subscriptions = Get-AzureRMSubscription
            $MySub = $Subscriptions | Where {$_.SubscriptionName -eq $SubscriptionName}
            # ie cant find
            If ($MySub -eq $null)
                {
                    $Message = "Cannot Find SubscriptionName = $SubscriptionName" + "`r`n" + ($Subscriptions | Sort SubscriptionName | Select SubscriptionName | Out-String)
                    Write-Warning $Message 
                    Break

                }     
            # Found our Sub, check to see if current one
            Else
                {
                    # ie switch if we aren't current in right sub
                    If ($CurrentSubscriptionName -ne $SubscriptionName)
                        {
                            Write-Host "Switching to SubscriptionName = $SubscriptionName from $CurrentSubscriptionName"
                            $MySub = Select-AzureRmSubscription -SubscriptionName $SubscriptionName
                        }
                }

        }

    
    # No VMNames so get all 
    If ($VMNames -eq $null)
        {
            Write-Host "VMNames param is null, doing Get-AzureRMVM to get all VMNames"
            $VMs = Get-AzureRMVM 
            $VMNames  = $VMs.Name
        }

    # Various VM Vars to track progress
    $VMsCount = @($VMNames).Count
    $VMsFoundCount = 0 
    $VMCurrentNum = 1
    $VMsFound = @()

    # Get All Vaults
    Write-Host "$VMsCount VMs to be processed, Getting all Recovery Vaults for Subscription Name = $SubscriptionName"
    $Vaults = Get-AzureRMRecoveryServicesVault 
    $VaultCount = @($Vaults).Count 
    $VaultCurrentNum = 1

    # Seed this initially. VMsToCheck gets whittle down after each Vault is processed
    $VMsToCheck = $VMNames # | Where {$_ -notin $VMsFound.VMName}
    $VMsToCheckCount = @($VMsToCheck).Count

    $strVaults = $Vaults | Select Name, Type, Location, ResourceGroupName | Sort Name | Out-String 
    ForEach ($Vault in $Vaults)
        {
            $VaultName = $Vault.Name
            Write-Host "`tSetting Context to $VaultName ($VaultCurrentNum of $VaultCount)"
            $ctxVault = Set-AzureRMRecoveryServicesVaultContext -Vault $Vault
            
            $MatchingVMsCount = 0
            $AllContainerCount = 0

            $AllContainers = Get-AzureRMRecoveryServicesBackupContainer -ContainerType AzureVM
            $MatchingVMContainers = $AllContainers | Where {$_.FriendlyName -in $VMsToCheck}

            $AllContainersCount = @($AllContainers).Count
            $MatchingVMsCount = @($MatchingVMContainers).Count

            Write-Host "`tTotal Containers = $AllContainersCount, Matching = $MatchingVMsCount"
            $CurrentVMNumber = 1 

            ForEach ($Container in $MatchingVMContainers)
                {
                    $ContainerName = $Container.Name.Split(";")[1]
                    Write-Host "`t`tProcessing $ContainerName ($CurrentVMNumber of $MatchingVMsCount)"
                    $ProtectionState = $null 
                    $LastBackupStatus = $null 
                    $LatestRecoveryPoint = $null 
                    If($GetLatestBackupDetails)
                        {
                                 Write-Host "`t`t`tGetting Latest Backup Details"
                                 $BackupItem = Get-AzureRMRecoveryServicesBackupItem -Container $Container -WorkloadType AzureVM
                                 If ($BackupItem -ne $null)
                                        {
                                            $ProtectionState = $BackupItem.ProtectionState 
                                            $LastBackupStatus = $BackupItem.LastBackupStatus
                                            $LatestRecoveryPoint = $BackupItem.LatestRecoveryPoint
                                          #  $ThisVMInProgress = $InProgressJobs | Where {$_.WorkloadName -eq $VMName}
                                          #  If ($ThisVMInProgress)
                                          #      {
                                          #          $BackupStartTime = $ThisVMInProgress.StartTime 
                                          #          $BackupJobStatus = $ThisVMInProgress.Status
                                          #      }
                                        }
                                    Else
                                        {
                                            Write-Warning "Get-AzureRMRecoveryServicesBackupItem returned null = no current backup"
                                        }
                           

                        }
                    
                    $CurrentVMNumber++     
                    # Add current Container to Array
                    $VMsFound += $Host | Select @{Name = "VMName" ; Expression = {$ContainerName.ToUpper()}}, 
                                                        @{Name = "VaultName" ; Expression = {$VaultName}},
                                                        @{Name = "ProtectionState" ; Expression = {$ProtectionState}}, 
                                                        @{Name = "LastBackupStatus" ; Expression = {$LastBackupStatus}},
                                                        @{Name = "LatestRecoveryPoint" ; Expression = {$LatestRecoveryPoint}}
                }

            # reget the VMsToCheck, so we only check for VMs we aint found yet, if its null then we are done
            $VMsToCheck = $VMNames | Where {$_ -notin $VMsFound.VMName}
            If ($VMsToCheck -eq $null)
                {
                    Write-Host ""
                    Write-Host "We have found all $VMsCount VMs. Quitting Searching"
                    break

                }        
            Else
                {
                    $VMsToCheckCount = @($VMsToCheck).Count 
                    $VaultCurrentNum++
                    Write-Host ""
                }
                    
        }

    # finally return, removing the dummy record
    $VMsFound | Where {$_.VMName -ne "Dummy"}

}





