
$ContainerPrefix = "SQLRocks"
$PortNumberStart = 1501
$PortNumber = $PortNumberStart
$Instances = 50

For($Counter = 1 ; $Counter -le $Instances; $Counter++)
    {
        $ContainerName = $ContainerPrefix + $PortNumber
        Write-Host "Starting Container = $ContainerName ($Counter of $Instances) on Port = $PortNumber"
        $MyArgs = "run --name $ContainerName -d -p $PortNumber" + ":" + $PortNumber + " -e sa_password= -e ACCEPT_EULA=Y microsoft/mssql-server-windows-developer"
        
        Start-Process -FilePath docker.exe -ArgumentList $MyArgs -Wait

        $PortNumber++
    }