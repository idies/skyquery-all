#region Configuration

function WrapItself([string] $path, [string[]] $params) {
	# To prevent locking assemblies, the script executes itself
	# in a saparate poweshell session
	if ($params[0] -notmatch "-i") {
		powershell -Command "$path -i $params"
		exit
	}
	# This is the normal execution path
}

function Configure($config) {
	# Load config
	if (!(test-path .\$config\configure.ps1)) {
		Write-Host Invalid configuration: $config
		exit
	}

	# Load configuration and initialize setup

	. .\$config\configure.ps1
	Write-Host "Configured for $skyquery_config"
	Write-Host "Build target is $skyquery_target"
}

function GetSubmodules() {
	git config --file .gitmodules --name-only --get-regexp path | %{"$($_.Split('.')[1])"}
}

function GetConfigVersion($module) {
	$filename = "$module\build.config"
	$configfile = GetConfigFile "$filename"
	$config = GetConfig $configfile
	$version = GetVersion $config
	$version
}

function PrintConfigVersion($modules) {
	Write-Host "Printing version number for module:"
	foreach ($m in $modules) {
		$version = GetConfigVersion $m
		Write-Host $(" ... {0,-20} : {1}" -f $m, $version)
	}
}

function UpdateConfigVersion($modules, $now) {
	Write-Host "Updating version number for module:"
	foreach ($m in $modules) {
		$filename = "$m\build.config"
		$configfile = GetConfigFile "$filename"
		$config = GetConfig $configfile
		$version = GetVersion $config

		$version = IncrementVersion $version $now
		UpdateVersion $config $version
		$config.Save($configfile.FullName)
	
		Write-Host $(" ... {0,-20} : {1}" -f $m, $version)
	}
}

function SetConfigVersion($modules, $version) {
	Write-Host "Setting version number for module:"
	foreach ($m in $modules) {
		$filename = "$m\build.config"
		$configfile = GetConfigFile "$filename"
		$config = GetConfig $configfile

		UpdateVersion $config $version
		$config.Save($configfile.FullName)
	
		Write-Host $(" ... {0,-20} : {1}" -f $m, $version)
	}
}

function CreateTag($modules, $tag) {
	Write-Host "Using version number of root module: $version"
	Write-Host "Tagging module with $tag :"
	foreach ($m in $modules) {
		pushd
		cd $m
		git tag "$tag"
		popd
		Write-Host " ... $m"
	}
}

#endregion
# -------------------------------------------------------------
#region Passwords

function AskPasswords() {
	if ($skyquery_admin_passwd -eq $NULL) {		
		Write-Host "Please enter admin account password."
		$skyquery_admin_account, $skyquery_admin_passwd = AskPassword "$skyquery_admin_account"
	} else {
		Write-Host "Admin account password found in config file"	
	}

	if ($skyquery_service_passwd -eq $NULL) {		
		Write-Host "Please enter service account password."
		$skyquery_service_account, $skyquery_service_passwd = AskPassword "$skyquery_service_account"
	} else {
		Write-Host "Service account password found in config file"	
	}

	if ($skyquery_user_passwd -eq $NULL) {		
		Write-Host "Please enter user account password."
		$skyquery_user_account, $skyquery_user_passwd = AskPassword "$skyquery_user_account"
	} else {
		Write-Host "User account password found in config file"	
	}
}

#endregion
# -------------------------------------------------------------
#region Logging

function InstallLogging() {
	if ($skyquery_deployregistry) {
		Write-Host "Creating database for logging..."
		$cstr = GetConnectionString "Jhu.Graywulf.Logging"
		$srv, $db = GetServerAndDatabase "$cstr"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe CreateLog -Q -Server "$srv" -Database "$db"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddUser -Q -Server "$srv" -Database "$db" -Username "$skyquery_admin_account" -Role "db_owner"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddUser -Q -Server "$srv" -Database "$db" -Username "$skyquery_service_account" -Role "db_owner"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddUser -Q -Server "$srv" -Database "$db" -Username "$skyquery_user_account" -Role "db_owner"
	}
}

function RemoveLogging() {
	if ($skyquery_deployregistry) {
		Write-Host "Removing database for logging..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe DropLog -Q
	}
}

#endregion
# -------------------------------------------------------------
#region Job persistence

