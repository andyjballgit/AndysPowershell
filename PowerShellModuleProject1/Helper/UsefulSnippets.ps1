

#region Get current public facing IP Address
$MyIpAddress = Invoke-RestMethod -Method GET -uri "http://myexternalip.com/raw"
$MyIpAddress
#endregion 
