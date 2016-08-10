$verb = $args[0]
$config = $args[1]

# Load config
if (!(test-path .\$config\configure.ps1)) {
	Write-Host Invalid configuration: $config
	exit
}

. .\$config\configure.ps1
Write-Host "Configured for $skyquery_config"

# Initialize install libraries
. .\deploy\instutil.ps1
. .\deploy\instlib.ps1
Init
InitRegistry

if ($verb -match "install") {
	$ErrorActionPreference = "Stop"
	
	# Prompt for user account to be used for service install
	Write-Host "Please enter service account password."
	$skyquery_user, $skyquery_pass = AskPassword "$skyquery_serviceaccount"
	
	# Create and configure registry
	InstallLogging
	InstallJobPersistence
	InstallRegistry
	InstallSkyQuery
	ImportRegistry

	# Find servers
	FindServers
	PrintServers

	CopyBinaries
	InstallWebAdmin
	InstallWebUI
	InstallRemotingService
	InstallScheduler

	CreateCodeDb
	InstallCodeDbScripts
	
	echo "Install complete. Run 'setup start $config' to finish installation."
} elseif ($verb -match "reinstall") {
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
} elseif ($verb -match "start") {
	FindServers

	StartRemotingService
	StartScheduler

	echo "Services started."
} elseif ($verb -match "stop") {
	FindServers

	StopScheduler
	StopRemotingService

	echo "Services stopped."
} elseif ($verb -match "remove") {
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
} elseif ($verb -match "purge") {
	RemoveRegistry
	RemoveJobPersistence
	RemoveLogging

	echo "Configuration purged."
} else {
	Write-Host "Unrecognized verb: $verb"
}