#Get public and private function definition files.
    Write-Host "Populating list of Public Functions"
	$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
	Write-Host "Populating list of Private Functions"
	$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
	Write-Host "Loading Functions into memory"
    Foreach($import in @($Public + $Private))
    {
        Try
        {
			Write-Host "Loading Function [$($import.fullname)]"    
			. $import.fullname
        }
        Catch
        {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }

# Here I might...
    # Read in or create an initial config file and variable
    # Export Public functions ($Public.BaseName) for WIP modules
    # Set variables visible to the module and its functions only

Write-Host ("Exporting Functions....." + $Public.Basename) 
Export-ModuleMember -Function $Public.Basename
