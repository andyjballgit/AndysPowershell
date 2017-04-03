<# 
 .Synopsis
  Uses REST API to get Azure Resource Health of either everything, for given resourcegroup or resourcename 

 .Description
  see - https://azure.microsoft.com/en-us/blog/reduce-troubleshooting-time-with-azure-resource-health/  
  Cant find it on docs.microsoft.com as of this writing

  Prequisites
  -----------
  - currently requires Azure Powershell cmdlets
  - Get-CVAzureRESTAuthHeader cmdlet in this repo : https://github.com/andyjballgit/AndysPowershell/blob/master/PowerShellModuleProject1/Public/Get-CVAzureRESTAuthHeader.ps1

  Change Log
  ----------
  v1.00 Andy Ball 03/04/2017 Base / Very raw version not much error checking / formatting etc 

  Issues 
  ------
  - Major bug , doesnt seem to pull back all VMs 

  Backlog 
  --------
  -
  -

 .Parameter Mode
 Either All (default), ResourceGroup, Resource
 dicates what API / what ItemName is checked for

 .Parameter ItemName
 If using ResourceGroup or Resource mode then this its name
  
 .Parameter OutputType 
    Raw - just as returned from REST API call 
    Pretty - with lookups of Resources , formatted as table 

 .Example
 $ret = Get-CVAzureResourceHealth -Mode All -OutputType Pretty -Verbose
 $VMs = $ret | where {$_.Resourcetype -eq "Microsoft.Compute/VirtualMachines"} | Select Name, ResourceGroupName | Sort Name 
 $VMs.Count 

 .Example

 .Example 

#>
Function Get-CVAzureResourceHealth
{
    Param
        (
            [Parameter(Mandatory = $false, Position = 0)]  [string] [ValidateSet("All", "ResourceGroup", "Resource")] $Mode = "All",
            [Parameter(Mandatory = $false, Position = 1)] [string] $ItemName,
            [Parameter(Mandatory = $false, Position = 2)] [string] [ValidateSet("Raw", "Pretty")] $OutputType = "Raw"
        )

    $ErrorActionPreference = "Stop"

    If ($Mode -ne "All" -AND [string]::IsNullOrWhiteSpace($ItemName))
        {
            Write-Warning "Mode Param = $Mode but ItemName param is missing. Quitting..."
            Break
        }

    # Build Header 
    $MyRESTAuth  = Get-CVAzureRESTAuthHeader
    $RESTHeader = @{'Authorization' = $MyRESTAuth }

    # Get Subscription Details 
    $Context = Get-AzureRmContext 
    $SubscriptionName = $Context.Subscription.SubscriptionName
    $SubscriptionId = $Context.Subscription.SubscriptionId

    # because if Raw we don't need list of resources for lookup / save time 
    If ($OutputType -ne "Raw")
        {
            # Get all Resources so we can lookup 
            Write-Host ("Getting all Resources in SubscriptionName = $SubscriptionName @ " + (Get-Date))
            $AllResources = Get-AzureRMResource 
            Write-Host ("Finished all Resources in SubscriptionName = $SubscriptionName @ " + (Get-Date))
    }

    Switch ($Mode)
    {
        "All"  {
                    $ProcessingMessage = "`r`n*** Processing All Resources for Subscription = $SubscriptionName"
                    $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.ResourceHealth/availabilityStatuses?api-version=2015-01-01"

               }

        "ResourceGroup"
               {
                     $ProcessingMessage = "`r`n*** Processing ResourceGroupName = $ResourceGroupName for Subscription = $SubscriptionName"
                     $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ItemName/providers/Microsoft.ResourceHealth/availabilityStatuses?api-version=2015-01-01"

               }            
        
        "ResourceType"
               {
                    Throw "ResourceType functionality Not Implemented yet"
               }
    }

    Write-Host $ProcessingMessage 
    Write-Host "Calling URI = $Uri" 
    $RESTResult = Invoke-RESTMethod -Method Get -Uri $uri -Headers $RESTHeader
    
    If ($OutputType -eq "Pretty")
        {
            $ResultSet = @()

            ForEach ($RAWHealthResource in $RESTResult.value)
                {
                    $RAWHealthResourceId = $null 
                    $RAWHealthResourceId = $RAWHealthResource.id 
                    
                    Write-Host ("Processing Resource = " + $RAWHealthResourceId)
                    # ie by stripping of end bit should give us the actual resource id
                    $ActualResourceId = $RAWHealthResourceId.Replace("/providers/Microsoft.ResourceHealth/availabilityStatuses/current", "")
                    Write-Verbose "Actual Resource ID = $ActualResourceId"
                  
                    # Now try and get the actual resource  
                    $Resource = $null 
                    $Resource = $AllResources | Where {$_.ResourceId -eq $ActualResourceId}
                    If ($Resource -eq $null)
                        {
                            Write-Warning ("Cannot find ResourceId = " + $ActualResourceId)

                        }
                    Else
                        {
                            # Glue Health and Resource details together 
                            $Row = $Resource | Select Name, 
                                                      ResourceGroupName, 
                                                      @{Name = "AvailabilityState" ; Expression = {$RAWHealthResource.Properties.availabilityState}}, 
                                                      ResourceType, 
                                                      Location, 
                                                      @{Name = "Summary" ; Expression = {$RAWHealthResource.Properties.summary}}, 
                                                      @{Name = "DetailedStatus" ; Expression = {$RAWHealthResource.Properties.DetailedStatus}}, 
                                                      @{Name = "OccurredTime" ; Expression = {$RAWHealthResource.Properties.OccuredTime}}, 
                                                      @{Name = "ReportedTime" ; Expression = {$RAWHealthResource.Properties.ReportedTime}}, 
                                                      @{Name = "ReasonChronicity" ; Expression = {$RAWHealthResource.Properties.reasonChronicity}}
                                                   
                            # And add to resultset 
                            $ResultSet += $Row 

                        }
                    
                }


           # return resultset
           $ResultSet
        }

    # currently raw 
    Else
        {
            $RESTResult
        }
}

