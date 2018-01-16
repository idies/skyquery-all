# Source install libraries
. .\deploy\instutil.ps1
. .\deploy\instlib.ps1

WrapItself $PSCommandPath $args

$verb = $args[1]

. Configure
Init
InitRegistry

if ($verb -match "^help") {
	# TODO
	echo "This will display the help some day."
} elseif ($verb -match "^export") {
	ExportRegistry
} elseif ($verb -match "^import") {
	ImportRegistry
}