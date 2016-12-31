# Source install libraries
. .\deploy\instutil.ps1
. .\deploy\instlib.ps1

WrapItself $PSCommandPath $args

$verb = $args[1]
$config = $args[2]
$dbname = $args[3]
$dbversion = $args[4]

. Configure $config
Init
InitRegistry

if ($verb -match "^help") {
	# TODO
	echo "This will display the help some day."
} elseif ($verb -match "^deploy") {
	# Execute schema scripts on empty skynode database
	DeploySkyNodeScripts "$dbname" "$dbversion" "create|index"
} elseif ($verb -match "^addmeta") {
	# Add metadata extended properties to skynode database ($dbversion is usually SCHEMA)
	ImportSkyNodeMetadata "$dbname" "$dbversion" "create|index"
} elseif ($verb -match "^fixuser") {
	# Fix users in database
	FixSkyNodeUsers "$dbname" "$dbversion"
} else {
	Write-Host "Unrecognized verb: $verb"
}