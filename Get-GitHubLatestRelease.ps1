<# 
 .Synopsis
  Parses a Github / Markdown ChangeLog file and extracts the details between the 2 ## lines

 .Description
  
  Prequisites - Powershell 3.0 / Internet Access

  Change Log
  ----------
  v1.00 Andy Ball 10\12\2016

  Backlog 
  --------
  
 .Parameter ChangeLogUri 
 the raw Uri to the Github ChangeLog file 
 Defaults to Azure Powershell - https://raw.githubusercontent.com/Azure/azure-powershell/dev/ChangeLog.md

 .Example
 default to Azure Powersehll
 Get-GitHubLatestRelease

 .Example
 Another name uri
 Get-GitHubLatestRelease -ChangeLogUri "https://raw.githubusercontent.com/andyjballgit/AndysPowershell/master/ChangeLog.md"

#>

Function Get-GitHubLatestRelease
{
    Param
        (
            [Parameter(Mandatory = $false, Position = 0)] [string] $ChangeLogUri = "https://raw.githubusercontent.com/Azure/azure-powershell/dev/ChangeLog.md" 
        )
 
    $ErrorActionPreference = "Stop"
    $ret = Invoke-RESTMethod -uri $ChangeLogUri
    $Rows = ($ret -split '\n')
    $Output = ""
    $RowCounter = 1 
    ForEach ($Row in $Rows)
        {
            If($RowCounter -ne 1)
                {
                    If ([string]::IsNullOrWhiteSpace($Row) -eq $false)
                        {
                            If($Row.Substring(0, 2) -eq "##")
                                {
                                    break
                                }
                            Else
                                {
                                    $Output += $Row + "`r`n"
                                }
                        }
                }
            Else
                {
                    $Output += $Row + "`r`n"
                }
            $RowCounter++
        }
    $Output 
}

Get-GitHubLatestRelease