function InstallJobPersistence() {
	if ($skyquery_deployregistry) {
		Write-Host "Creating database for job persistence store..."
		$cstr = GetConnectionString "Jhu.Graywulf.Activities.Persistence"
		$srv, $db = GetServerAndDatabase "$cstr"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe CreateJobPersistence -Q -Server "$srv" -Database "$db"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddUser -Q -Server "$srv" -Database "$db" -Username "$skyquery_admin_account" -Role "db_owner"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddUser -Q -Server "$srv" -Database "$db" -Username "$skyquery_service_account" -Role "db_owner"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddUser -Q -Server "$srv" -Database "$db" -Username "$skyquery_user_account" -Role "db_owner"
	}
}

function RemoveJobPersistence() {
	if ($skyquery_deployregistry) {
		Write-Host "Removing database for job persistence store..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe DropJobPersistence -Q
	}
}

#endregion
# -------------------------------------------------------------
#region Registry

function InitRegistry() {
	Add-Type -Path ".\bin\$skyquery_target\Jhu.Graywulf.Registry.dll"
	Add-Type -Path ".\bin\$skyquery_target\Jhu.Graywulf.Registry.Enum.dll"
	LoadRegistryConnectionString
	Write-Host "Registry connection string is"
	Write-Host $([Jhu.Graywulf.Registry.ContextManager]::Instance.ConnectionString)
}

function LoadRegistryConnectionString() {
	$cstr = GetConnectionString "Jhu.Graywulf.Registry"
	[Jhu.Graywulf.Registry.ContextManager]::Instance.ConnectionString = $cstr
}

function InstallRegistry() {
	if ($skyquery_deployregistry) {
		Write-Host "Creating database for registry..."
		$cstr = [Jhu.Graywulf.Registry.ContextManager]::Instance.ConnectionString
		$srv, $db = GetServerAndDatabase "$cstr"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe CreateRegistry -Q
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddUser -Q -Server "$srv" -Database "$db" -Username "$skyquery_admin_account" -Role "db_owner"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddUser -Q -Server "$srv" -Database "$db" -Username "$skyquery_service_account" -Role "db_owner"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddUser -Q -Server "$srv" -Database "$db" -Username "$skyquery_user_account" -Role "db_owner"
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddCluster -Q -cluster "Graywulf" -User admin -Email admin@graywulf.org -Password alma
		ExecLocal .\bin\$skyquery_target\gwregutil.exe AddDomain -Q -cluster "Cluster:Graywulf" -Domain "SciServer"
	}
}

function RemoveRegistry() {
	if ($skyquery_deployregistry) {
		Write-Host "Deleting database for registry..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe DropRegistry -Q
	}	
}

function ExportSubtree($entity, $output, $options) {
	ExecLocal .\bin\$skyquery_target\gwregutil.exe export -root "$entity" -Output "$config\$output" $options -ExcludeUserCreated
}

function ExportRegistry() {
	Write-Host "Exporting cluster settings..."
	ExportSubtree "Cluster:Graywulf" "SkyQuery_Cluster.xml" "-Cluster"
	Write-Host "Exporting system federation settings..."
	ExportSubtree "Federation:Graywulf\System\System" "SkyQuery_System.xml" "-Layout"
	Write-Host "Exporting SciServer domain..."
	ExportSubtree "Domain:Graywulf\SciServer" "SkyQuery_Domain.xml" "-Domain"
	Write-Host "Exporting SkyQuery federation..."
	ExportSubtree "Federation:Graywulf\SciServer\SkyQuery" "SkyQuery_Federation.xml" "-Federation"
	Write-Host "Exporting SkyQuery layout..."
	ExportSubtree "Federation:Graywulf\SciServer\SkyQuery" "SkyQuery_Layout.xml" "-Layout"
}

function ImportRegistry() {
	if ($skyquery_deployregistry) {
		Write-Host "Importing registry: cluster..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Cluster.xml -Duplicates Update
		Write-Host "Importing registry: system..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_System.xml -Duplicates Update
		Write-Host "Importing registry: domain..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Domain.xml -Duplicates Update
		Write-Host "Importing registry: federation..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Federation.xml -Duplicates Update
		Write-Host "Importing registry: layout..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Layout.xml -Duplicates Update
	}
}

function InstallSkyQuery() {
	if ($skyquery_deployregistry) {
		Write-Host "Installing SkyQuery..."
		ExecLocal .\bin\$skyquery_target\sqregutil.exe install -Domain "Domain:Graywulf\SciServer"
	}
}

