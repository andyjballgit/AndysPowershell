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
| Get-CVAzureRESTAuthHeader|Generates an Authentication Token / Header that can then be used when calling Azure REST API's. See Examples Section for how to use with Invoke-RESTMethod|
| Get-CVAzureVMBackupStatus|For given  VM Names or all VMs searches all Azure Recovery Services vaults in a given subscription to see if backed up|
| Get-GitHubLatestRelease|Parses a Github / Markdown ChangeLog file and extracts the details between the 2 ## lines|
| Get-MarkDownFileForCmdLets|For a given wildcard will generate a Markdown table / file of Name , Synopsis. Markdown is used in Git for rich documentation..|
| Set-AzureDocsUrisJSON|Calls Get-AzureDocumentation to get list of current Azure Powershell docs and then pushes summary to Azure Storage Account Blob container in JSON format.|
| Update-CVAzureRMDiskAttached|Updates Size of an Azure Managed Disk even if attached to a VM (by detaching, resizing, reattaching if neccessary)|

