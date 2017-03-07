$ErrorActionPreference = "Stop"
$DoRegisterProviders = $false
$DoDeleteResourceGroup = $true
$DoStopVM = $true
$DoStartVMAfterIncrease = $true 
$DoIncreaseSize = $true 

$ResourceGroupName = "CV-RG-TEST-003"
$VMName = "CV-SVR-TEST-003"
$AdminUserName = "Andy"
$ResourceGroupLocation = "North Europe"
[int]$DataDiskSizeGBInitial = 256

$IncreaseDataDiskSizeGB = 10 

$templateFilePath = $PSScriptRoot + "\azuredeploy.json"


$parametersFilePath = $PSScriptRoot + "\azuredeploy.parameters.json"
$params = @{MyVMName=$VMName;
            dnsLabelPrefix= ($VMName.ToLower().Replace("-", ""));
            adminUserName = $AdminUserName;
            DataDiskSizeGB = $DataDiskSizeGBInitial
            }




#A. 
If ($DoDeleteResourceGroup)
    {
        $RGs = Get-AzureRmResourceGroup
        $RG = $RGs | Where {$_.ResourceGroupName -eq $ResourceGroupName}
        If ($RG -eq $null)
            {
                Write-Host "Cannot find $ResourceGroupName"
                
            }
        Else
            {
                Write-Host "$ResourceGroupName found, deleting"
                Remove-AzureRmResourceGroup -Name $ResourceGroupName
            }    
    }


# 1. Register Providers
If ($DoRegisterProviders)
{


    # Register RPs
    $resourceProviders = @("microsoft.automation","microsoft.compute","microsoft.network","microsoft.storage");
    if($resourceProviders.length) {
        Write-Host "Registering resource providers"
        foreach($resourceProvider in $resourceProviders) {
            RegisterRP($resourceProvider);
        }
    }
}


# 2. Create or check for existing resource group
$ResourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

#3, Start the deployment
Write-Host ("*** Starting deployment at " + (Get-Date)) -ForegroundColor Magenta
If ($params -ne $null)
    {
        Write-Host ("Using Params object with : `r`n" + ($Params | Out-string))
        $DeployResult = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath  -TemplateParameterObject $params -Verbose
    }

Else
    {
    if(Test-Path $parametersFilePath)
        {
            Write-Host "`tUsing template file = $templateFilePath"
            Write-Host "`t Using Params from $parametersFilePath"

            New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath  -TemplateParameterFile $parametersFilePath -Verbose
        } 
    Else 
        {
             Write-Host "`tUsing template file = $templateFilePath with default / built in values"
            New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -Verbose
        }
}

$DeployResult | Out-String 
If ($DeployResult.ProvisioningState -eq "Failed")
    {
        Write-Host ("*** FAILED deployment at " + (Get-Date)) -ForegroundColor Red
        Break 
    }

Write-Host ("*** Finished deployment at " + (Get-Date)) -ForegroundColor Magenta

#4. Increase Size 
If ($DoIncreaseSize)
{
    Write-Host ("*** Resizing VM at " + (Get-Date)) -ForegroundColor Magenta
    Write-Host "`tGetting VM"
    $VM = Get-AzureRMVM -Name $VMName -ResourceGroupName $ResourceGroupName
    If ($VM -eq $null)
        {
            Write-Host "Unable to get VM = $VMName from ResourceGroup = $ResourceGroupName"
            Break
        }

    If($DoStopVM)
        {
            Write-Host ("`tStopping VM @ " + (Get-Date))
            $VM | Stop-AzureRMVM -Force
        }
    $DataDiskName = $VM.StorageProfile.DataDisks[0].Name
    Write-Host "`t Getting First Data Disk = $DataDiskName"
    $DataDisk = Get-AzureRMDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName

    $CurrentSizeGB = $DataDisk.DiskSizeGB
    $NewSizeGB = $CurrentSizeGB + $IncreaseDataDiskSizeGB 
    $DataDisk.DiskSizeGB = $NewSizeGB 

    Write-Host "`tIncreasing DataDisk = $DataDiskName from $CurrentSizeGB to $NewSizeGB Gbytes"
    Update-AzureRmDisk -Disk $DataDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName -Verbose 

    Write-Host "`Regetting Data Disk = $DataDiskName"
    $UpdatedDataDisk = Get-AzureRMDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName
    $UpdatedDataDisk | Select Name, DiskSizeGB, CreateOption | Out-String 

    If ($DoStartVMAfterIncrease)
        {
            Write-Host ("`tRestarting VM at " + (Get-Date))
            $VM | Start-AzureRMVM 
        }
    
}

