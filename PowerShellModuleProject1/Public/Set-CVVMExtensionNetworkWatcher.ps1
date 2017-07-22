Function Set-CVVMExtensionNetworkWatcher
    {
        Param
            (
                [Parameter (Mandatory = $true, Position = 0)] [PSObject] $VM 

            )

            $ErrorActionPreference = "Stop" 
           
            # $ExtnNames = $SourceVM.Extensions.id | Select @{Name = "ExtensionName" ; Expression = {$_.Split("/")[10]}}
            #$ExtnNames = 
            $Extensions = $VM.Extensions
            Write-Verbose ("Extension Names = " + "`r`n" + ($Extensions.Name | Sort | Out-String))
            $ExtnExists = $Extensions | Where {$_.Name -eq "Microsoft.Azure.NetworkWatcher"}

            If ($ExtnExists -ne $null)
                {
                    Write-Host "networkWatcherAgent already installed"
                    # Write-Host -Object $Extn
                }
            Else
                {
                    Write-Host ("Adding NetworkAgent Extension to " + ($VM.Name))
                    Set-AzureRmVMExtension -ResourceGroupName $VM.ResourceGroupName `
                       -Location $VM.Location `
                       -VMName $VM.Name `
                       -Name "networkWatcherAgent" `
                       -Publisher "Microsoft.Azure.NetworkWatcher" `
                       -Type "NetworkWatcherAgentWindows" `
                       -TypeHandlerVersion "1.4"
                }

}