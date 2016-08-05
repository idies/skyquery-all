function ExitOnError() {
	if ($LastExitCode -gt 0) { 
		exit 
	}
}

function LoadRegistryConnectionString() {
	$path = ".\bin\$skyquery_target\gwregutil.exe.config"
	$xpath = '//connectionStrings/add[@name="Jhu.Graywulf.Registry"]'
	$cstr = Select-Xml -XPath $xpath -Path $path | foreach { $_.node.connectionString } | Select-Object -first 1
	[Jhu.Graywulf.Registry.ContextManager]::Instance.ConnectionString = $cstr
}

function FindMachines($role) {
	$context = [Jhu.Graywulf.Registry.ContextManager]::Instance.CreateContext()
	
		$ef = New-Object Jhu.Graywulf.Registry.EntityFactory $context
		$mr = $ef.LoadEntity($role)
		$mr.LoadMachines($TRUE)
		$mm = $mr.Machines.Values | select -ExpandProperty HostName | select -ExpandProperty ResolvedValue
	
	$context.Dispose()
	
	return $mm
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
	
	return $ss
}