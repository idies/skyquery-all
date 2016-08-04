# Installs SkyQuery binary components and web sites for the first time
# .\deploy\install.ps1 [config]

function ExitOnError() {
	if ($LastExitCode -gt 0) { 
		exit 
	}
}

function FindMachines($role) {
	$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
	$csb["Data Source"] = $skyquery_registrysql
	$csb["Initial Catalog"] = $skyquery_registrydb
	$csb["MultipleActiveResultsets"] = $TRUE
	$csb["Integrated Security"] = $TRUE
	[Jhu.Graywulf.Registry.ContextManager]::Instance.ConnectionString = $csb.ConnectionString
	$context = [Jhu.Graywulf.Registry.ContextManager]::Instance.CreateContext()
	$ef = New-Object Jhu.Graywulf.Registry.EntityFactory $context

	$mr = $ef.LoadEntity($role)
	$mr.LoadMachines($TRUE)
	$mm = $mr.Machines.Values | select -ExpandProperty HostName | select -ExpandProperty ResolvedValue
	
	$context.Dispose()
	
	return $mm
}

# Import references
Add-Type -Path ".\bin\Debug\Jhu.Graywulf.Registry.dll"

# Stop on any error
$ErrorActionPreference = "Stop"
$fwpath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()

# Load config
$config = $args[0] 
. .\$config\configure.ps1

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
echo "Find servers..."
$skyquery_controller = FindMachines("MachineRole:Graywulf\Controller")
$skyquery_controller
$skyquery_skynode = FindMachines("MachineRole:Graywulf\SkyNode")
$skyquery_skynode

exit

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
