# Installs SkyQuery binary components and web sites for the first time
# .\deploy\install.ps1 [config]

# Stop on any error
$ErrorActionPreference = "Stop"
$fwpath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()

# Load config
$config = $args[0] 
. .\$config\configure.ps1
. .\deploy\instlib.ps1

# Initialize registry
Add-Type -Path ".\bin\$skyquery_target\Jhu.Graywulf.Registry.dll"
LoadRegistryConnectionString

# Prompt for user account to be used for service install
if ($FALSE) { # ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
	$cred = Get-Credential $skyquery_serviceaccount
	$user = $cred.UserName
	$pass = $cred.GetNetworkCredential().Password
} else {
	$user = $skyquery_usergroup
}

# Create and configure registry
if ($FALSE) { #($skyquery_deployregistry) {
	echo "Creating log..."
	& .\bin\$skyquery_target\gwregutil.exe CreateLog -Q -Username "$user" -Role "db_owner"
	ExitOnError
	
	echo "Creating job persistence store..."
	& .\bin\$skyquery_target\gwregutil.exe CreateJobPersistence -Q -Username "$user" -Role "db_owner"
	ExitOnError
	
	echo "Creating registry..."
	& .\bin\$skyquery_target\gwregutil.exe CreateRegistry -Q -Username "$user" -Role "db_owner"
	ExitOnError
	& .\bin\$skyquery_target\gwregutil.exe AddCluster -Q -cluster "Graywulf" -User admin -Email admin@graywulf.org -Password alma
	ExitOnError
	& .\bin\$skyquery_target\gwregutil.exe AddDomain -Q -cluster "Cluster:Graywulf" -Domain "SciServer"
	ExitOnError
	
	echo "Installing SkyQuery..."
	& .\bin\$skyquery_target\sqregutil.exe install -Domain "Domain:Graywulf\SciServer"
	ExitOnError
	
	echo "Importing registry: cluster..."
	& .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Cluster.xml -Duplicates Update
	ExitOnError
	echo "Importing registry: federation..."
	& .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Federation.xml -Duplicates Update
	ExitOnError
	echo "Importing registry: layout..."
	& .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Layout.xml -Duplicates Update
	ExitOnError
}

# Find servers
echo "Finding servers..."
$skyquery_controller = FindMachines("MachineRole:Graywulf\Controller")
Write-Host $skyquery_controller
$skyquery_skynode = FindMachines("MachineRole:Graywulf\SkyNode")
Write-Host $skyquery_skynode
$skyquery_skynode_sql = FindServerInstances("MachineRole:Graywulf\SkyNode")
Write-Host $skyquery_skynode_sql

# TODO: find web servers
# TODO: add mydb hosts

# Copy binaries
if ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
	echo "Copying binaries to all servers..."
	foreach ( $s in ($skyquery_controller + $skyquery_skynode)) {
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
	$ss = $skyquery_controller + $skyquery_skynode
	icm $ss -Script {
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
	icm $skyquery_controller -Script {
		param($un, $pw, $gw, $fw, $sn) 
		& $fw\InstallUtil.exe /username=$un /password=$pw /unattended /svcname=$sn C:\$gw\gwscheduler.exe
	} -Args $user, $pass, $skyquery_gwbin, $fwpath, $skyquery_schedulerservice
}

# Start scheduler
if ($skyquery_deployscheduler) {
	echo "Starting scheduler service '$skyquery_schedulerservice' on the controllers..."
	icm $skyquery_controller -Script { 
		param($sn) 
		net start $sn 
	} -Args $skyquery_schedulerservice
}

exit

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
