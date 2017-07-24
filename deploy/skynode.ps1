# Source install libraries
. .\deploy\instutil.ps1
. .\deploy\instlib.ps1
. .\deploy\sqlib.ps1

WrapItself $PSCommandPath $args

$verb = $args[1]
$dbname = $args[2]
$dbversion = $args[3]

. Configure
Init
InitRegistry

if ($verb -match "^help") {
	Write-Host `
"SkyQuery SkyNode management script.

Usage: .\skynode.ps1 <verb> [parameters]
Verbs:
	help
		display this info
	deploy <dbname> <dbversion>
		run create and index .sql scripts on skynode databases
	dropmeta <dbname> [dbversion]
		delete metadata from skynodes, dbversion is usually SCHEMA
	addmeta <dbname> [dbversion]
		create metadata to skynodes, dbversion is usually SCHEMA
	fixuser <dbname> [dbversion]
		fix service user privileges
	plot <dbname>
		generate density plots

Parameters:
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