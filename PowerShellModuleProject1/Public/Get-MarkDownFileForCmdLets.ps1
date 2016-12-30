<# 
 .Synopsis
  For a given wildcard will generate a Markdown table / file of Name , Synopsis. Markdown is used in Git for rich documentation..

 .Description
  See https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet#tables for details of Markdown tables
  
  Prequisites
  -----------
  None

  Returns 
  -------
  Markdown as a String


  Limitations and Known Issues
  ----------------------------
  - 14/12/2016 Some Synops is not being picked up ie Move-LBEAzureRMResourceGroupAll 

  Backlog 
  --------
  - Create / Process as object so can retirn as object / output to other formats , csv etc
  - Add a header / option to glue another .md file so can use for main ReadMe.md for a project, with overview etc. 
    
  Change Log
  ----------
  v1.00 Andy Ball 14/12/2016 Base Version
  v1.01 Andy Ball 15/12/2016 Add ReadMeMarkdownHeaderFileName parameter so can glue overview to this output to make a dynamic ReadMe.md
  v1.02 Andy Ball 19/12/2016 Extra Verbose statements as some Functions not parsing properly
   
 .Parameter CmdletWildcard
 ie the Cmdlets you want to dump in the form *SomeWildCard*
  
 .Parameter OutputFileName
 Where to write Markdown output to 

 .Parameter ReadMeMarkdownHeaderFileName
 Path to the Markdown header file that you want to add before table of Cmdlets that this Function provide. Idea is that it will contain overview of the Module, installation instructions etc. 
 Default to looking in Parent Directory for ReadMeHeader.md
  
 .Example
 Outputs to default filename which is <ParentDirectory>\ReadMe.md
 Get-LBEMarkDownFileForCmdLets -CmdletWildCard "*LBE*" -Verbose
 
 .Example
 Named file and anything that has standard LBE naming - ie <Verb>-LBE<Whatitdoes>
 Get-LBEMarkDownFileForCmdLets -CmdletWildCard "*-LBE*" -OutputFileName "c:\temp\MyMarkdown.md" -Verbose



#>
Function Get-MarkDownFileForCmdLets
{
    Param
        (
            [Parameter(Mandatory = $true, Position = 0)]  [string] $Module,
            [Parameter(Mandatory = $false, Position = 1)] [string] $OutputFileName = ((Get-Item -Path $PSScriptRoot).Parent.FullName + "\ReadMe.md"),
            [Parameter(Mandatory = $false, Position = 2)] [string] $ReadMeMarkdownHeaderFileName = ((Get-Item -Path $PSScriptRoot).Parent.FullName + "\ReadMeHeader.md")
        )

    $PSMajorVersion = $host.Version.Major
    If ($host.Version.Major -lt 3)
        {
            Write-Warning "Powershell Version = $PSMajorVersion, only Loaded Modules cmdlets will be returned. Starting v3.0 all modules are checked"
        }
    # https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet#tables
    $Header = "Last Updated : " + (Get-Date).ToLongDateString() + "`r`n"
    $Header = "| Cmdlet       | Summary           |" + "`r`n" + "|------------- |-------------------|"

    Write-Host "Running Get-Command with for Module $Module"
    # $Synopsises = Get-Command $CmdLetWildCard | Get-Help | Select Name, Synopsis -Unique | Sort Name
    $Commands = Get-Command -Module $Module
    $CommandCount = @($Commands).Count
    Write-Verbose "Found $CommandCount commands in Module"

    $Synopsises = $Commands | Get-Help | Select Name, Synopsis -Unique | Sort Name
    $OutputString = $Header + "`r`n"

    $CmdletCount = @($Synopsises).Count

    If($CmdLetCount -eq 0)
        {
            Write-Warning "No Cmdlets found for Module $Module"
            Break
        }

    Write-Host "Processing $CmdletCount Cmdlet(s)"
    $CurrentSynopsisNum = 1 

    ForEach ($Synopsis in $Synopsises)
        {
            $OutputString += "| " + $Synopsis.Name + "|" 
            Write-Verbose ("Processing Module " + ($Synopsis.Name) + "($CurrentSynopsisNum of $CmdLetCount)")

            # if no synopsis present it has leaves white space on first line
            $thing = $Synopsis.Synopsis.Split("`r`n")
            Write-Verbose ("`t" + $thing | Out-String)
            If([string]::IsNullOrWhiteSpace($thing[0]))
                {
                    Write-Verbose ("`t!!! " + $Synopsis.Name + " has no Synopsis")
                    $Summary = ":-( No Synopsis, fix it !"
                }
            Else
                {
                    Write-Verbose ("`t" + $Synopsis.Name + " has Synopsis")
                    $Summary = $Synopsis.Synopsis
                }
        
            $OutputString += $Summary + "|" + "`r`n"
            $CurrentSynopsisNum++
            
        } 

    Write-Host "Checking for ReadMe Markdown Header FileName = $ReadMeMarkdownHeaderFileName"
    If( Test-Path ($ReadMeMarkdownHeaderFileName))
        {
            Write-Host "Found File , adding above Function Table" -ForegroundColor Green
            $OutputString = (Get-Content -Path $ReadMeMarkdownHeaderFileName) + "`r`n" + $OutputString
        }
    Else
        {
            Write-Warning "File not found"
        }
    Write-Host "Writing Markdown to $OutputFileName"
    $OutputString | Out-File -FilePath $OutputFileName
    $OutputFileName
 
 }

