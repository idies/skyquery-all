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
} elseif ($verb -match "^initdb") {
	$ErrorActionPreference = "Stop"

	# Create and configure registry
	InstallLogging
	InstallJobPersistence
	InstallRegistry
} elseif ($verb -match "^initreg") {
	InstallSkyQuery
	ImportRegistry
} elseif ($verb -match "^servers") {
	FindServers
	PrintServers
} elseif ($verb -match "^install") {
	$ErrorActionPreference = "Stop"
	
	AskPasswords

	# Find servers
	FindServers
	PrintServers

	CreateBinariesDir
	CopyBinaries

	InstallWebAdmin
	InstallWebUI

	InstallRemotingService
	InstallScheduler

	CreateCodeDb
	InstallCodeDbScripts
	
	echo "Install complete. Run 'setup start $config' to finish installation."
} elseif ($verb -match "^export") {
	ExportRegistry
} elseif ($verb -match "^reinstall") {
	FindServers

	StopScheduler
	StopRemotingService
	
	CopyBinaries

	InstallWebAdmin
	InstallWebUI

	RemoveCodeDbScripts
	InstallCodeDbScripts

	StartRemotingService
	StartScheduler

	echo "Reinstall complete."
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
} elseif ($verb -match "^remove") {
	FindServers

	StopScheduler
	RemoveScheduler

	StopRemotingService
	RemoveRemotingService

	DropCodeDb
	
	RemoveWebUI
	RemoveWebAdmin

	RemoveBinaries

	echo "Remove complete. Run 'setup purge $config' to delete registry."
} elseif ($verb -match "^purge") {
	RemoveRegistry
	RemoveJobPersistence
	RemoveLogging

	echo "Configuration purged."
} else {
	Write-Host "Unrecognized verb: $verb"
}