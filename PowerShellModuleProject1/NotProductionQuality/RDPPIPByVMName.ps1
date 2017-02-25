$VMName = "SomeServer"

$VM = Get-AzureRMVM | Where Name -eq $VMName 

$Resource  = Get-AzureRMResource -ResourceId $VM.NetworkProfile.NetworkInterfaces.iD 
$PIP = Get-AzureRMResource -ResourceId ($Resource.Properties.ipConfigurations[0].properties.publicIPAddress.id) 
$PIPAddress = $Pip.Properties.ipAddress

$Params =  "/v:$PIPAddress"
Start-Process -FilePath "MSTSC.exe" -ArgumentList $Params 





