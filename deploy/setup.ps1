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

if ($verb -match "^help") {
	# TODO
	echo "This will display the help some day."
}
if ($verb -match "^initdb") {
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
	Write-Host "Exporting cluster settings..."
	ExecLocal .\bin\$skyquery_target\gwregutil.exe export -root "Cluster:Graywulf" -Output "SkyQuery_Cluster.xml" -Cluster -ExcludeUserCreated

	Write-Host "Exporting SkyQuery federation..."
	ExecLocal .\bin\$skyquery_target\gwregutil.exe export -root "Federation:Graywulf\SciServer\SkyQuery" -Output "SkyQuery_Federation.xml" -Federation -ExcludeUserCreated

	Write-Host "Exporting SkyQuery layout..."
	ExecLocal .\bin\$skyquery_target\gwregutil.exe export -root "Federation:Graywulf\SciServer\SkyQuery" -Output "SkyQuery_Layout.xml" -Layout -ExcludeUserCreated
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