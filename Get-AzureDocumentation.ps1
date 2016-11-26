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

 .Example
   Basic usage , gets all documents 
   Get-AzureDocumentation -DestDirectory "C:\AzureDocs"

 .Example
   Only downloads the 10 smallest files. Used for testing
   Get-AzureDocumentation -DestDirectory "C:\AzureDocs" -FirstXBlobs 10 

 .Example 
  Just returns the URIs for all matching files
  Get-AzureDocumentation -DestDirectory "C:\AzureDocs" -GetURIsOnly $true 
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
        [Parameter(Mandatory = $false , Position = 6)] [boolean] $GetURIsOnly = $false 
          

    )

    # Store the Full URL in here in case we want to download directly / Without Azure Sub / 
    $FileURIs = @()

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
         

    # Storage Context and then get matching Blobs
    Write-Host "Getting Storage Context for StorageAccount = $StorageAccountName"
    $StorageContext = New-AzureStorageContext -StorageAccountName opbuildstorageprod -Anonymous
    Write-Host "Getting Storage Blobs from https://$StorageAccountName/$ContainerPathWildCard"
    $BlobsAzure = Get-AzureStorageBlob -Container $ContainerName -Context $StorageContext | Where {$_.Name -like $ContainerPathWildCard} 

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
            $FileURIs += "https://" + $StorageAccountName +  "/" + $ContainerName + "/" + $Blob.Name 


            If ($GetURIsOnly -eq $false)
            {
                $ExistingLocalFile = $null
                $BlobShortName = (Split-Path $Blob.Name -Leaf)
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
                                $BlobLastModified = $Blob.LastModified.DateTime 
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
                        $blobcontent = Get-AzureStorageBlobContent -Blob $Blob.Name -Destination $DestDirectory -Force -Container $ContainerName -Context $StorageContext -ConcurrentTaskCount $ConcurrentTaskCount
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
        $MbytesASec = [math]::round($FileSizeDownloaded / 1024 / 1024 / $TimeTakenSecs , 2)
        Write-Host "$FilesDownloaded file(s) total size = $FilesDownloaded Mbytes downloaded to $DestDirectory in $TimeTakenSecs secs at $MbytesASec Mbytes/sec" 
    }
    
    Write-Host ""
    # Finally return all the URI's   
    $FileURIs 
}


# $ret = Get-AzureDocumentation -DestDirectory "C:\Training\AzureDocs2" -ConcurrentTaskCount 32

