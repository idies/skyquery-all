# Source install libraries
. .\deploy\instutil.ps1
. .\deploy\instlib.ps1
. .\deploy\sqlib.ps1

WrapItself $PSCommandPath $args

$verb = $args[1]
$config = $args[2]
$dbname = $args[3]
$dbversion = $args[4]

. Configure $config
Init
InitRegistry

if ($verb -match "^help") {
	Write-Host `
"SkyQuery SkyNode management script.

Usage: .\skynode.ps1 <verb> <config> [parameters]
Verbs:
	help
		display this info
	deploy <config> <dbname> <dbversion>
		run create and index .sql scripts on skynode databases
	dropmeta <config> <dbname> [dbversion]
		delete metadata from skynodes, dbversion is usually SCHEMA
	addmeta <config> <dbname> [dbversion]
		create metadata to skynodes, dbversion is usually SCHEMA
	fixuser <config> <dbname> [dbversion]
		fix service user privileges
	plot <config> <dbname>
		generate density plots

Parameters:
	config
		graywulf config
	dbname
		database definition name
	dbversion
		database version name

"
	echo "This will display the help some day."
} elseif ($verb -match "^deploy") {
	# Execute schema scripts on empty skynode database
	DeploySkyNodeScripts "$dbname" "$dbversion" "create|index"
} elseif ($verb -match "^dropmeta") {
	# Delete metadata from skynode
	if (!$dbversion) {
		$dbversion = "SCHEMA"
	}
	DropSkyNodeMetadata "$dbname" "$dbversion"
} elseif ($verb -match "^addmeta") {
	# Add metadata extended properties to skynode database ($dbversion is usually SCHEMA)
	if (!$dbversion) {
		$dbversion = "SCHEMA"
	}
	ImportSkyNodeMetadata "$dbname" "$dbversion"
} elseif ($verb -match "^fixuser") {
	# Fix users in database
	FixSkyNodeUsers "$dbname" "$dbversion"
} elseif ($verb -match "^plot") {
	# Generate density maps
	GenerateSkyNodeDensityPlots "$dbname"
} else {
	Write-Host "Unrecognized verb: $verb"
}