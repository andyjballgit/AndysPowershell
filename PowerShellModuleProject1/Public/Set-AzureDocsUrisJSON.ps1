<# 
 .Synopsis
  Calls Get-AzureDocumentation to get list of current Azure Powershell docs and then pushes summary to Azure Storage Account Blob
  container in JSON format.

  Idea is that people then can run Calls Get-AzureDocumentation with the -DownloadSource "FromJSONFile" to read this uploaded file to 
  pull down Azure docs without having to have Azure Cmdlets installed. 

 .Description
  

  Prequisites - Depends on Get-AzureDocmentation enumerate list of Azure docs and Post in JSON format 
                Requires Azure Subscription 
                Requires Azure RM Powershell cmdlets installed
                Logged in via Login-AzureRMAccount 

                
  Returns - nothing 

  Change Log
  ----------
  v1.00 Andy Ball 26/11/2016 Base version

  Backlog 
  --------
  
 .Parameter StorageAccountName
  Azure Resource Manager Account Name where you want to push JSON file

 .Parameter ContainerName
  Blob Storage Container where you want to push JSON file 

 .LocalJSONOutputDirectory
  Local Directory to temporarily store the JSON outputted by Get-AzureDocumentation before uploading to blob storage 
 
 .Example
  Upload-AzureDocsJSONFile -LocalJSONOutputDirectory "C:\Training\AzureDocs" -StorageAccountName "cloudviewpubliclrsne" -ContainerName "misc" 


#>
Function Upload-AzureDocsJSONFile 
{
    Param
        (
            [Parameter(Mandatory = $true, Position = 0)]  [string] $StorageAccountName,
            [Parameter(Mandatory = $true, Position = 1)] [string] $ContainerName, 
            [Parameter(Mandatory = $true, Position = 1)] [string] $LocalJSONOutputDirectory 

        )
	#Requires -Modules AzureRM.Profile, Azure.Storage
    $ErrorActionPreference = "Stop"
    # So dont have to pass in Resource Group Name 
    $RMStorageAccount = Get-AzureRmStorageAccount | Where {$_.StorageAccountName -eq $StorageAccountName}
    If ($RMStorageAccount -eq $null)
        {
            Write-Warning "StorageAccountName = $StorageAccountName not found quitting"
            Break 
        }

    $ErrorActionPreference = "Stop"
    Write-Host "Creating new StorageContext to $StorageAccountName"
    $Key = Get-AzureRmStorageAccountKey -Name $StorageAccountName -ResourceGroupName $RMStorageAccount.ResourceGroupName 
    $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $Key[0].value
    
    Write-Host "Calling Get-AzureDocumentation to get output object" 
    $FileSummary = Get-AzureDocumentation -DestDirectory $LocalJSONOutputDirectory -GetURIsOnly $true -OutputFormat Object
    $FileSummaryJSON = $FileSummary | ConvertTo-Json 
    
    $LocalJSONOutputFileName = $LocalJSONOutputDirectory + "\AzureDocList.json" 
    Write-Host "Writing File list to $LocalJSONOutputFileName"
    $FileSummaryJSON | Out-File $LocalJSONOutputFileName -Encoding ascii -Force 

    Write-Host "Uploading $LocalJSONOutputFileName to $StorageAccountName\$ContainerName container"
    Set-AzureStorageBlobContent -File $LocalJSONOutputFileName -Container $ContainerName -Context $StorageContext -Force 

}
