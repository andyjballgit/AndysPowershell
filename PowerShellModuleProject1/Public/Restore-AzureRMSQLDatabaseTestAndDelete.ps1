<# 
 .Synopsis
  Restores a given point of time, for given Server , DB , Resource group and optionally runs given query to check

 .Description
  

  Change Log
  ----------
  v1.00 Andy Ball 03/05/2018

  Backlog 
  --------
  -
  -

 .Parameter ServerName
  
 .Parameter ResourceGroupName
  
 .Parameter DatabaseName

 .Parameter TargetDatabaseName 

 .Parameter TestQuery
 Optional Query to run against Restored database - ie to validate ok. If present username and password must be preset

 .Parameter PointInTime 
 When to restore to 

 .Parameter DoRestore
 Defaults to true, can set to false just to test query functionality 

 .Parameter UserName 
 used with TestQuery 

 .Parameter Password 
 used with TestQuery 

 .Example
    $RGName = "SomeRGName"
    $ServerName = "SomeSQLServer"
    $DBName = "MyDatabase"
    $TargetDBName = "MyDatabase_Test"
    $PointInTime = (Get-Date).AddDays(-1)
    $DoRestore = $true
    $Query = "Select TOP 1 from sys.objects order by create_Date desc"
    $UserName = "Bob"
    $Password = "Somepassword"

    Restore-AzureRMSQLDatabaseTestAndDelete -DoRestore $DoRestore `
                                            -Verbose `
                                            -ServerName $ServerName `
                                            -ResourceGroupName $RGName `
                                            -DatabaseName $DBName `
                                            -TargetDatabaseName $TargetDBName `
                                            -PointInTime $PointInTime `
                                            -TestQuery $Query `
                                            -UserName $UserName `
                                            -Password $Password
 .Example

 .Example 

#>
Function Restore-AzureRMSQLDatabaseTestAndDelete
{
    Param
        (
            [Parameter(Mandatory = $true, Position = 0)]  [string] $ServerName,
            [Parameter(Mandatory = $true, Position = 1)] [string] $ResourceGroupName, 
            [Parameter(Mandatory = $true, Position = 3)] [string] $DatabaseName, 
            [Parameter(Mandatory = $true, Position = 4)] [string] $TargetDatabaseName, 
            [Parameter(Mandatory = $true, Position = 5)] [datetime] $PointInTime, 
            [Parameter(Mandatory = $false, Position = 6)] [string] $TestQuery,
            [Parameter(Mandatory = $true, Position = 7)] [boolean] $DoRestore = $true,
            [Parameter(Mandatory = $false, Position = 8)] [string] $UserName,
            [Parameter(Mandatory = $false, Position = 9)] [String] $Password
    

        )

    $ErrorActionPreference = "Stop"
    $DoTestQuery = $false 

    #region Validate
    If ($PointInTime -ge (Get-Date))
        {
            Write-Warning "$PointInTime is greater than current time"
            Break
        }

    If([string]::IsNullOrWhiteSpace($TestQuery) -eq $false)
       {
            $DoTestQuery = $true 
            If( ([string]::IsNullOrWhiteSpace($UserName)) -OR ([string]::IsNullOrWhiteSpace($Password)) )
                {
                    Write-Warning "TestQuery provided so need Username and Password params to be provided"
                    Break 
                }
        }

    If ($DatabaseName -eq $TargetDatabaseName)
        {
            Write-Warning "Target and DatabaseName are both $DatabaseName. Quitting.."
            Break
        }
    #endregion 

    #Get Restore points to validate 
    $RestorePoints = Get-AzureRmSqlDatabaseRestorePoints -ServerName $ServerName -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName 
    If($RestorePoints -eq $null)
        {
            Write-Warning "Cannot find any restore points for ServerName = $ServerName, ResourceGroupName = $ResourceGroupName, DatabaseName = $DatabaseName"
            Break
        }
   
    Write-Verbose ("Restore Points`r`n " + ($RestorePoints | Out-String))
    Write-Host "Getting Database"
    $Database = Get-AzureRMSQLDatabase -DatabaseName $DatabaseName -ServerName $ServerName -ResourceGroupName $ResourceGroupName 
    
    If($DoRestore)
        {
            Write-Host ("Starting restore at " + (Get-Date))
            Restore-AzureRMSQLDatabase -FromPointInTimeBackup `
                                       -PointInTime $PointInTime `
                                       -ServerName $ServerName `
                                       -TargetDatabaseName $TargetDatabaseName `
                                       -ResourceGroupName $ResourceGroupName `
                                       -ResourceId $Database.ResourceId `
                                       -Edition Free
                               

            Write-Host ("Restore Finished @ " + (Get-Date))
        }
    Else
        {
            Write-Warning "DoRestore param is false , so skipping restore"
        }

    If ($TestQuery)
        {
            $ServerConnectionString = $ServerName + ".database.windows.net"
            Write-Host "Running Query = $TestQuery on $ServerConnectionString"
            $result = Invoke-Sqlcmd -ServerInstance $ServerConnectionString -Database $TargetDatabaseName -Username $UserName -Password $Password -Query $TestQuery -EncryptConnection 
            $result
        }
}


