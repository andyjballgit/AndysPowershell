<# 
 .Synopsis
  Removes a given VM / ResourceGroup and all its disks 

 .Description
  Blah Blah 

  Prequisites
  -----------

  Change Log
  ----------
  v1.00 Andy Ball 12/03/2017

  Backlog 
  --------
  -
  -

 .Parameter Name
 Name of VM
  
 .Parameter ResourceGroupName
 VMs Resource Group Name

 .Parameter Force
 Switch whether to pass in Force

 .Example

 .Example

 .Example 

#>
Function Remove-AzureRMVMAndDisks
{
    Param
        (
            [Parameter(Mandatory = $true, Position = 0)]  [string] $Name,
            [Parameter(Mandatory = $true, Position = 1)] [string] $ResourceGroupName, 
            [Parameter(Mandatory = $false, Position = 2)] [switch] $Force 

        )

    Write-Host "Getting all VMs"
    $AllVMs = Get-AzureRMVM 
    $VM = $AllVMs | Where {$_.Name -eq $Name -AND $_.ResourceGroupName -eq $ResourceGroupName}
    If ($VM -eq $null) 
        {
            Write-Warning "Cannot find VM = $Name in ResourceGroupName = $ResourceGroupName" 
            Write-Host ($AllVMs | Select Name, ResourceGroupName | Out-String)
            Break 
        }

    $OSDisk = $VM.StorageProfile.OsDisk
    $DataDisks = $VM.StorageProfile.DataDisks
    $OSDiskName = $OSDisk.Name

    Write-Host "Removing VM"
    Remove-AzureRMVM -Name $Name -ResourceGroupName $ResourceGroupName

    Write-Host "Removing OSDiskName = $OSDiskName"
    $OSDisk | Remove-AzureRmDisk -ResourceGroupName $ResourceGroupName
    
    ForEach ($DataDisk in $DataDisks)
        {
            $DataDiskName = $DataDisk.Name 
            $DataDiskRG = $DataDisk.ResourceGroupName 

            Write-Host "Processing $DataDiskName"
            $DataDisk | Remove-AzureRMDisk -ResourceGroupName $ResourceGroupName
        }


}


Remove-AzureRMVMAndDisks -Name "CV-SRV-SCOM-001" -ResourceGroupName "CV-RG-INF-001"