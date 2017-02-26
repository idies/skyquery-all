#region Generic utilities

function Init($config) {
	$global:fwpath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
}

function HandleError {
	if ($global:LastExitCode -gt 0 -and $global:ErrorActionPreference -match "stop") {
		exit
	}
}

function AskPassword($account) {
	$cred = Get-Credential $account
	$cred.UserName
	$cred.GetNetworkCredential().Password
}

function GetConnectionString($name) {
	$path = ".\bin\$skyquery_target\gwregutil.exe.config"
	$xpath = "//connectionStrings/add[@name=`"$name`"]"
	$cstr = Select-Xml -XPath $xpath -Path $path | foreach { $_.node.connectionString } | Select-Object -first 1
	$cstr
}

function GetServerAndDatabase($cstr) {
	$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder;
	$csb.psbase.ConnectionString = $cstr
	$csb["Data Source"]
	$csb["Initial Catalog"]
}

function RenderArgument($a) {
	if ($a.GetType().Name -match 'ScriptBlock') {
		$r = "{ $a }"
	} elseif ($a.GetType().Name -match 'string' -and $a -match ' ') {
		$r = "`"$a`""
	} elseif ($a.GetType().Name -match '\[\]') {
		$r = ""
		foreach ($aa in $a) {
			if (!($r -eq "")) {
				$r += ", "
			}
			$r += RenderArgument($aa)
		}
	} else {
		$r = $a
	}

	return $r
}

function RenderCommand($arguments) {
	$cmd = ""
	foreach ($a in $arguments) {
		$cmd += RenderArgument($a)
		$cmd += " "
	}
	return $cmd
}

function ExecLocal {
	$cmd = RenderCommand($args)
	iex $cmd
	HandleError
}

function ForEachServer($servers) {
	$cmd = RenderCommand($args)
	foreach ($s in $servers) {
		Write-Host "... $s"
		iex $cmd
		Write-Host "... ... OK"
	}
}

#endregion
# -------------------------------------------------------------
#region File utilities

function FindFiles($dir, $pattern) {
	$files = ls "$dir" | 
		where {$_.Name -match "$pattern" } | sort "Name"
	$files
}

function CopyDir($servers, $source, $target) {
	ForEachServer $servers icm `
		-Args "$source", "\\`$s\$target" `
		-Script {
			param($source, $target)
			if (!(Test-Path $target)) {
				mkdir $target
			}
			rm -force -recurse "$target\*"
			cp "$source" "$target" -recurse -force 
		}
}

function RemoveDir($servers, $target) {
	ForEachServer $servers icm `
		-Args "\\`$s\$target" `
		-Script {
			param($target)
			rm -force -recurse "$target\*"
		}
}

