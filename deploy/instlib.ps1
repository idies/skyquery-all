function Init($config) {
	# Framework path
	$global:fwpath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
		
	# Initialize registry
	InitRegistry
}

function ExitOnError() {
	if ($global:LastExitCode -gt 0) { 
		exit 
	}
}

function AskPassword() {
	$cred = Get-Credential $skyquery_serviceaccount
	$cred.UserName
	$cred.GetNetworkCredential().Password
}

function InitRegistry() {
	Add-Type -Path ".\bin\$skyquery_target\Jhu.Graywulf.Registry.dll"
	Add-Type -Path ".\bin\$skyquery_target\Jhu.Graywulf.Registry.Enum.dll"
	LoadRegistryConnectionString
}

function LoadRegistryConnectionString() {
	$path = ".\bin\$skyquery_target\gwregutil.exe.config"
	$xpath = '//connectionStrings/add[@name="Jhu.Graywulf.Registry"]'
	$cstr = Select-Xml -XPath $xpath -Path $path | foreach { $_.node.connectionString } | Select-Object -first 1
	[Jhu.Graywulf.Registry.ContextManager]::Instance.ConnectionString = $cstr
}

function InstallLogging() {
	Write-Host "Creating database for logging..."
	& .\bin\$skyquery_target\gwregutil.exe CreateLog -Q -Username "$skyquery_user" -Role "db_owner"
	ExitOnError
}

function InstalleJobPersistence() {
	Write-Host "Creating database for job persistence store..."
	& .\bin\$skyquery_target\gwregutil.exe CreateJobPersistence -Q -Username "$skyquery_user" -Role "db_owner"
	ExitOnError
}

function InstallRegistry() {
	Write-Host "Creating database for registry..."
	& .\bin\$skyquery_target\gwregutil.exe CreateRegistry -Q -Username "$skyquery_user" -Role "db_owner"
	ExitOnError
	& .\bin\$skyquery_target\gwregutil.exe AddCluster -Q -cluster "Graywulf" -User admin -Email admin@graywulf.org -Password alma
	ExitOnError
	& .\bin\$skyquery_target\gwregutil.exe AddDomain -Q -cluster "Cluster:Graywulf" -Domain "SciServer"
	ExitOnError
}

function InstallSkyQuery() {
	Write-Host "Installing SkyQuery..."
	& .\bin\$skyquery_target\sqregutil.exe install -Domain "Domain:Graywulf\SciServer"
	ExitOnError
}

function ImportRegistry() {
	Write-Host "Importing registry: cluster..."
	& .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Cluster.xml -Duplicates Update
	ExitOnError
	Write-Host "Importing registry: federation..."
	& .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Federation.xml -Duplicates Update
	ExitOnError
	Write-Host "Importing registry: layout..."
	& .\bin\$skyquery_target\gwregutil.exe Import -Input .\$config\SkyQuery_Layout.xml -Duplicates Update
	ExitOnError
}

function FindMachines($role) {
	$context = [Jhu.Graywulf.Registry.ContextManager]::Instance.CreateContext()
	
		$ef = New-Object Jhu.Graywulf.Registry.EntityFactory $context
		$mr = $ef.LoadEntity($role)
		$mr.LoadMachines($TRUE)
		$mm = $mr.Machines.Values | 
			where-object {$_.DeploymentState -eq [Jhu.Graywulf.Registry.DeploymentState]::Deployed} |
			foreach { "$($_.Hostname.ResolvedValue)" }
	
	$context.Dispose()
	
	$mm
}

function FindServerInstances($role) {
	$context = [Jhu.Graywulf.Registry.ContextManager]::Instance.CreateContext()
	
		$ef = New-Object Jhu.Graywulf.Registry.EntityFactory $context
		$mr = $ef.LoadEntity($role)
		$mr.LoadMachines($TRUE)
		$mm = $mr.Machines.Values
		$ss = @()
		
		foreach ($m in $mm) {
			$m.LoadServerInstances($TRUE)
			$ss += $m.ServerInstances.Values | foreach { $_.GetCompositeName() }
		}
	
	$context.Dispose()
	
	$ss
}

function FindServers() {
	Write-Host "Finding servers..."

	$global:skyquery_controller = FindMachines("MachineRole:Graywulf\Controller")
	$global:skyquery_skynode = FindMachines("MachineRole:Graywulf\SkyNode")
	$global:skyquery_skynode_sql = FindServerInstances("MachineRole:Graywulf\SkyNode")
	$global:skyquery_web = FindMachines("MachineRole:Graywulf\Web")
	$global:skyquery_mydb = FindMachines("MachineRole:Graywulf\MyDBHost")
	$global:skyquery_mydb_sql = FindServerInstances("MachineRole:Graywulf\MyDBHost")
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
}

