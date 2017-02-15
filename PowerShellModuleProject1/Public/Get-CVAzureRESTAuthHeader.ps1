<# 
 .Synopsis
  Generates an Authentication Token / Header that can then be used when calling Azure REST API's. See Examples Section for how to use with Invoke-RESTMethod

 .Description
  Adapted from below
  https://blogs.technet.microsoft.com/paulomarques/2016/04/05/working-with-azure-rest-apis-from-powershell-getting-page-and-block-blob-information-from-arm-based-storage-account-sample-script/
  
  Prequisites
  -----------
  List Modules
  Does it need RunAs Admin

  Returns 
  -------
  AuthorisationHeader object that can be used with Invoke-RESTMethod in the headers param 


  Limitations and Known Issues
  ----------------------------
  
  Backlog 
  --------
    
  Change Log
  ----------
  v1.00 Andy Ball 21/12/2016 Base Version

 
 .Parameter ApiEndpointUri
 Endpoint URI for Azure Managmeent. Defaults to "https://management.core.windows.net/" and this is unlikely to ever change
  
 .Parameter AADTenantID
 Azure Active Directory tenant id with permissions to Subscription. If this not specified then will use Get-AzureRMSubscription and pick out the 1st tenantid from the 1st Subscription
 
 .Example
  # Simply returns Subscription details
  $MyRESTAuth  = Get-LBEAzureRESTAuthHeader
  # this creates a header for the REST call, sometimes will have extra values , see Example 2
  $RESTHeader = @{'Authorization' = $MyRESTAuth }
  # this is the particular REST method in Azure you want to call , browse https://resources.azure.com for the relevant uris
  $AzureRESTUri = "https://management.azure.com/subscriptions?api-version=2014-04-01"
  $ret = Invoke-RESTMethod -Method Get -Uri $AzureRESTUri -Headers $RESTHeader
  $ret.value | Select displayName, SubscriptionId, state -ExpandProperty subscriptionPolicies | ft 

  .Example
    # This example shows how to Export ARM Template using REST API - basically does what Export-AzureRMResourceGroup does
    # Important as it shows how some API calls use XPATH Queries / commands

    $ErrorActionPreference = "Stop"

    #Change these
    $ResourceGroupName = "LBE-RG-MOVE-001"
    $SubscriptionName = "Non-Live"
    #
    $OutputFile = "c:\temp\$ResourceGroupName.json"
    $SubscriptionId = (Get-AzureRMSubscription | Where {$_.SubscriptionName -eq $SubscriptionName}).SubscriptionId 

    # the API use an XPath query and this goes into head
    $XPathQuery = "/subscriptions/" + $SubscriptionId + "/resourcegroups/" + $ResourceGroupName + "/exporttemplate?api-version=2015-11-01"
    $JSONBody = "{'resources':['*'],'options':3}" 
    $InvokeURI = "https://management.azure.com/api/invoke?_=1"

    #initialize Header with the Auth field
    $Header = @{'Authorization' = (Get-LBEAzureRESTAuthHeader)}

    # Now add the other stuff to the Header that is required for this particular call, ie XPath query and Command
    $Header += @{'Accept-Encoding' = 'gzip, deflate' ; 
                      'Accept-Language' = 'en'
                     'x-ms-path-query' = $XPathQuery ;
                     'x-ms-effective-locale' = 'en.en-us';
                    'x-ms-command-name' = 'TemplateViewer.generateTemplate';
                   }

    # Finally do the Invoke / Export
    Write-Host "`tInvoking uri = $InvokeURI with XPathQuery = $XPathQuery"
    $RESTResult = Invoke-RestMethod -Method Post -Uri $InvokeUri -Headers $Header -verbose -Body $JSONBody -ContentType "application/json"
    Write-Host "Writing ARM Template to $OutputFile" -ForegroundColor Magenta
    $RESTResult.template | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputFile 

#>
Function Get-CVAzureRESTAuthHeader
  {

     Param
     (
          [Parameter(Mandatory=$false, Position = 0 )] [string] $ApiEndpointUri = "https://management.core.windows.net/" ,
          [Parameter(Mandatory=$false, Position = 1 )] [string] $AADTenantID
     )
   
    $ErrorActionPreference = "Stop"
     If ([string]::IsNullOrWhiteSpace($AADTenantID))
        {
            Write-Host "AADTenantID is null, so getting TenantID from first Subscription returned by Get-AzureRMSubscrption"
            $Subs = Get-AzureRMSubscription 
            $SubscriptionName = $Subs[0].SubscriptionName
            $TenantId = $Subs[0].TenantId
            Write-Host "Using TenantId = $TenantId from SubscriptionName = $SubscriptionName"
            Write-Host ""
            $AADTenantID = $TenantId 

        }

     Write-Verbose "AADTentantID = $AADTenantID"

     $adal = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\" + `
              "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
     $adalforms = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\" + `
                  "Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
     
     Write-Verbose "Loading Assemblies"
     [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
     [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
     
     $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"
     $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
     $authorityUri = "https://login.windows.net/$AADTenantID"
     
     Write-Verbose "Creating New Auth Context with URI = $authorityUri"
     $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authorityUri
     
     $authToken = $authContext.AcquireToken($ApiEndpointUri, $clientId,$redirectUri, "Auto")
   
     $AuthHeader = $authToken.CreateAuthorizationHeader()
     $AuthHeader
}