function CreateShare($servers, $path, $share) {
	ForEachServer $servers icm `
		-Args "$path", "$share" `
		-Script {
			param($path, $share)
			if (!(Test-Path "$path")) {
				mkdir "$path"
			}
			$Shares=[WmiClass]"WIN32_Share"
			if (!(Get-WmiObject Win32_Share -filter "name=`"$share`"")) { 
                $Shares.Create($path ,$share, 0) 
			} 
		}
}

#endregion
# -------------------------------------------------------------
#region Version tagging

function GetConfigFile($filename) {
	$configfile = Get-Item "$filename"
	$configfile
}

function GetConfig($configfile) {
	[xml]$config = Get-Content $configfile
	$config
}

function GetVersion($config) {
	[string]$version = $config.config.assemblySettings.version
	$version
}

function GetPrefix($config) {
	[string]$prefix = $config.config.assemblySettings.prefix
	$prefix
}

function IncrementVersion($version) {
	$parts = $version.Split('.')
	$version = ""
	for($i = 0; $i -lt $parts.Count - 1; $i++) {
		[int]$v = $parts[$i]
		$version = "$version$v."
	}
	[int]$v = $parts[$parts.Count - 1]
	$v = $v + 1
	$version = "$version$v"
	$version
}

function IncrementVersionFromDate($version, $now) {
	# Build number is the number of days since January 1, 2000
	[datetime]$start='01/01/2000'
		
	# Update version number.
	$parts = $version.Split('.')
	[string]$major = $parts[0]
	[string]$minor = $parts[1]
	[string]$build = ($now - $start).Days
	if ($build -match $parts[2]) {
		[string]$revision = $([int]$parts[3]) + 1
	} else {
		[string]$revision = "0"
	}
	[string]$version = "$major.$minor.$build.$revision"

	$version
}

function UpdateVersion($config, $version) {
	$config.config.assemblySettings.version = $version
}

#endregion
# -------------------------------------------------------------
#region Registry

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

function FindDatabaseInstances($databaseDefinition, $databaseVersion) {
	$context = [Jhu.Graywulf.Registry.ContextManager]::Instance.CreateContext()

	$ef = New-Object Jhu.Graywulf.Registry.EntityFactory $context
	$dd = $ef.LoadEntity($databaseDefinition)
	$dd.LoadDatabaseInstances($TRUE)
	$di = $dd.DatabaseInstances.Values |
		foreach { @{
			"Name" = $_.GetFullyQualifiedName();
			"Server" = $_.ServerInstance.GetCompositeName();
			"Database" = $_.DatabaseName;
			"Version" = $_.DatabaseVersion.Name;
		} }
	if ($databaseVersion) {
		$di = $di | where {$_["Version"] -eq "$databaseVersion"}
	}
	
	$context.Dispose()
	$di
}

#endregion
# -------------------------------------------------------------
#region Services

function InstallService([string[]] $servers, [string] $name, [string] $exe, [string] $user, [string] $pass) {
	Write-Host "Installing service $name on:"
	foreach ($s in $servers) {
		Write-Host "... $s"
		icm $s `
			-Args $user, $pass, $exe, $fwpath, $name `
			-Script {
				param($un, $pw, $xe, $fw, $sn) 
				& $fw\InstallUtil.exe /username=$un /password=$pw /unattended /svcname=$sn $xe
			}
		Write-Host "... ... OK"
	}
}

function StartService($servers, $name) {
	Write-Host "Starting service $name on:"
	ForEachServer $servers icm '$s' `
		-Args $name `
		-Script { 
			param($sn) 
			Start-Service $sn 
		}
}

function StopService($servers, $name) {
	Write-Host "Stopping service $name on:"
	ForEachServer $servers icm '$s' `
		-Args $name `
		-Script { 
			param($sn) 
			Stop-Service $sn 
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

#endregion
# -------------------------------------------------------------
#region Web interfaces

function CreateAppPool($servers, $name, $user, $pass) {
	ForEachServer $servers icm '$s' `
		-Args '$name', '$user', '$pass' `
		-Script {
			param($nm, $un, $pw)
			Import-Module WebAdministration
			cd IIS:\AppPools
			if (!(Test-Path $nm -pathType container))
			{
				$ap = New-Item "$nm"
			} else {
				$ap = Get-Item "$nm"
			}

			$ap.managedRuntimeVersion = "v4.0"
			$ap.processModel.userName = "$un"
			$ap.processModel.password = "$pw"
			$ap.processModel.identityType = "SpecificUser"
			$ap.processModel.loadUserProfile = $true
			$ap | Set-Item
		}
}

function RemoveAppPool($servers, $name) {
	foreach ($s in $servers) {
		Write-Host "... $s"
		icm $s `
			-Args $name `
			-Script {
				param($nm)
				Import-Module WebAdministration
				rm -Recurse -Force "IIS:\AppPools\$nm"
			}
		Write-Host "... ... OK"
	}
}

function RecycleAppPool($servers, $name) {
	foreach ($s in $servers) {
		Write-Host "... $s"
		icm $s `
			-Args $name `
			-Script {
				param($nm)
				Import-Module WebAdministration
				Restart-WebAppPool "$nm"
			}
		Write-Host "... ... OK"
	}
}

function CreateWebApp($servers, $site, $name, $path, $apppool) {
	ForEachServer $servers icm '$s' `
		-Args "$site", "$name", "$path", "$apppool" `
		-Script {
			param($st, $nm, $pp, $ap)
			Import-Module WebAdministration
			cd "IIS:\Sites\$st"
			if (!(Test-Path "$nm" -pathType container)) {
				$app = New-WebApplication "$nm" `
					-Site "$st" `
					-ApplicationPool "$ap" `
					-PhysicalPath "$pp"
			}
		}
}

function RemoveWebApp($servers, $site, $name) {
	ForEachServer $servers icm '$s' `
		-Args "$site", "$name" `
		-Script {
			param($st, $nm)
			Import-Module WebAdministration
			rm "IIS:\Sites\$st\$nm" -Force -Recurse
		}
}

function InstallWebSite($servers, $source, $target, $apppool, $account, $passwd, $site, $app) {
	Write-Host "Copying web `'$app`' to:"
	CopyDir $servers "$source" "$target"
	Write-Host "Creating app pool `'$apppool`' on:"
	CreateAppPool $servers "$apppool" "$account" "$passwd"
	Write-Host "Creating web app `'$app`' under site `'$site`' on:"
	CreateWebApp $servers "$site" "$app" "C:\$target" "$apppool"
}

function RemoveWebSite($servers, $target, $apppool, $site, $app) {
	Write-Host "Removing web app `'$app`' from:"
	RemoveWebApp $servers "$site" "$app"
	Write-Host "Removing app pool `'$apppool`' from:"
	RemoveAppPool $servers "$apppool"
	Write-Host "Removing web `'$app`' from:"
	RemoveDir $servers "$target"
}

#endregion
# -------------------------------------------------------------
#region Database and SQL scripts

function DeployDatabaseInstance($databaseInstance) {
	$context = [Jhu.Graywulf.Registry.ContextManager]::Instance.CreateContext()
	$ef = New-Object Jhu.Graywulf.Registry.EntityFactory $context
	$di = $ef.LoadEntity($databaseInstance)
	$di.Discover()
	if ($di.DeploymentState -ne [Jhu.Graywulf.Registry.DeploymentState]::Deployed) {
		$di.Deploy()
	}
	$context.Dispose()
}

function DropDatabaseInstance($databaseInstance) {
	$context = [Jhu.Graywulf.Registry.ContextManager]::Instance.CreateContext()
	$ef = New-Object Jhu.Graywulf.Registry.EntityFactory $context
	$di = $ef.LoadEntity($databaseInstance)
	$di.Undeploy()
	$context.Dispose()
}

function ExecSqlScript($server, $database, $script) {
	sqlcmd -S "$server" -E -d "$database" -i "$script"
}

function AddDatabaseUser($server, $database, $user) {
	$sql = "CREATE USER [$user] FOR LOGIN [$user]"
	sqlcmd -S "$server" -E -d "$database" -Q "$sql"
}

function AddDatabaseUserRole($server, $database, $user, $role) {
	$sql = "ALTER ROLE [$role] ADD MEMBER [$user]"
	sqlcmd -S "$server" -E -d "$database" -Q "$sql"
}

#endregion
# -------------------------------------------------------------
#region Web requests

function GetUrl($servers, $hostname, $url) {
	foreach ($s in $servers) {
		Write-Host "... $s"
		$wc = New-Object net.webclient
		$wc.Headers.Add("Host", $hostname)
		$res = $wc.DownloadString($url.replace('$server', $s))
		Write-Host "... ... OK"
	}
}

#endregion

#endregion