function FindServers() {
	Write-Host "Finding servers..."

	$global:skyquery_controller = FindMachines("MachineRole:Graywulf\Controller")
	$global:skyquery_skynode = FindMachines("MachineRole:Graywulf\SkyNode")
	$global:skyquery_skynode_sql = FindServerInstances("MachineRole:Graywulf\SkyNode")
	$global:skyquery_web = FindMachines("MachineRole:Graywulf\Web")
	$global:skyquery_mydb = FindMachines("MachineRole:Graywulf\UserDBHost")
	$global:skyquery_mydb_sql = FindServerInstances("MachineRole:Graywulf\UserDBHost")
	$global:skyquery_codedb = FindDatabaseInstances("DatabaseDefinition:Graywulf\SciServer\SkyQuery\CODE")
}

function PrintServers() {
	Write-Host "Found the following servers:"
	
	Write-Host "Controllers:"
	Write-Host $skyquery_controller

	Write-Host "SkyNodes:"
	Write-Host $skyquery_skynode

	Write-Host "SkyNode SQL instances:"
	Write-Host $skyquery_skynode_sql

	Write-Host "Web servers:"
	Write-Host $skyquery_web

	Write-Host "MyDB hosts:"
	Write-Host $skyquery_mydb
	
	Write-Host "MyDB SQL instances:"
	Write-Host $skyquery_mydb_sql
	
	Write-Host "CodeDB database instances:"
	foreach ($s in $skyquery_codedb) {
		Write-Host $s["Server"] $s["Database"]
	}
}

#endregion
# -------------------------------------------------------------
#region Binaries

function GetBinariesServers() {
	$servers = @()
	if ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
		$servers += $skyquery_controller
	}
	if ($skyquery_deployremoteservice) {
		$servers += $skyquery_skynode
		$servers += $skyquery_mydb
	}
	$servers
}

function CreateBinariesDir() {
	if ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
		$servers = GetBinariesServers
		Write-Host "Creating directory and share on:"
		CreateShare $servers "C:\Graywulf" "Graywulf"
	}
}

function CopyBinaries() {
	if ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
		$servers = GetBinariesServers
		Write-Host "Copying binaries to:"
		CopyDir $servers ".\bin\$skyquery_target\*" "$skyquery_gwbin"
	}
}

function RemoveBinaries() {
	if ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
		$servers = GetBinariesServers
		Write-Host "Removing binaries from:"
		RemoveDir $servers "$skyquery_gwbin"
	}
}

#endregion
# -------------------------------------------------------------
#region Remoting service

function GetRemotingServiceServers() {
	$servers = @()
	$servers += $skyquery_controller
	$servers += $skyquery_skynode 
	$servers += $skyquery_mydb
	$servers
}

function InstallRemotingService() {
	if ($skyquery_deployremoteservice) {
		$servers = GetRemotingServiceServers
		InstallService $servers "$skyquery_remoteservice" "C:\$skyquery_gwbin\gwrsvr.exe" "$skyquery_service_account" "$skyquery_service_passwd"
	}
}

function StartRemotingService() {
	if ($skyquery_deployremoteservice) {
		$servers = GetRemotingServiceServers
		StartService $servers $skyquery_remoteservice
	}
}

function StopRemotingService() {
	if ($skyquery_deployremoteservice) {
		$servers = GetRemotingServiceServers
		StopService $servers $skyquery_remoteservice
	}
}

function RemoveRemotingService() {
	if ($skyquery_deployremoteservice) {
		$servers = GetRemotingServiceServers
		RemoveService $skyquery_remoteservice "C:\$skyquery_gwbin\gwrsvr.exe" $servers
	}
}

#endregion
# -------------------------------------------------------------
#region Scheduler

function GetSchedulerServers() {
	$servers = @()
	$servers += $skyquery_controller
	$servers
}

function InstallScheduler() {
	if ($skyquery_deployscheduler) {
		$servers = GetSchedulerServers
		InstallService $servers $skyquery_schedulerservice "C:\$skyquery_gwbin\gwscheduler.exe" "$skyquery_service_account" "$skyquery_service_passwd"
	}
}

function StartScheduler([string[]] $servers) {
	if ($skyquery_deployscheduler) {
		$servers = GetSchedulerServers
		StartService $servers $skyquery_schedulerservice
	}
}

function StopScheduler([string[]] $servers) {
	if ($skyquery_deployscheduler) {
		$servers = GetSchedulerServers
		StopService $servers $skyquery_schedulerservice
	}
}

function RemoveScheduler() {
	if ($skyquery_deployscheduler) {
		$servers = GetSchedulerServers
		RemoveService $skyquery_schedulerservice "C:\$skyquery_gwbin\gwscheduler.exe" $servers
	}
}

