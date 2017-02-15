
<# 
 .Synopsis
  Use Azure REST API to get Service Map details

 .Description
  See 
  
  Prequisites
  -----------
  Get-AzureRESTAuthHeader

  Returns 
  -------
  ie the type of object returned if any 


  Limitations and Known Issues
  ----------------------------
  
  Backlog 
  --------
    
  Change Log
  ----------
  v1.00 Joe Blogs DD/MM/YYYY Base Version

 
 .Parameter OMSWorkspaceName
  
 .Parameter OMSResourceGroupName
  
 .Example
 
  $res =  Get-AzureRmResourceProvider -ListAvailable | Where {$_.ProviderNamespace -like "Microsoft.OperationalInsights"}
  $res.ResourceTypes.ResourceTypeName

   Select ProviderNameSpace | Sort ProviderNameSpace

   Register-AzureRmResourceProvider -ProviderNamespace Microsoft.OperationalInsights

  Get-ServiceMapSummary 


 .Example

 .Example 

#>
Function Get-ServiceMapSummary
{
    Param
        (
            [Parameter(Mandatory = $true, Position = 0)]  [string] $OMSWorkspaceName,	
            [Parameter(Mandatory = $true, Position = 1)]  [string] $OMSResourceGroupName
        )

    $ErrorActionPreference = "Stop"

    $CurrentSub = (Get-AzureRMContext).Subscription
    $CurrentSubscriptionName = $CurrentSub.SubscriptionName
    Write-Host "Current SubscriptionName = $CurrentSubscriptionName"
    $SubscriptionID = $CurrentSub.SubscriptionId

    # $uri = "https://management.azure.com/api/subscriptions/$SubscriptionID/resourceGroups/$OMSResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$OMSWorkspaceName/features/serviceMap/summaries/machines?api-version=2015-11-01-preview"
   $uri = "https://management.azure.com/subscriptions/$SubscriptionID/resourceGroups/$OMSResourceGroupName/providers/Microsoft.OperationalInsights/$OMSWorkspaceName/features/serviceMap/summaries/machines?api-version=2015-11-01-preview"
   
#    $uri = "https://management.azure.com/subscriptions/$SubscriptionID/resourceGroups/$OMSResourceGroupName/providers/Microsoft.OperationalInsights" + "?api-version=2016-09-01"
    
    Write-Host $uri 
    $Header = @{'Authorization' = (Get-CVAzureRESTAuthHeader)}

    Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Operations
    $res = Invoke-RestMethod -Method GET -Uri $uri -Headers $Header -Debug -Verbose
    # GET /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}/features/serviceMap/summaries/machines?api-version=2015-11-01-preview[&startTime&endTime]
    $res 

}

  
Get-ServiceMapSummary -OMSWorkspaceName  CloudviewWE -OMSResourceGroupName cloudviewneiaas 
