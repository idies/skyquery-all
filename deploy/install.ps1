# Installs SkyQuery binary components and web sites for the first time
# before execution, make sure to dot source an appropriate config file:
# . .\skyquery-config\scidev01\configure.ps1
# .\deploy\install.ps1

$fwpath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()

# Prompt for user account to be used for service install
if ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
	$cred = Get-Credential $skyquery_serviceaccount
	$user = $cred.UserName
	$pass = $cred.GetNetworkCredential().Password
}

# Create and configure registry
if ($skyquery_deployregistry) {
	echo "Creating registry..."
	& .\bin\$skyquery_target\gwregutil.exe createdb
	& .\bin\$skyquery_target\gwregutil.exe createcluster -cluster Graywulf -User admin -Email admin@graywulf.org -Password alma
	sqlcmd -S $skyquery_registrysql -d $skyquery_registrydb -Q "CREATE USER [$user] FOR LOGIN [$user]"
	sqlcmd -S $skyquery_registrysql -d $skyquery_registrydb -Q "ALTER ROLE [db_owner] ADD MEMBER [$user]"
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

# Start remote service
if ($skyquery_deployremoteservice) {
	echo "Starting remoting service '$skyquery_remoteservice' on all servers..."
	icm $skyquery_remoteservice_nodes -Script { 
		param($sn) 
		net start $sn 
	} -Args $skyquery_remoteservice
}

# Install scheduler
if ($skyquery_deployscheduler) {
	echo "Installing scheduler"
	icm $skyquery_scheduler_nodes -Script {
		param($un, $pw, $gw, $fw, $sn) 
		& $fw\InstallUtil.exe /username=$un /password=$pw /unattended /svcname=$sn C:\$gw\gwscheduler.exe
	} -Args $user, $pass, $skyquery_gwbin, $fwpath, $skyquery_schedulerservice
}

# Start scheduler
if ($skyquery_deployscheduler) {
	echo "Starting scheduler service '$skyquery_schedulerservice' on the controllers..."
	icm $skyquery_scheduler_nodes -Script { 
		param($sn) 
		net start $sn 
	} -Args $skyquery_schedulerservice
}

# Copy web site
if ($skyquery_deploywww) {
	echo "Copying web site..."
	foreach ( $s in $skyquery_wwwserver) {
		if (-Not (Test-Path \\$s\$skyquery_www)) {
			mkdir \\$s\$skyquery_www
		}
		rm -force -recurse \\$s\$skyquery_www\*
		cp .\www\* \\$s\$skyquery_www -recurse -force 
	}
}
