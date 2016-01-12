# Installs SkyQuery binary components and web sites for the first time
# before execution, make sure to dot source an appropriate config file:
# . .\skyquery-config\scidev01\configure.ps1
# .\deploy\reinstall.ps1

$fwpath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()

# Prompt for user account to be used for service install
if ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
	$cred = Get-Credential $skyquery_serviceaccount
	$user = $cred.UserName
	$pass = $cred.GetNetworkCredential().Password
}

# Copy binaries
if ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
	echo "Copying binaries to all servers..."
	foreach ( $s in ($skyquery_scheduler_nodes + $skyquery_remoteservice_nodes)) {
		if (-Not (Test-Path \\$s\$skyquery_gwbin)) {
			mkdir \\$s\$skyquery_gwbin
		}
		rm -force -recurse \\$s\$skyquery_gwbin\*
		cp .\bin\$skyquery_target\* \\$s\$skyquery_gwbin -recurse -force 
	}
}

# Install remoting service
if ($skyquery_deployremoteservice) {
	echo "Installing remoting service"
	icm $skyquery_remoteservice_nodes -Script {
		param($un, $pw, $gw, $fw, $sn) 
		& $fw\InstallUtil.exe /username=$un /password=$pw /unattended /svcname=$sn C:\$gw\gwrsvr.exe
	} -Args $user, $pass, $skyquery_gwbin, $fwpath, $skyquery_remoteservice
}

# Install scheduler
# TODO

# Start remote service
if ($skyquery_deployremoteservice) {
	echo "Starting remoting service '$skyquery_remoteservice' on all servers..."
	icm $skyquery_remoteservice_nodes -Script { 
		param($sn) 
		net start $sn 
	} -Args $skyquery_remoteservice
}

# Start scheduler
# TODO


# Copy web site
# TODO
#cp C:\Data\dobos\project\skyquery-all\bin \\scitest02\data\dobos\project\skyquery-all -Force -Recurse
#cp C:\Data\dobos\project\skyquery-all\www \\scitest02\data\dobos\project\skyquery-all -Force -Recurse