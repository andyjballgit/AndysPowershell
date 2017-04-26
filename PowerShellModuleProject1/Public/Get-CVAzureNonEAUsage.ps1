<# 
 .Synopsis
  Downloads the Usage data for a non-Enterprise Agreeement Subscription

 .Description
  

  Prequisites
  -----------
  - currently requires Azure Powershell cmdlets installed. Note don't require Azure Subscription as anonymous access. 

  Change Log
  ----------
  v1.00 Andy Ball 06/04/2017

  Backlog 
  --------
  -
  -

 .Parameter SubscriptionName
  Subscription to Query. If null uses current Subscription
  
 .Parameter StartDate
  
 .Parameter EndDate 

 .Example

 .Example

 .Example 

#>
Function Get-CVAzureNonEAUsage
{
    Param
        (
            [Parameter(Mandatory = $false, Position = 0)]  [string] $SubscriptionName = $null,
            [Parameter(Mandatory = $true,  Position = 1)] [DateTime] $StartDate,
			[Parameter(Mandatory = $false,  Position = 2)] [DateTime] $EndDate = $StartDate.AddDays(-1)

        )

	$AuthHeader = Get-CVAzureRESTAuthHeader
    
    Write-Host "Getting SubscriptionId"
    $SubscriptionId = (Get-AzureRmContext).Subscription.SubscriptionId
    Write-Verbose "SubscriptionId = $SubscriptionId"

    $URI = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Commerce/UsageAggregates?api-version=2015-06-01-preview&reportedStartTime=2017-04-01T00%3a00%3a00%2b00%3a00&reportedEndTime=2017-04-05T00%3a00%3a00%2b00%3a00&aggregationGranularity=Daily&showDetails=false"
     $URI

    $res = Invoke-RestMethod -Method Get -Uri $URI -Headers $RESTHeader
    $res.value.properties | Select meterName, meterCategory, unit, Infofields, quantity -ExpandProperty instanceData


    
}

$StartDate = (Get-Date).AddDays(-1)
Get-NonEAUsage -StartDate $StartDate -Verbose