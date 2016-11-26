<# 
 .Synopsis
  Downloads Azure Documentation to Local Drive

 .Description
  Uses Azure Storage Cmdlets to download all Azure PDF based documentation locally.
  Checks to see if the up to date local copy exists and thus only downloads new / updated files.

  Prequisites - currently requires Azure Powershell cmdlets installed. Note don't require Azure Subscription as anonymous access. 

  Change Log
  ----------
  v1.00 Andy Ball 26/11/2016 Base Version
  v1.01 Andy Ball 26/11/2016 Added ConcurrentTaskCount for Blob download
  v1.02 Andy Ball 26/11/2016 Added GetURIsOnly param 

  Backlog 
  --------
  - Remove Powershell dependency by using say Invoke-WebRequest
  - Flatten Local Directory Structure so doesnt reflect deep path of Azure Blobs 
  
 .Parameter DestinationDirectory
  Root Local Directory where files are to be downloaded i.e C:\AzureDocs

 .Parameter StorageAccountName
  Storage AccountName where Azure Documentation is held. Defaults to opbuildstorageprod

 .Parameter ContainerName 
  Root Container in Storage Account where Azure Docs are held. Defaults to output-pdf-files

 .Parameter ContainerPathWildcard 
  Path below the container where Azure Docs are held. Defaults to en-us/Azure.azure-documents/live/*

 .Parameter GetFirstXBlobs 
  Only downloads the number specified , smallest first. This param generally used for testing
  
  .Parameter ConcurrentTaskCount 
   For Blob Copy. Default = 32 
   #https://github.com/Azure/azure-powershell/wiki/Microsoft-Azure-Storage-Cmdlets
   # By default, when you upload files from local computer to Windows Azure Storage, this cmdlet will initiate network calls up to eight times the number of cores this local computer had to execute concurrent tasks

   .Parameter GetURIsOnly
   If true just returns the full URI of each matching file. Default is false 

  .Parameter OutputFormat 
  Format that list of files is returned in either Object or Text or None 
  Default is None

  .Parameter DownloadSource
  Either:
    UseAzureCmdlets - Requires Azure Subscription and Azure Powershell Cmdlets as use Azure Storage Account Cmdlets to enum the list of files 
    FromJSONFile -    Will read from JSON file specified in $JSONFileLocation  for list of URIs to download 
                      This file can be created by running Set-AzureDocURIsJSON or by relying on the default json file in JSONFileLocation being update
                    
                      Advantage being works without Azure Sub / cmdlets but is much slowr

                      Current list of files can be generated with the -GetURIsOnly $true 

    Defaults to UseAzureCmdlets 

  .Parameter TextFileListLocation 
  FileName Used if -DownloadSource param is set to FromTextFileList. File should have full URI Per line  

 .Example
   Basic usage , gets all documents 
   Get-AzureDocumentation -DestDirectory "C:\AzureDocs" -UseAzureCmdlets

 .Example
   Only downloads the 10 smallest files. Used for testing
   Get-AzureDocumentation -DestDirectory "C:\AzureDocs" -FirstXBlobs 10 

 .Example 
  Just returns the URIs for all matching files
  Get-AzureDocumentation -DestDirectory "C:\AzureDocs" -GetURIsOnly $true 

 .Example
  Compares / downloads files based on List helad in JSON file @ "https://cloudviewpubliclrsne.blob.core.windows.net/misc/AzureDocList.json"
  Note : This is much slower than useing           
  Get-AzureDocumentation -DestDirectory "C:\Training\AzureDocs2" -OutputFormat Object -DownloadSource FromJSONFile -JSONFileLocation =  "https://cloudviewpubliclrsne.blob.core.windows.net/misc/AzureDocList.json"
          
#>

Function Get-AzureDocumentation 
{
    Param
    (
        [Parameter(Mandatory = $true , Position = 0)] [string] $DestDirectory, 
        [Parameter(Mandatory = $false , Position = 1)] [string] $StorageAccountName = "opbuildstorageprod", 
        [Parameter(Mandatory = $false , Position = 2)] [string] $ContainerName = "output-pdf-files", 
        [Parameter(Mandatory = $false , Position = 3)] [string] $ContainerPathWildCard = "en-us/Azure.azure-documents/live/*",
        [Parameter(Mandatory = $false , Position = 4)] [int] $GetFirstXBlobs = 0  , 
        [Parameter(Mandatory = $false , Position = 5)] [int] $ConcurrentTaskCount = 32, 
        [Parameter(Mandatory = $false , Position = 6)] [boolean] $GetURIsOnly = $false, 
        [Parameter(Mandatory = $false , Position = 7)] [string] [ValidateSet("Object", "Text", "None")] $OutputFormat = "None",
        [Parameter(Mandatory = $false , Position = 8)] [ValidateSet ("UseAzureCmdlets", "FromJSONFile")] [string] $DownloadSource = "UseAzureCmdlets",
        [Parameter(Mandatory = $false , Position = 9)] [string]   $JSONFileLocation =  "https://cloudviewpubliclrsne.blob.core.windows.net/misc/AzureDocList.json"
          

    )

    $ErrorActionPreference = "Inquire" 
    # Store the Full URL in here in case we want to download directly / Without Azure Sub / 
    $FileURIs = @()
    $FileSummary = @()

    # So we dont wast time checking for 
    $NewDirCreated = $False 

    # Create Local Directory 
    If ( (Test-Path -Path $DestDirectory -PathType Container) -eq $false)
        {
            Write-Host "Creating Directory $DestDirectory"
            $NewDir = New-Item -Path $DestDirectory -ItemType Container
            $NewDirCreated = $true 
        }
    Else
        {
            Write-Host "$DestDirectory already exists"
            # ie so we can only copy down new / non existing files later 
            Write-Host "Getting existing Files in $DestDirectory"
            $ExistingLocalFiles = Get-ChildItem -Path $DestDirectory -Recurse -File
            Write-Host (@($ExistingLocalFiles).Count.ToString() + " existing files found in $DestDirectory")
        }

    
    # Get the filelist either from a pre uploaded JSON file with the details (Set-AzureDocURIsJSON cmdlet)
    # Either way the resultset will have same fields. 
    If ($DownloadSource -eq "FromJSONFile")
        {
            $DownloadFileName = $DestDirectory + "\AzureDocList.json"

            Write-Host "-DownloadSource param = FromJsonFile so downloading list from  $JSONFileLocation to $DownloadFileName"
            # Key is with JSON use Invoke-RESTMethod instead of Invoke-WebRequest otherwise data is returned wrong
            $BlobsAzure = Invoke-RESTMethod -Uri $JSONFileLocation -ContentType "application/json" -UseBasicParsing
            # Fix up LastModified field , cos its DateTime and because JSO
            $BlobsAzure = $BlobsAzure | Select ShortFileName, FullUri, Name, Length , @{Name = "LastModified" ; Expression = {$_.LastModified.value}}

            $Webclient = New-Object System.Net.WebClient
            
        }         
    # or by querying the Azure Docs Storage account
    Else
        {
             # Storage Context and then get matching Blobs
            Write-Host "Getting Storage Context for StorageAccount = $StorageAccountName"
            $StorageContext = New-AzureStorageContext -StorageAccountName opbuildstorageprod -Anonymous
            Write-Host "Getting Storage Blobs from https://$StorageAccountName/$ContainerPathWildCard"
            $BlobsAzure = Get-AzureStorageBlob -Container $ContainerName -Context $StorageContext | Where {$_.Name -like $ContainerPathWildCard} 
        }

    # For Debugging really 
    If ($GetFirstXBlobs -ne 0)
        {
            Write-Host "Getting the first $GetFirstXBlobs smallest blobs"
            $BlobsAzure = $BlobsAzure | Sort Length | Select -First $GetFirstXBlobs 
        }

    # See how much data..
    $BlobsTotalBytes = $BlobsAzure | Measure-Object -Sum Length
    $BlobsTotalMBytes = [math]::round($BlobsTotalBytes.Sum / 1024 / 1024, 2)
    
    # Array stunt in case only 1 
    $BlobCount = @($BlobsAzure).Count 
    $CurrentBlobNumber = 1 
    $FilesDownloaded = 0
    $FileSizeDownload = 0.00

    $StartTime = Get-Date 

    # Roll through and download 
    Write-Host "Processing $BlobCount Files, total size $BlobsTotalMbytes MBytes"
    ForEach ($Blob in $BlobsAzure)
        {
            #Add to Results
            $BlobShortName = (Split-Path $Blob.Name -Leaf)

            $FileURI = "https://" + $StorageAccountName +  ".blob.core.windows.net/" + $ContainerName + "/" + $Blob.Name 
            $FileURIs += $FileURI
            $FileSummary += $Blob | Select @{Name = "ShortFileName" ; Expression = {$BlobShortName}} , 
                                           @{Name = "LastModified" ; Expression = {$Blob.LastModified.DateTime}},
                                           @{Name = "FullUri" ; Expression = {$FileURI}},
                                           @{Name = "Name" ;Expression = {$Blob.Name}}, 
                                           @{Name = "Length" ;Expression = {$Blob.Length}}

            If ($GetURIsOnly -eq $false)
            {
                $ExistingLocalFile = $null
           
                $CopyFile = $false 
                $FoundMessage = $null 

                # ie no need to check if exists ! 
                If ($NewDirCreated)
                    {
                        $CopyFile = $true 
                    
                    }
                Else
                    {
                        $LocalDir = $DestDirectory + "\" + (Split-Path $Blob.Name -Parent) 
        
                        Write-Host ("`tChecking if " + $BlobShortName + " exists in $LocalDir")
                        $ExistingLocalFile = $ExistingLocalFiles | Where {$_.Name -eq $BlobShortName -and $_.DirectoryName -eq $LocalDir}
                        If ($ExistingLocalFile -ne $null)
                            {

                                $ExistingFileLastModified = $ExistingLocalFile.LastWriteTime
                                #ToDo:fix this at source , messy 
                                If ($DownloadSource -eq "UseAzureCmdLets")
                                    {
                                        $BlobLastModified = $Blob.LastModified.DateTime 
                                    }
                                Else
                                    {
                                       $BlobLastModified = $Blob.LastModified
                                    }
                                $FoundMessage = "`tExisting Local File Dated $ExistingFileLastModified found, Current Blob Date = $BlobLastModified"

                                If ($BlobLastModified -ge $ExistingFileLastModified )
                                    {
                                        $CopyFile = $true
                                        $FoundMessage += " so will overwrite."
                                    }
                                Else
                                    {
                                        $CopyFile = $false 
                                        $FoundMessage += " so skipping."
                                    }

                                Write-Host $FoundMessage
                            }


                        Else
                            {
                                Write-Host "`tExisting local file not found" 
                                $CopyFile = $true 
                            }
                        
                    }

                $BlobSizeMB = [math]::round($Blob.Length / 1024 / 1024, 2)
                If ($CopyFile)
                    {
                        Write-Host ("`tStarting copy of Blob = " + $BlobShortName + ", Size = " + $BlobSizeMB +  " Mbytes @ " + (Get-Date) + " ($CurrentBlobNumber of $BlobCount)") -ForegroundColor Green 
                        
                        If($DownloadSource -eq "UseAzureCmdlets")
                        {
                            $blobcontent = Get-AzureStorageBlobContent -Blob $Blob.Name -Destination $DestDirectory -Force -Container $ContainerName -Context $StorageContext -ConcurrentTaskCount $ConcurrentTaskCount
                        }
                        Else
                        {
                            $url = $Blob.FullUri
                            If ( (Test-Path $LocalDir) -eq $false)
                                {
                                    Write-Host "`tCreating Directory $LocalDir"
                                    $DirCreated = New-Item $LocalDir -ItemType Directory
                                }
                            $LocalFileName = $LocalDir + "\" + $BlobShortName
                         
                            $webclient.DownloadFile($url,$LocalFileName)

                        }

                        $FilesDownloaded++
                        $FileSizeDownloaded += $Blob.Length
                    }
                Write-Host ""
            }

            $CurrentBlobNumber ++
     
        }

    # Work out how long
    If ($GetURIsOnly -eq $false)
    {
        $EndTime = Get-Date 
        $TimeTakenSecs = [math]::round((New-TimeSpan -Start $StartTime -End $EndTime).TotalSeconds, 0)
        $FileSizeDownloadedMB = [math]::round($FileSizeDownloaded / 1024 / 1024 , 2)
        $MbytesASec = [math]::round($FileSizeDownloadedMB / $TimeTakenSecs , 2)
        Write-Host "$FilesDownloaded file(s) , total size = $FileSizeDownloadedMB Mbytes downloaded to $DestDirectory in $TimeTakenSecs secs at $MbytesASec Mbytes/sec" 
    }
    
    Write-Host ""
    # Finally return all the URI's   
    If ($OutputFormat -eq "Text")
        {
            $FileURIs 
        }
    ElseIf ($OutputFormat -eq "Object")
        {
            $FileSummary
        }
}


$ret = Get-AzureDocumentation -DestDirectory "C:\Training\AzureDocs2" -ConcurrentTaskCount 32 -DownloadSource UseAzureCmdlets
$ret
