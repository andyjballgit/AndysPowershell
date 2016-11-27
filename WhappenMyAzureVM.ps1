<# 
 .Synopsis
  For a given VM Name and Resource Group name will load up the Boot Diagnostics Web page so can see status

 .Description
  See above

  Prequisites - currently requires Azure Powershell cmdlets installed. 

  Change Log
  ----------
  v1.00 Andy Ball 23\11\2016 Base Version 
  v1.01 Andy Bakk 27\11\2016 If VM Name not found , output a list of all VMs

  Backlog 
  --------
  - Option so just generates URL without doing Get-AzureRMVM , so don't have to have Azure Cmdlets installed
  - Cmdlet Binding so can pipe.
  

 .Parameter VMName
  Name of the Azure VM
  
 .Parameter ResourceGroupName 
  Resource Group the VM resides in 
  
 .Example
 WhappenMyAzureVM -VMName "MyVM" -ResourceGroupName "ItsResourceGroupName"
 
#>
Function WhappenMyAzureVM
{
    Param
    (
     [Parameter (Mandatory = $true , Position = 0)] [string] $VMName,
     [Parameter (Mandatory = $true , Position = 1)] [string] $ResourceGroupName
    )

    # Yes i know about Find-AzureRMResource...
    $VMs = Get-AzureRMVM 
    $VM = $VMs | Where {$_.Name -eq $VMName -AND $_.ResourceGroupName -eq $ResourceGroupName}
    If ($VM -eq $null)
    {
        Write-Host "Cannot find VM = $VMName in resourceGroupName = $ResourceGroup, heres whats available"
        $VMs | Select Name, ResourceGroupName | Sort Name, ResourceGroupName 
       
    }
    Else
        {
            $URL = "https://portal.azure.com/#resource/" + $VM.Id + "/bootDiagnostics"
            Start-Process -FilePath $URL
        }

}

#WhappenMyAzureVM -VMName "myVMName" -ResourceGroupName "MyResourceGroupName"
