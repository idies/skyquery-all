# Source install libraries
. .\deploy\instutil.ps1
. .\deploy\instlib.ps1

# To prevent locking assemblies, the script executes itself
# in a saparate poweshell session

if ($args[0] -notmatch "-i") {
	$verb = $args[0]
	$config = $args[1]
	powershell -Command "$PSCommandPath -i $verb $config"
	exit
}

# This is the normal execution path

$verb = $args[1]
$config = $args[2]

# Load config
if (!(test-path .\$config\configure.ps1)) {
	Write-Host Invalid configuration: $config
	exit
}

# Load configuration and initialize setup

. .\$config\configure.ps1
Write-Host "Configured for $skyquery_config"

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