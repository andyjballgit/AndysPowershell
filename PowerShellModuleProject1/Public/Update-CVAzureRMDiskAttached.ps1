<# 
 .Synopsis
  Updates Size of an Azure Managed Disk even if attached to a VM (by detaching, resizing, reattaching if neccessary)

 .Description
 See https://docs.microsoft.com/en-us/azure/storage/storage-managed-disks-overview 

  Change Log
  ----------
  v1.00 Andy Ball 26/02/2017 Base Version
  v1.01 Andy Ball 27/02/2017 Handle VM that already has Multiple Data Disks , ie LUN numbers 

  Backlog 
  --------
 

 .Parameter DiskName
  
 .Parameter NewSizeGBytes
  
 .Parameter StopVMIfRunning 

 .Example
 Expands to 512Gb , stopping the VM it is attached to if running

    $DiskName = "MyServer-DataDisk-01"
    $Stop = $true 
    $NewDiskSizeGB = 512

Update-CVAzureRMDiskAttached -DiskName $DiskName -NewDiskSizeGB $NewDiskSizeGB -StopVMIfAttached $Stop 
 .Example

 .Example 

#>
Function Update-CVAzureRMDiskAttached
{
    Param
        (
            [Parameter(Mandatory = $true, Position = 0)]  [string] $DiskName,
            [Parameter(Mandatory = $true, Position = 1)]  [ValidateRange(1, 1023)] [int] $NewDiskSizeGB, 
            [Parameter(Mandatory = $false, Position = 2)] [boolean]  $StopVMIfAttached = $false  

        )

    $ErrorActionPreference = "Stop"

    $Disks = Get-AzureRMDisk

    $DataDisk = $Disks | Where {$_.Name -eq $DiskName}
    If ($DataDisk -eq $null)
        {
            Write-Warning "Cannot Find DiskName = $DiskName :" 
            $Disks | Sort Name | Select * | Out-String
            Break 

        }

    $CurrentDiskSizeGB = $DataDisk.DiskSizeGB
    If ($CurrentDiskSizeGB -ge $NewDiskSizeGB)
        {
            Write-Warning "CurrentDiskSize = $CurrentDiskSizeGB is greater or equal to NewDiskSizeGb = $NewDiskSizeGB. Quitting" 
            Break
        }

    $OwnerId = $DataDisk.OwnerId 
    If ($OwnerId -ne $null)
        {
            $Resource = Get-AzureRMResource -ResourceId $OwnerId
            $VMName = $Resource.Name 
            $ResourceGroupName = $Resource.ResourceGroupName 

            Write-Host "Disk is attached to VMName = $VMName in ResourceGroup = $ResourceGroupName, Doing Get-AzureRVM -Status on it"
            $VMStatus = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
            $Status = $VMStatus.Statuses[1].Code
            
            Write-Host "VM Status = $Status"
            If ($Status -eq "PowerState/Running")
                {
                    
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

            Write-Verbose "Regetting VM without status switch" 

            $VM = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName
            Write-Host ("Removing DiskName = $DiskName from VM @ " + (Get-Date))
            Remove-AzureRmVMDataDisk -VM $VM -DataDiskNames $DiskName | Update-AzureRMVM 

        }

    # reget as other was status
    $VM = Get-AzureRMVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name 
    $VMDataDisks = $VM.StorageProfile.DataDisks

    # ie it has no Data Disks so hard code LUN to 0 
    If ($VMSDataDisks -eq $null)
        {
            Write-Host "VM has no Data Disks so setting LUN to 0"
            $LUN = 0
        }
    Else
        {
            $MaxLun = $VMDataDisks | Sort Lun | Select -Last 1

            $LUN = $MaxLun + 1
            Write-Host "Maximum Current LUN = $MaxLUN, setting LUN = $LUN"
        }

    Write-Host "Setting Data Disk to New Size = $NewDiskSizeGB (from $CurrentDiskSizeGB)"
    $DataDisk.DiskSizeGB = $NewDiskSizeGB
    Update-AzureRMDisk -Disk $DataDisk -ResourceGroupName $DataDisk.ResourceGroupName -DiskName $DataDisk.Name

    If ($OwnerId -ne $null)
        {
            Write-Host ("Adding Disk back to VM @ " + (Get-Date))
            Add-AzureRmVMDataDisk -ManagedDiskId $DataDisk.id -VM $VM -Name $DataDisk.Name -LUN $LUN -CreateOption Attach | Update-AzureRmVM
    
            # ie if VM was running before, restart
            If($Status -eq "PowerState/Running")
                {
                    Write-Host ("Restarting $VMName @ " + (Get-Date))
                    Start-AzureRMVM -Name $VMName -ResourceGroupName $ResourceGroupName
                }
            Else
                {
                    Write-Host "VM wasn't running before change so leaving alone"
                }

            Write-Host "Regetting VM to check Disks"
            $VM = Get-AzureRMVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name 
    
            $VM.StorageProfile.DataDisks | Select * | ft
        }
    Else
        {
            # reget if not attached to a VM 
            Get-AzureRMDisk -ResourceGroupName $DataDisk.ResourceGroupName -DiskName $DataDisk.Name
        }
}
 


Update-CVAzureRMDiskAttached -DiskName CV-SRV-TEST-001-DataDisk-02 -NewDiskSizeGB 512 -StopVMIfAttached $TRUE 

