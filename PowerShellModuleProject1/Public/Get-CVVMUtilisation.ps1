Function Get-CVVMUtilisation
{
    Param 
    (
        [Parameter(Mandatory = $true, Position = 0)]  [string[]] $VMNames, 
        [Parameter(Mandatory = $true, Position = 1)]  [datetime] $StartTime,
        [Parameter(Mandatory = $true, Position = 2)]  [datetime] $EndTime, 
        [Parameter(Mandatory = $false, Position = 3)] [string]   $VMSizeLocation = "northeurope"
        )

    Write-Host ("Getting all VMs @ " + (Get-Date))
    $VMs = Get-AzureRMVM
    Write-Host ("Running Get-AzureRMVMSizes -Location $VMSizeLocation @ " + (Get-Date))
    $VMSizes = Get-AzureRMVMSize -Location $VMSizeLocation

    # ie do all 
    If($VMNames -eq "*")
        {
            $MyVMS = $VMs
        }
    Else
        {
            $MyVMs = $VMS | Where {$_.Name -in $VMNames}
        }


    If ($MyVms -eq $null)
        {
            Write-Warning "No Matching VMs found. Quitting..."
            Break 
        }

    Write-Verbose ("Matching VMs:`r`n" + ($MyVMs.Name | Out-String))

    $VMsCount = ($MyVMS).Count
    $CurrentVMNum = 1 

    $Resultset = @()
    ForEach ($VM in $MyVMs)
    {
        $AVGMemoryPercent = $null 
        $AVGCPUPercent = $null 
        $VMSize = $null 
        $VMLookupRow = $null 
        $VMMemoryMB = $null
        $VMCores = $null

        $VMName = $VM.Name 
        Write-Host "Processing $VMName ($CurrentVMNum of $VMsCount)" -ForegroundColor Green

        Write-Host ("`tGetting Metrics @ " + (Get-Date))
        $Metrics = Get-AzureRMMetric -ResourceId $VM.Id -TimeGrain 00:01:00 -StartTime $StartTime -EndTime $EndTime

        $AVGMemItems = ($Metrics | Where {$_.Name -eq "\Memory\% Committed Bytes In Use"}).MetricValues
        $AVGMemoryPercent = [math]::Round(($AVGMemItems | Measure-Object -Property Average -Average).Average,2)

        $AVGCPUItems = ($Metrics | Where {$_.Name -eq "\Processor(_Total)\% Processor Time"}).MetricValues
        $AVGCPUPercent = [math]::Round(($AVGCPUItems | Measure-Object -Property Average -Average).Average,2)
    
        # Match VM Size 
        $VMSize = $VM.HardwareProfile.VmSize
        $VMLookupRow = $VMSizes | Where {$_.Name -eq $VMSize}
        If ($VMLookupRow -eq $null)
            {
                Write-Warning "`Cannot find VMSize = $VMSize in Get-AzureRMVMSizes output"
            }
        Else
            {
                $VMMemoryMB = $VMLookupRow.MemoryInMB
                $VMCores = $VMLookupRow.NumberOfCores
            }

        $Resultset += $Host | Select @{Name = "VMName" ; Expression = {$VMName}}, 
                                     @{Name = "RGname" ; Expression = {$VM.ResourceGroupName}}, 
                                     @{Name = "AvgMem%" ; Expression = {$AVGMemoryPercent}}, 
                                     @{Name = "AVGCPU%" ; Expression = {$AVGCPUPercent}},
                                     @{Name = "VMSize" ; Expression = {$VMSize}}, 
                                     @{Name = "MemoryMB" ; Expression = {$VMMemoryMB}},
                                     @{Name = "CPUCores" ; Expression = {$VMCores}}
        $CurrentVMNum += 1
    }

    $Resultset 
}
