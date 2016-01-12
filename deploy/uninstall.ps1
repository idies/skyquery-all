# Uninstalls SkyQuery binary components and web sites.
# Before execution, make sure to dot source an appropriate config file:
# . .\skyquery-config\scidev01\configure.ps1
# .\deploy\uninstall.ps1

$controller = $skyquery_controller

$fwpath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()

# Stop the scheduler
#if ($skyquery_deployscheduler) {
#	echo "Stopping scheduler on the controller..."
# TODO
#}

# Uninstall the scheduler service
#if ($skyquery_deployscheduler) {
#	echo "Uninstalling scheduler..."
# TODO
#}

# Stop the remoting service
if ($skyquery_deployremoteservice)
{
	echo "Stopping remoting service '$skyquery_remoteservice' on all servers..."
	icm $skyquery_remoteservice_nodes -Script { 
		param($sn) 
		net stop $sn 
	} -Args $skyquery_remoteservice
}

# Uninstall the remoting service
if ($skyquery_deployremoteservice)
{
	echo "Uninstalling remoting service '$skyquery_remoteservice' on all servers..."
	icm $skyquery_remoteservice_nodes -Script { 
		param($gw, $fw, $sn) 
		& $fw\InstallUtil.exe /u /svcname=$sn C:\$gw\gwrsvr.exe
	} -Args $skyquery_gwbin, $fwpath, $skyquery_remoteservice
}

# Delete binaries
# TODO