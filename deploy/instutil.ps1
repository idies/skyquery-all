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

function FindDatabaseInstances($databaseDefinition) {
	$context = [Jhu.Graywulf.Registry.ContextManager]::Instance.CreateContext()
	
	$ef = New-Object Jhu.Graywulf.Registry.EntityFactory $context
	$dd = $ef.LoadEntity($databaseDefinition)
	$dd.LoadDatabaseInstances($TRUE)
	$di = $dd.DatabaseInstances.Values |
		foreach { @{
			"Name" = $_.GetFullyQualifiedName();
			"Server" = $_.ServerInstance.GetCompositeName();
			"Database" = $_.DatabaseName
		} }
	
	$context.Dispose()
	
	$di
}

#endregion
# -------------------------------------------------------------
#region Services

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
		-Args "$name", "$user", "$pass" `
		-Script {
			param($nm, $un, $pw)
			Import-Module WebAdministration
			cd IIS:\AppPools
			if (!(Test-Path $nm -pathType container))
			{
				$ap = New-Item $nm
				$ap.managedRuntimeVersion = "v4.0"
				$ap.processModel.userName = "$un"
				$ap.processModel.password = "$pw"
				$ap.processmodel.identityType = "SpecificUser"
				$ap | Set-Item
			}
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
				cd IIS:\AppPools
				rm -recurse -force '$nm'
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

#endregion
# -------------------------------------------------------------
#region Database and SQL scripts

function DeployDatabaseInstance($databaseInstance) {
	$context = [Jhu.Graywulf.Registry.ContextManager]::Instance.CreateContext()
	$ef = New-Object Jhu.Graywulf.Registry.EntityFactory $context
	$di = $ef.LoadEntity($databaseInstance)
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

#endregion
# -------------------------------------------------------------