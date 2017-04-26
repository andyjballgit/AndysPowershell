

#region Get current public facing IP Address
$MyIpAddress = Invoke-RestMethod -Method GET -uri "http://myexternalip.com/raw"
$MyIpAddress
#endregion 

#region Billing  - non EA	https://azure.microsoft.com/en-gb/blog/azure-billing-reader-role-and-preview-of-invoice-api/

    $Latest = Get-AzureRmBillingInvoice -Latest
    Invoke-WebRequest -uri $Latest.DownloadUrl -OutFile "c:\temp\latestinvoice.pdf"

    . "c:\temp\latestinvoice.pdf"
    
    $RESTHeader =  $Header = @{'Authorization' = (Get-CVAzureRESTAuthHeader)}


    $url = "https://management.azure.com/providers/Microsoft.Billing/operations?api-version=2017-02-27-preview"
    $ret = Invoke-RESTMethod -Method get -uri $url -Headers $RESTHeader
    $ret.value
#endregion 


