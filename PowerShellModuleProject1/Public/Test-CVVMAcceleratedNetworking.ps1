<# 
 .Synopsis
  Returns true if Accelerated Networking is supported for given VM Size / Region / OS Combo 

 .Description
  Based on https://azure.microsoft.com/en-gb/updates/accelerated-networking-in-preview/
  See below for more detail - specifically limitations section 

  Prequisites
  -----------
  Azure Modules

  Returns 
  -------
  true if supports / false if not 


  Limitations and Known Issues
  ----------------------------
  - Only Supports Windows 
  - Only Supports UK / West Europe (North Europe not available as of this writing)

  Backlog 
  -------
        
  Change Log
  ----------
  v1.00 Andy Ball 19/07/2017 Base Version
 
 .Parameter VMSize
 Size of the VM - as per Get-AzureRMVMSize. 

 .Parameter Location
 Azure Location where you want to deploy

 .Parameter OS 
 Currently limited to Windows (various Linux flavours in Preview)

 .Example
    $VMSize = "Standard_F8"
    $Location = "uksouth"

    Test-CVVMAcceleratedNetworking -VMSize $VMSize -Location $Location -OS Windows


 .Example

 .Example 

#>
Function Test-CVVMAcceleratedNetworking
{
    Param
        (
            [Parameter(Mandatory = $true, Position = 1)]  [string] $VMSize, 
            [Parameter(Mandatory = $true, Position = 2)]  [string] $Location,
            [Parameter(Mandatory = $true, Position = 3)]  [string] [ValidateSet("Windows")] $OS = "Windows"

        )

    #  See https://azure.microsoft.com/en-gb/updates/accelerated-networking-in-preview/
    $IsSupported = $false 
    $SupportedLocations = @(
                            "uksouth", 
                            "ukwest", 
                            "westeurope"
                           )
    
    <#
            West Central US
            East US
            East US 2
            West US
            West US 2
            North US
            South US
            West Europe
            Brazil South
            UK West
            UK North
            UK South
            UK South 2
            Asia East
            Asia Southeast
            Korea South
            Korea Central
            Australia Southeast
            Australia East
            Japan East
            Canada East
            Canada Central
    #>

    $SupportedVMSizes = @( "Standard_D4_v2" ,
                           "Standard_DS4_v2" , 
                           "Standard_D5_v2" ,
                           "Standard_DS5_v2" , 
                           "Standard_F8", 
                           "Standard_F8s", 
                           "Standard_F16",
                           "Standard_F16s",
                           "Standard_D13_v2",
                           "Standard_D13_v2",
                           "Standard_D14_v2",
                           "Standard_D14_v2"                                  
                           "Standard_D15_v2",
                           "Standard_D15_v2"
                         )
    
    If ($Location -notin $SupportedLocations)
        {
            Write-Host ("Location = $Location is found in list of Locations that Supported Accelerated Networking below:`r`n`r`n" + ($SupportedLocations | Sort | Out-String)) -ForegroundColor Red
        }
    Else
        {
            If ($VMSize -notin $SupportedVMSizes)
                {
                    Write-Host ("VMSize = $VMSize is not found in list that support Accelerated Networking below:`r`n`r`n" + ($SupportedVMSizes | Sort | Out-String)) -ForegroundColor Red
                }
            Else 
                {
                    Write-Host ("VMSize = $VMSize IS supported in Location = $Location") -ForegroundColor Green 
                    $IsSupported = $true 
                }
        }

    # finally return IsSupported
    $IsSupported
}

