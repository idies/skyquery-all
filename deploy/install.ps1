# Installs SkyQuery binary components and web sites for the first time
# .\deploy\install.ps1 [config]

# Stop on any error
$ErrorActionPreference = "Stop"

# Load config
$config = $args[0]
. .\$config\configure.ps1
Write-Host "Configured for $skyquery_config"

# Initialize install library
. .\deploy\instlib.ps1
Init

# Prompt for user account to be used for service install
if ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
	Write-Host "Please enter service account password."
	$skyquery_user, $skyquery_pass = AskPassword
}

# Create and configure registry
if ($FALSE) { #($skyquery_deployregistry) {
	InstallLogging
	InstallJobPersistence
	InstallRegistry
	InstallSkyQuery
	ImportRegistry
}

# Find servers
FindServers
PrintServers

# Copy binaries
CopyBinaries

# Copy web sites
# TODO

# Install remoting service
InstallRemotingService
StartRemotingService

# Install scheduler
InstallScheduler
StartScheduler