#endregion
# -------------------------------------------------------------
#region Web admin

function InstallWebAdmin() {
	if ($skyquery_deployadmin) {
		InstallWebSite $skyquery_controller `
			".\graywulf\web\Jhu.Graywulf.Web.Admin\*" "$skyquery_admin_web_path" `
			"$skyquery_admin_web_apppool" "$skyquery_admin_account" "$skyquery_admin_passwd" `
			"$skyquery_admin_web_site" "gwadmin"
	}
}

function RemoveWebAdmin() {
	if ($skyquery_deployadmin) {
		RemoveWebSite $skyquery_controller `
			"$skyquery_admin_web_path" `
			"$skyquery_admin_web_apppool" `
			"$skyquery_admin_web_site" "gwadmin"
	}
}

#endregion
# -------------------------------------------------------------
#region Web UI

function InstallWebUI() {
	if ($skyquery_deploywww) {
		$servers = $skyquery_web
		RecycleAppPool $servers "$skyquery_user_web_apppool"
		Write-Host "Copying web UI to:"
		CopyDir $servers ".\skyquery\web\Jhu.SkyQuery.Web.UI\*" "$skyquery_user_web_path"
		Write-Host "Creating app pool for web UI on:"
		CreateAppPool $servers "$skyquery_user_web_apppool" $skyquery_user_account $skyquery_user_passwd
		Write-Host "Creating web app for web UI on:"
		CreateWebApp $servers "$skyquery_user_web_site" "skyquery" "C:\$skyquery_user_web_path" "$skyquery_user_web_apppool"
	}
}

function RemoveWebUI() {
	if ($skyquery_deploywww) {
		$servers = $skyquery_web
		Write-Host "Removing web UI from:"
		RemoveWebApp $servers "$skyquery_user_web_site" "skyquery"
		Write-Host "Removing app pool for web UI from:"
		RemoveAppPool $servers "$skyquery_user_web_apppool"
		Write-Host "Removing dir for web UI from:"
		RemoveDir $servers "$skyquery_user_web_path"
	}
}

function RecycleWebUI() {
	$servers = $skyquery_web
	Write-Host "Recycling web UI app pool $skyquery_user_web_apppool on:"
	RecycleAppPool $servers "$skyquery_user_web_apppool"
}

#endregion
# -------------------------------------------------------------
#region CodeDB

function CreateCodeDb() {
	if ($skyquery_deploycodedb) {
		$databases = $skyquery_codedb
		$name = $databases[0]["Database"]
		Write-Host "CodeDB name is $name"
		Write-Host "Deploying CodeDB to:"
		foreach ($db in $databases) {
			Write-Host "... " $db["Server"]
			DeployDatabaseInstance $db["Name"]			
			Write-Host "... ... OK"
		}
	}
}

function DropCodeDb() {
	if ($skyquery_deploycodedb) {
		$databases = $skyquery_codedb
		$name = $databases[0]["Database"]
		Write-Host "CodeDB name is $name"
		Write-Host "Removing CodeDB from:"
		foreach ($db in $databases) {
			Write-Host "... " $db["Server"]
			DropDatabaseInstance $db["Name"]
			Write-Host "... ... OK"
		}
	}
}

function InstallCodeDbScripts() {
	if ($skyquery_deploycodedb) {
		$databases = $skyquery_codedb
		Write-Host "Installing CodeDB scripts to:"
		foreach ($db in $databases) {
			Write-Host "... " $db["Server"] $db["Database"]
			$s = $db["Server"]
			$d = $db["Database"]
			ExecSqlScript "$s" "$d" ".\bin\$skyquery_target\Jhu.Spherical.Sql.Create.sql"
			ExecSqlScript "$s" "$d" ".\bin\$skyquery_target\Jhu.SkyQuery.SqlClrLib.Create.sql"
			AddDatabaseUser "$s" "$d" "$skyquery_admin_account"
			AddDatabaseUserRole "$s" "$d" "$skyquery_admin_account" "db_owner"
			AddDatabaseUser "$s" "$d" "$skyquery_service_account"
			AddDatabaseUserRole "$s" "$d" "$skyquery_service_account" "db_owner"
			AddDatabaseUser "$s" "$d" "$skyquery_user_account"
			AddDatabaseUserRole "$s" "$d" "$skyquery_user_account" "db_owner"
			Write-Host "... ... OK"
		}
	}
}

