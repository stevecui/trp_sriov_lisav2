# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.

function Configure-Test() {
	$vm = "forwarder"
	$nics = Get-NonManagementNics $vm
	$nics[0].EnableIPForwarding = $true
	$nics[0] | Set-AzureRmNetworkInterface

	LogMsg "Enabled ip forwarding on $vm's non management nic"
}

function Alter-Runtime() {
	return
}

function Verify-Performance() {
	$vmSizes = @()

	foreach ($vm in $allVMData) {
		$vmSizes += $vm.InstanceSize
	}
	$vmSize = $vmSizes[0]

	# use temp so when a case fails we still check the rest
	$tempResult = "PASS"

	$allPpsData = [Xml](Get-Content .\XML\Other\testfwd_pps_lowerbound.xml)
	$sizeData = Select-Xml -Xml $allPpsData -XPath "testfwdpps/$vmSize" | Select-Object -ExpandProperty Node

	if ($null -eq $sizeData) {
		throw "No pps data for VM size $vmSize"
	}

	# count is non header lines
	$isEmpty = ($testDataCsv.Count -eq 0)
	if ($isEmpty) {
		throw "No data downloaded from vm"
	}

	foreach($testRun in $testDataCsv) {
		$coreData = Select-Xml -Xml $sizeData -XPath "core$($testRun.core)" | Select-Object -ExpandProperty Node
		LogMsg "Comparing $($testRun.core) core(s) data"
		LogMsg "  compare tx pps $($testRun.tx_pps_avg) with lowerbound $($coreData.tx)"
		if ([int]$testRun.tx_pps_avg -lt [int]$coreData.tx) {
			LogErr "  Perf Failure; $($testRun.tx_pps_avg) must be > $($coreData.tx)"
			$tempResult = "FAIL"
		}

		LogMsg "  compare fwdrx pps $($testRun.fwdrx_pps_avg) with lowerbound $($coreData.fwdrx)"
		if ([int]$testRun.fwdrx_pps_avg -lt [int]$coreData.fwdrx) {
			LogErr "  Perf Failure; $($testRun.fwdrx_pps_avg) must be > $($coreData.fwdrx)"
			$tempResult = "FAIL"
		}

		LogMsg "  compare fwdtx pps $($testRun.fwdtx_pps_avg) with lowerbound $($coreData.fwdtx)"
		if ([int]$testRun.fwdtx_pps_avg -lt [int]$coreData.fwdtx) {
			LogErr "  Perf Failure; $($testRun.fwdtx_pps_avg) must be > $($coreData.fwdtx)"
			$tempResult = "FAIL"
		}

		LogMsg "  compare rx pps $($testRun.rx_pps_avg) with lowerbound $($coreData.rx)"
		if ([int]$testRun.rx_pps_avg -lt [int]$coreData.rx) {
			LogErr "  Perf Failure; $($testRun.rx_pps_avg) must be > $($coreData.rx)"
			$tempResult = "FAIL"
		}
	}

	return $tempResult
}
