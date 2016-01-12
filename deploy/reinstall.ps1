# Reinstalls SkyQuery binary components and web sites
# before execution, make sure to dot source an appropriate config file:
# . .\skyquery-config\scidev01\configure.ps1
# .\deploy\reinstall.ps1

# Stop the scheduler
if ($skyquery_deployscheduler)
{
	echo "Stopping scheduler on the controller..."
	icm $skyquery_scheduler_nodes -Script { param($sn) net stop $sn } -Args $skyquery_schedulerservice
}

# Stop the remoting service
if ($skyquery_deployremoteservice)
{
	echo "Stopping remoting service '$skyquery_remoteservice' on all servers..."
	icm $skyquery_remoteservice_nodes -Script { param($sn) net stop $sn } -Args $skyquery_remoteservice
}

# Overwrite binaries
if ($skyquery_deployscheduler -or $skyquery_deployremoteservice) {
	echo "Copying binaries to all servers..."
	foreach ( $s in ($skyquery_scheduler_nodes + $skyquery_remoteservice_nodes)) {
		cp .\bin\$skyquery_target\* \\$s\$skyquery_gwbin -recurse -force 
	}
}

# Overwrite web sites on the controller
if ($skyquery_deploywww)
{
	echo "Deploying web site to controller"
	foreach ( $s in $skyquery_controller ) { cp .\www\* \\$s\$skyquery_www -recurse -force }
}

# Deploy code database scripts
if ($skyquery_deploycodedb)
{
	echo "Deploying CODE DB scripts"
	foreach ( $s  in $skyquery_database_nodes ) 
	{ 
		echo $s
		sqlcmd -S $s -E -d $skyquery_codedb -i .\bin\$skyquery_target\Jhu.SkyQuery.SqlClrLib.Drop.sql 
		sqlcmd -S $s -E -d $skyquery_codedb -i .\bin\$skyquery_target\Jhu.Spherical.Sql.Drop.sql
		sqlcmd -S $s -E -d $skyquery_codedb -i .\bin\$skyquery_target\Jhu.Spherical.Sql.Create.sql
		sqlcmd -S $s -E -d $skyquery_codedb -i .\bin\$skyquery_target\Jhu.SkyQuery.SqlClrLib.Create.sql
	}
}

# Restart remoting service
if ($skyquery_deployremoteservice)
{
	echo "Starting remoting service '$skyquery_remoteservice' on all servers..."
	icm $skyquery_remoteservice_nodes -Script { param($sn) net start $sn } -Args $skyquery_remoteservice
}

# Restart scheduler
if ($skyquery_deployscheduler)
{
	echo "Starting scheduler on the controller..."
	icm $skyquery_scheduler_nodes -Script { param($sn) net start $sn } -Args $skyquery_schedulerservice
}