function RemoveCodeDbScripts() {
	if ($skyquery_deploycodedb) {
		$databases = $skyquery_codedb
		Write-Host "Removing CodeDB scripts from:"
		foreach ($db in $databases) {
			$s = $db["Server"]
			$d = $db["Database"]
			Write-Host "... " $s $d
			ExecSqlScript "$s" "$d" ".\bin\$skyquery_target\Jhu.SkyQuery.SqlClrLib.Drop.sql"
			ExecSqlScript "$s" "$d" ".\bin\$skyquery_target\Jhu.Spherical.Sql.Drop.sql"
			Write-Host "... ... OK"
		}
	}
}

#endregion
# -------------------------------------------------------------
#region SkyNode utils

function DeploySkyNodeScripts($name, $version, $subset) {
	$databases = FindDatabaseInstances "DatabaseDefinition:Graywulf\SciServer\SkyQuery\$name" "$version"
	$scripts = FindFiles ".\skyquery-skynodes\sql\$dbname\*" "\d+_($subset).*\.sql"
	Write-Host "Deploying SkyNode scripts to:"
	foreach ($db in $databases) {
		$s = $db["Server"]
		$d = $db["Database"]
		Write-Host "... " $s $d
		foreach ($f in $scripts) {
			Write-Host "... ... " $f.Name
			ExecSqlScript "$s" "$d" $f.FullName
		}
	}
}

function ImportSkyNodeMetadata($name, $version) {
	$databases = FindDatabaseInstances "DatabaseDefinition:Graywulf\SciServer\SkyQuery\$name" "$version"
	$scripts = FindFiles ".\skyquery-skynodes\sql\$dbname\*" "\d+_meta\.xml"
	Write-Host "Generating SkyNode metadata to:"
	foreach ($db in $databases) {
		$s = $db["Server"]
		$d = $db["Database"]
		Write-Host "... " $s $d
		foreach ($f in $scripts) {
			Write-Host "... ... " $f.Name
			& ".\bin\$skyquery_target\gwmetautil.exe" import -Server "$s" -Database "$d" -E -Input "$($f.FullName)"
		}
	}
}

function FixSkyNodeUsers($name, $version) {
	$databases = FindDatabaseInstances "DatabaseDefinition:Graywulf\SciServer\SkyQuery\$name" "$version"
	Write-Host "Fixing SkyNode users in:"
	foreach ($db in $databases) {
		$s = $db["Server"]
		$d = $db["Database"]
		Write-Host "... " $s $d
		FixUsers "$s" "$d"
	}
}

#endregion
# -------------------------------------------------------------
#region Management utils

function FixUsers($server, $database) {
	$s = $server
	$d = $database
	# TODO: modify, skyquery-user is not dbo but allowed to read schema
	# TODO: modify to deal with read-only databases
	AddDatabaseUser "$s" "$d" "$skyquery_admin_account"
	AddDatabaseUserRole "$s" "$d" "$skyquery_admin_account" "db_owner"
	AddDatabaseUser "$s" "$d" "$skyquery_service_account"
	AddDatabaseUserRole "$s" "$d" "$skyquery_service_account" "db_owner"
	AddDatabaseUser "$s" "$d" "$skyquery_user_account"
	AddDatabaseUserRole "$s" "$d" "$skyquery_user_account" "db_owner"
}

function FlushSchema() {
	$servers = $skyquery_web
	Write-Host "Flushing schema cache on:"
	GetUrl $servers "$skyquery_user_host" "$skyquery_user_url/api/v1/manage.svc/schema/flush"
}

#endregion
# -------------------------------------------------------------
#region Unit tests

function FindTests($pattern) {
	Get-ChildItem -Recurse . | where { $_.PSIsContainer -and $_.Name -match ".*$pattern.*\.Test" }
}

function PrintTests($tests) {
	Write-Host "Tests found:"
	foreach ($t in $tests) {
		Write-Host " ... $($t.Name)"
	}
}

function RunTest($test, $outdir) {
	$name = "$($test.Name)"
	$dll = "$($test.FullName)\bin\$skyquery_target\$($test.Name).dll"
	$res = "$outdir\$name.trx"
	$err = "$outdir\$name.err"
	& 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\mstest.exe' /testcontainer:$dll /resultsfile:$res
}

function RunTests($tests) {
	$now = Get-Date
	$outdir = [string]::Format("{0:yyyyMMdd-hhmmss}", $now)
	$outdir = "TestResults\$outdir"
	mkdir -Path "$outdir"
	Write-Host "Executing tests in:"
	foreach ($t in $tests) {
		Write-Host " ... $($t.Name)"
		RunTest $t "$outdir"
	}
}

#endregion