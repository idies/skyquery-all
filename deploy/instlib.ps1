#region Logging

function InstallLogging() {
	if ($skyquery_deployregistry) {
		Write-Host "Creating database for logging..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe CreateLog -Q -Username "$skyquery_user" -Role "db_owner"
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
		ExecLocal .\bin\$skyquery_target\gwregutil.exe CreateJobPersistence -Q -Username "$skyquery_user" -Role "db_owner"
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
	$cstr =[Jhu.Graywulf.Registry.ContextManager]::Instance.ConnectionString
	Write-Host $cstr
}

function LoadRegistryConnectionString() {
	$path = ".\bin\$skyquery_target\gwregutil.exe.config"
	$xpath = '//connectionStrings/add[@name="Jhu.Graywulf.Registry"]'
	$cstr = Select-Xml -XPath $xpath -Path $path | foreach { $_.node.connectionString } | Select-Object -first 1
	[Jhu.Graywulf.Registry.ContextManager]::Instance.ConnectionString = $cstr
}

function InstallRegistry() {
	if ($skyquery_deployregistry) {
		Write-Host "Creating database for registry..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe CreateRegistry -Q -Username "$skyquery_user" -Role "db_owner"
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

function ImportRegistry() {
	if ($skyquery_deployregistry) {
		Write-Host "Importing registry: cluster..."
		ExecLocal .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Cluster.xml -Duplicates Update
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
	$global:skyquery_mydb = FindMachines("MachineRole:Graywulf\MyDBHost")
	$global:skyquery_mydb_sql = FindServerInstances("MachineRole:Graywulf\MyDBHost")
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
	$skyquery_skynode + $skyquery_mydb
}

function InstallRemotingService() {
	if ($skyquery_deployremoteservice) {
		$servers = GetRemotingServiceServers
		InstallService $skyquery_remoteservice "C:\$skyquery_gwbin\gwrsvr.exe" $servers
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
	$skyquery_controller
}

function InstallScheduler() {
	if ($skyquery_deployscheduler) {
		$servers = GetSchedulerServers
		InstallService $skyquery_schedulerservice "C:\$skyquery_gwbin\gwscheduler.exe" $servers
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
		$servers = $skyquery_controller
		Write-Host "Copying web admin to:"
		CopyDir $servers ".\graywulf\web\Jhu.Graywulf.Web.Admin\*" "$skyquery_admin"
		Write-Host "Creating app pool for web admin on:"
		CreateAppPool $servers "Graywulf" $skyquery_user $skyquery_password
		Write-Host "Creating web app for web admin on:"
		CreateWebApp $servers "Default Web Site" "gwadmin" "C:\$skyquery_admin" "Graywulf"
	}
}

function RemoveWebAdmin() {
	if ($skyquery_deployadmin) {
		$servers = $skyquery_controller
		Write-Host "Removing web admin from:"
		RemoveWebApp $servers "Default Web Site" "gwadmin"
		RemoveAppPool $servers "Graywulf"
		RemoveDir $servers "$skyquery_admin"
	}
}

#endregion
# -------------------------------------------------------------
#region Web UI

function InstallWebUI() {
	if ($skyquery_deploywww) {
		$servers = $skyquery_web
		Write-Host "Copying web UI to:"
		CopyDir $servers ".\www\*" "$skyquery_www"
		Write-Host "Creating app pool for web UI on:"
		CreateAppPool $servers "Graywulf" $skyquery_user $skyquery_password
		Write-Host "Creating web app for web UI on:"
		CreateWebApp $servers "???" "skyquery" "C:\$skyquery_www" "Graywulf"
	}
}

function RemoveWebUI() {
	if ($skyquery_deploywww) {
		$servers = $skyquery_web
		Write-Host "Removing web UI from:"
		RemoveWebApp $servers "???" "skyquery"
		RemoveAppPool $servers "Graywulf"
		RemoveDir $servers "$skyquery_www"
	}
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
			Write-Host "... ... OK"
		}
	}
}

function RemoveCodeDbScripts() {
	if ($skyquery_deploycodedb) {
		$databases = $skyquery_codedb
		Write-Host "Removing CodeDB scripts from:"
		foreach ($db in $databases) {
			Write-Host "... " $db["Server"] $db["Database"]
			$s = $db["Server"]
			$d = $db["Database"]
			ExecSqlScript "$s" "$d" ".\bin\$skyquery_target\Jhu.SkyQuery.SqlClrLib.Drop.sql"
			ExecSqlScript "$s" "$d" ".\bin\$skyquery_target\Jhu.Spherical.Sql.Drop.sql"
			Write-Host "... ... OK"
		}
	}
}

#endregion