# Installs SkyQuery binary components and web sites for the first time
# before execution, make sure to dot source an appropriate config file:
# . .\skyquery-config\scidev01\configure.ps1
# .\deploy\reinstall.ps1

$controller = $skyquery_controller
$nodes = $skyquery_nodes
$servers = $controller + $nodes

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
	foreach ( $s in $servers ) {
		if (-Not (Test-Path \\$s\$skyquery_gwbin)) {
			mkdir \\$s\$skyquery_gwbin
		}
		rm -force -recurse \\$s\$skyquery_gwbin\*
		cp .\bin\$skyquery_config\* \\$s\$skyquery_gwbin -recurse -force 
	}
}

# Install remoting service (need to run manually because asks for password
if ($skyquery_deployremoteservice) {
	echo "Installing remoting service"
	icm $servers -Script {
		param($un, $pw, $gw, $fw) 
		& $fw\InstallUtil.exe /username=$un /password=$pw /unattended C:\$gw\gwrsvr.exe
	} -Args $user, $pass, $skyquery_gwbin, $fwpath
#& 'C:\windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe' C:\data\data0\graywulf\bin\debug\gwrsvr.exe
}

# Install scheduler (need to run manually because asks for password
#& 'C:\windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe' C:\data\data0\graywulf\bin\debug\gwscheduler.exe


# Start services
#icm $servers { net start GWRSvr }
#icm $controller { net start SchedulerService }


# Copy web site
#cp C:\Data\dobos\project\skyquery-all\bin \\scitest02\data\dobos\project\skyquery-all -Force -Recurse
#cp C:\Data\dobos\project\skyquery-all\www \\scitest02\data\dobos\project\skyquery-all -Force -Recurse