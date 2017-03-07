<# 
 .Synopsis
  Updates Size of an Azure Managed Disk even if attached to a VM (by detaching, resizing, reattaching if neccessary) as appears to fail if attached to a VM

 .Description
 See https://docs.microsoft.com/en-us/azure/storage/storage-managed-disks-overview 

  Change Log
  ----------
  v1.00 Andy Ball 26/02/2017 Base Version
  v1.01 Andy Ball 27/02/2017 Handle VM that already has Multiple Data Disks , ie LUN numbers 
  v1.02 Andy Ball 27/02/2017 Change output slightly
  V1.03 Andy Ball 06/03/2017 Add params to can choose to stop / start / remove disk
  v1.04 Andy Ball 07/03/2017 Tidy up output / complete help 

  Limitations and Known Issues 
  ----------------------------
  - VM Status (Running etc) display doesn't always work
  - Get below if expanding and attached to a VM , can only get it to work by detaching
  
  Start-AzureRMVM : Long running operation failed with status 'Failed'.
    ErrorCode: BadRequest
    ErrorMessage: Disks or snapshot cannot be resized down.
    StartTime: 07/03/2017 05:28:25
    EndTime: 07/03/2017 05:28:25
    OperationID: 461f509c-da87-4b89-8d09-97abfebc8880
    Status: Failed

  Backlog 
  --------

 .Parameter DiskName
  Name of Managed Disk to Expand 

 .Parameter ExpandGB
 Has 2 meanings : If Mode = ExpandBy , then it will increase by ExpandGB Gbytes , else if ExpandTo it will increase to ExpandGB GBytes
  
 .Parameter StopVMIfAttached
 if Managed Disk is attached to VM , will stop. True by default

 .Parameter Remove Disk
 If true , will remove the disk , expand, reattach. As of this writing if dont do that fails 

 .Example
 Expand current size *BY* 20Gb
  
    $DiskName = "CV-SRV-TEST-001-DataDisk-01"
    $Stop = $true
    $ExpandDiskGB = 20
    $Mode = "ExpandBY"
    $RemoveDisk = $false

    Update-CVAzureRMDiskAttached -DiskName $DiskName -Mode $Mode -ExpandGB $ExpandDiskGB  -StopVMIfAttached $Stop  -RemoveDisk $RemoveDisk
 
 .Example 
  Expand Current Disk size *TO* 420gb

    $DiskName = "CV-SRV-TEST-001-DataDisk-01"
    $Stop = $true
    $ExpandDiskGB = 420
    $Mode = "ExpandTo"
    $RemoveDisk = $True

    Update-CVAzureRMDiskAttached -DiskName $DiskName -Mode $Mode -ExpandGB $ExpandDiskGB  -StopVMIfAttached $Stop  -RemoveDisk $RemoveDisk

 #>