## ------------------------------------

function GetBinariesServers() {
	$skyquery_controller + $skyquery_skynode + $skyquery_mydb
}

function CopyBinaries() {
	$servers = GetBinariesServers
	Write-Host "Copying binaries to:"
	Write-Host $servers
	foreach ($s in $servers) {
		Write-Host "... ${s}:"
		if (-Not (Test-Path \\$s\$skyquery_gwbin)) {
			mkdir \\$s\$skyquery_gwbin
		}
		rm -force -recurse \\$s\$skyquery_gwbin\*
		cp .\bin\$skyquery_target\* \\$s\$skyquery_gwbin -recurse -force 
		Write-Host "... ... OK"
	}
}

function RemoveBinaries() {
	$servers = GetBinariesServers
	Write-Host "Removing binaries from:"
	Write-Host $servers
	foreach ($s in $servers) {
		Write-Host "... ${s}:"
		rm -force -recurse \\$s\$skyquery_gwbin
		Write-Host "... ... OK"
	}
}

## ------------------------------------

function InstallService([string] $name, [string] $exe, [string[]] $servers) {
	Write-Host "Installing service $name on:"
	foreach ($s in $servers) {
		Write-Host "... $s"
		icm $s `
			-Args $skyquery_user, $skyquery_pass, $exe, $fwpath, $name `
			-Script {
				param($un, $pw, $xe, $fw, $sn) 
				& $fw\InstallUtil.exe /username=$un /password=$pw /unattended /svcname=$sn $xe
			}
		Write-Host "... ... OK"
	}
}

function StartService([string] $name, [string[]] $servers) {
	Write-Host "Starting service $name on:"
	foreach ($s in $servers) {
		Write-Host "... $s"
		icm $s -Script { 
			param($sn) 
			net start $sn 
		} -Args $name
		Write-Host "... ... OK"
	}
}

function StopService([string] $name, [string[]] $servers) {
	Write-Host "Stopping service $name on:"
	foreach ($s in $servers) {
		Write-Host "... $s"
		icm $s ` -Script { 
			param($sn) 
			net stop $sn 
		} -Args $name
		Write-Host "... ... OK"
	}
}

function RemoveService([string] $name, [string] $exe, [string[]] $servers) {
	Write-Host "Removing service $name from:"
	foreach ($s in $servers) {
		Write-Host "... $s"
		icm $s `
			-Args $skyquery_gwbin, $exe, $fwpath, $name `
			-Script { 
				param($gw, $xe, $fw, $sn) 
				& $fw\InstallUtil.exe /u /svcname=$sn $xe
			} 
		Write-Host "... ... OK"
	}
}

## ------------------------------------

function GetRemotingServiceServers() {
	$skyquery_skynode + $skyquery_mydb
}

function InstallRemotingService() {
	$servers = GetRemotingServiceServers
	InstallService $skyquery_remoteservice "C:\$skyquery_gwbin\gwrsvr.exe" $servers
}

function StartRemotingService() {
	$servers = GetRemotingServiceServers
	StartService $skyquery_remoteservice $servers
}

function StopRemotingService() {
	$servers = GetRemotingServiceServers
	StopService $skyquery_remoteservice $servers
}

function RemoveRemotingService() {
	$servers = GetRemotingServiceServers
	RemoveService $skyquery_remoteservice "C:\$skyquery_gwbin\gwrsvr.exe" $servers
}

## ------------------------------------

function GetSchedulerServers() {
	$skyquery_controller
}

function InstallScheduler() {
	$servers = GetSchedulerServers
	InstallService $skyquery_schedulerservice "C:\$skyquery_gwbin\gwscheduler.exe" $servers
}

function StartScheduler([string[]] $servers) {
	$servers = GetSchedulerServers
	StartService $skyquery_schedulerservice $servers
}

function StopScheduler([string[]] $servers) {
	$servers = GetSchedulerServers
	StopService $skyquery_schedulerservice $servers
}

function RemoveScheduler() {
	$servers = GetSchedulerServers
	RemoveService $skyquery_schedulerservice "C:\$skyquery_gwbin\gwscheduler.exe" $servers
}

## ------------------------------------

function CopyWebAdmin([string[]] $servers) {
}

function CopyWebUI([string[]] $servers) {
	Write-Host "Copying web UI to:"
	Write-Host $servers
	foreach ( $s in $server) {
		if (-Not (Test-Path \\$s\$skyquery_www)) {
			mkdir \\$s\$skyquery_www
		}
		rm -force -recurse \\$s\$skyquery_www\*
		cp .\www\* \\$s\$skyquery_www -recurse -force 
	}
}