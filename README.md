# Introduction
General Utility Powershell Functions 

# Pre-requisites
* Powershell 5.0 

# Backlog 

# Functions


| Cmdlet       | Summary           |
|------------- |-------------------|
| Get-AzureDocumentation|Downloads Azure Documentation to Local Drive|
| Get-AzureVMBootDiagnosticsScreen|For a given VM Name and Resource Group name will load up the Boot Diagnostics Web page so can see status|
| Get-CVAzureVMBackupStatus|For A Given VM Names or all VMs searches to if backed up by Azure Recovery Services|
| Get-GitHubLatestRelease|Parses a Github / Markdown ChangeLog file and extracts the details between the 2 ## lines|
| Get-MarkDownFileForCmdLets|For a given wildcard will generate a Markdown table / file of Name , Synopsis. Markdown is used in Git for rich documentation..|
| Set-AzureDocsUrisJSON|Calls Get-AzureDocumentation to get list of current Azure Powershell docs and then pushes summary to Azure Storage Account Blob container in JSON format.|