Function Update-CVAzureRMDiskAttached
{
    Param
        (
            [Parameter(Mandatory = $true, Position = 0)]  [string] $DiskName,
            [Parameter(Mandatory = $true, Position = 1)]  [ValidateRange(1, 1023)] [int] $ExpandGB, 
            [Parameter(Mandatory = $false, Position = 2)] [boolean]  $StopVMIfAttached = $true  ,  
            [Parameter(Mandatory = $false, Position = 3)] [string]  [ValidateSet("ExpandBy", "ExpandTo")] $Mode = "ExpandBy" ,
            [Parameter(Mandatory = $false, Position = 4)] [boolean]  $RemoveDisk = $false


        )

    $ErrorActionPreference = "Stop"

    # Get All Disks so we can display if not found
    $Disks = Get-AzureRMDisk


    $DataDisk = $Disks | Where {$_.Name -eq $DiskName}
    If ($DataDisk -eq $null)
        {
            Write-Warning "Cannot Find DiskName = $DiskName :" 
            $Disks | Sort Name | Select Name, DiskSizeGB, Location | Sort Name | Out-String
            Break 

        }

    # Validate not trying to shrink, which isnt supported
    $CurrentDiskSizeGB = $DataDisk.DiskSizeGB
    If ($Mode -eq "ExpandTo")
        {
            $NewDiskSizeGB = $ExpandGB             
            Write-Host "Mode is ExpandTo so will try and set to $NewDiskSizeGB GB (currently $CurrentDiskSizeGB GB)"
            
        }
    Else
        {
            $NewDiskSizeGB = $CurrentDiskSizeGB + $ExpandGB
            Write-Host "Mode is ExpandBy so will try and set to $NewDiskSizeGB GB (currently $CurrentDiskSizeGB GB)"
        }

    # NB this is lt as opposed lte cos can run it with same size to repair situation when try and expand Disk when attached 
    # and wont start as per help 

    If ($NewDiskSizeGB -lt $CurrentDiskSizeGB)
        {
            Write-Warning "New Disk Size = $NewDiskSizeGB Gbytes is < Current Disk Size = $CurrentDiskSizeGB Gbytes"
            Break
        }

    If ($NewDiskSizeGB -gt 1023)
        {
            Write-Warning "New Disk Size is $NewDiskSizeGB Gbytes, Maximum = 1023"
            Break 
        }

    # OwnerID will point at VM attached
    $OwnerId = $DataDisk.OwnerId 
    If ($OwnerId -ne $null)
        {
            # Get the VM
            $Resource = Get-AzureRMResource -ResourceId $OwnerId
            $VMName = $Resource.Name 
            $ResourceGroupName = $Resource.ResourceGroupName 

            # Get status so we can see if running
            Write-Host "Disk is attached to VMName = $VMName in ResourceGroup = $ResourceGroupName, Doing Get-AzureRVM -Status on it"
            $VMStatus = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
            $Status = $VMStatus.Statuses[1].Code
            
            Write-Host "VM Status = $Status"
            If ($Status -eq "PowerState/Running")
                {
                    Write-Warning "VM is Running"
                    If ($StopVMIfAttached -eq $false)
                        {
                            Write-Warning "StopVMAttached param is false. Quitting"
                            Break
                        }
                    Else
                        {
                            Write-Host ("Stopping VM @ " + (Get-Date))
                            Stop-AzureRMVM -Name $VMName -ResourceGroupName $ResourceGroupName -Force
                            Write-Host ("VM Now Stopped @ " + (Get-Date))
                        }
                }
            Else
                {
                    Write-Host "VM is Stopped"
                   
                }

            # Have to do this cos we need different format, 
            Write-Verbose "Regetting VM without status switch" 
            $VM = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName
                    
            If ($RemoveDisk)
                {
                    $VM = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName
                    Write-Host ("Removing DiskName = $DiskName from VM @ " + (Get-Date))
                    Remove-AzureRmVMDataDisk -VM $VM -DataDiskNames $DiskName | Update-AzureRMVM 
                }
            Else
                {
                    Write-Warning "Remove Disk is false"
                }
        # Figure out LUN 
        If ($VMSDataDisks -eq $null)
            {
                Write-Host "VM has no other Data Disks so setting LUN to 0"
                $LUN = 0
            }
        Else
            {
                    # Get the next available 
                    $MaxLun = $VMDataDisks | Sort Lun | Select -Last 1
                    $LUN = $MaxLun + 1
                    Write-Host "Maximum Current LUN = $MaxLUN, setting LUN = $LUN"
            }
    }
    Else
        {
            Write-Warning "$DiskName is not attached to a VM"
        }
 
    # Set the disk size and update it 
    $DataDisk.DiskSizeGB = $NewDiskSizeGB
    Write-Host ("Starting Update-AzureRMDisk to " + ($DataDisk.DiskSizeGB) + " Gbytes") 
    $UpdateDisk = Update-AzureRMDisk -Disk $DataDisk -ResourceGroupName $DataDisk.ResourceGroupName -DiskName $DataDisk.Name

    # Reattach to VM and restart it 
    If ($OwnerId -ne $null)
    {
            If ($RemoveDisk)
            {
                Write-Host ("Adding Disk back to VM @ " + (Get-Date))
                Add-AzureRmVMDataDisk -ManagedDiskId $DataDisk.id -VM $VM -Name $DataDisk.Name -LUN $LUN -CreateOption Attach | Update-AzureRmVM
            }

            # ie if VM was running before, restart
            If($Status -eq "PowerState/Running")
                {
                    Write-Host ("Restarting $VMName @ " + (Get-Date))
                    $StartVM = Start-AzureRMVM -Name $VMName -ResourceGroupName $ResourceGroupName
                }
            Else
                {
                    Write-Host "VM wasn't running before change so leaving alone"
                }

            Write-Host "Regetting VM to check Disks"
            $VM = Get-AzureRMVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name 
    
            $VM.StorageProfile.DataDisks | Select Name, DiskSizeGB, Lun, Caching, SourceImage, @{Name = "Type" ; Expression = {$_.ManagedDisk.StorageAccountType}} | ft 
        }
    Else
        {
            # reget if not attached to a VM 
            Write-Host "Disk not Attached to VM"
            Get-AzureRMDisk -ResourceGroupName $DataDisk.ResourceGroupName -DiskName $DataDisk.Name | Select Name, DiskSizeGB
        }
}
 