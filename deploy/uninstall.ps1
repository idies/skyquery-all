# Uninstalls SkyQuery binary components and web sites.
# .\deploy\uninstall.ps1 [config]

# Stop on any error
$ErrorActionPreference = "Continue"

# Load config
$config = $args[0]
. .\$config\configure.ps1
Write-Host "Configured for $skyquery_config"

# Initialize install library
. .\deploy\instlib.ps1
Init

# Find servers
FindServers
PrintServers


# Uninstall the scheduler
StopScheduler
RemoveScheduler

# Uninstall the remoting services
StopRemotingService
RemoveRemotingService

# TODO: remove web sites

RemoveBinaries
