# Source install libraries
. .\deploy\instutil.ps1
. .\deploy\instlib.ps1

WrapItself $PSCommandPath $args

$verb = $args[1]
$config = $args[2]

. Configure $config
Init
InitRegistry

if ($verb -match "^help") {
	# TODO
	echo "This will display the help some day."
} elseif ($verb -match "^start") {
	FindServers

	StartRemotingService
	StartScheduler

	echo "Services started."
} elseif ($verb -match "^stop") {
	FindServers

	StopScheduler
	StopRemotingService

	echo "Services stopped."
} elseif ($verb -match "^recycleweb") {
	FindServers

	RecycleWebUI

	echo "App pools recycled."
} elseif ($verb -match "^flushschema") {
	FindServers

	FlushSchema

	echo "Schema cache flushed."
} else {
	Write-Host "Unrecognized verb: $verb"
}