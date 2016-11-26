<# 
 .Synopsis
  Downloads Azure Documentation to Local Drive

 .Description
  Uses Azure Storage Cmdlets to download all Azure PDF based documentation locally 
  Checks to see if the up to date local copy exists and thus only downloads new / updated files 

  Prequisites - currently requires an Azure Subscription AND Azure Powershell cmdlets installed

  v1.0  Andy Ball 26/11/2016 Base Version
  Backlog 
  --------
  - Remove Azure Sub / Azure Powershell dependency by using Netclient cmdlet
  - Flatten Local Directory Structure. 
  

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


 .Example
   Basic usage , gets all documents 
   Get-AzureDocumentation -DestDirectory "C:\AzureDocs"

 .Example
   Only downloads the 10 smallest files. Used for testing
   Get-AzureDocumentation -DestDirectory "C:\AzureDocs" -FirstXBlobs 10 
#>

Function Get-AzureDocumentation 
{
    Param
    (
        [Parameter(Mandatory = $true , Position = 0)] [string] $DestDirectory, 
        [Parameter(Mandatory = $false , Position = 1)] [string] $StorageAccountName = "opbuildstorageprod", 
        [Parameter(Mandatory = $false , Position = 1)] [string] $ContainerName = "output-pdf-files", 
        [Parameter(Mandatory = $false , Position = 2)] [string] $ContainerPathWildCard = "en-us/Azure.azure-documents/live/*",
        [Parameter(Mandatory = $false , Position = 2)] [int] $GetFirstXBlobs = 0  
    )

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
    Write-Host "Starting copy of $BlobCount Files, total size $BlobsTotalMbytes MBytes"
    ForEach ($Blob in $BlobsAzure)
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
                    $blobcontent = Get-AzureStorageBlobContent -Blob $Blob.Name -Destination $DestDirectory -Force -Container $ContainerName -Context $StorageContext
                    $FilesDownloaded++
                    $FileSizeDownloaded += $Blob.Length
                }
            $CurrentBlobNumber ++
            
            Write-Host ""
        }

    # Work out how long
    $EndTime = Get-Date 
    $TimeTakenSecs = [math]::round((New-TimeSpan -Start $StartTime -End $EndTime).TotalSeconds, 0)
    $MbytesASec = [math]::round($FileSizeDownloaded / 1024 / 1024 / $TimeTakenSecs , 2)

    
    Write-Host ""
    Write-Host "$FilesDownloaded file(s) total size = $FilesDownloaded Mbytes downloaded to $DestDirectory in $TimeTakenSecs secs at $MbytesASec Mbytes/sec" 
}

# Get-AzureDocumentation -DestDirectory "C:\Training\AzureDocs"
