# Source install libraries
. .\deploy\instutil.ps1
. .\deploy\instlib.ps1

WrapItself $PSCommandPath $args

$verb = $args[1]
$pattern = $args[2]

. Configure

if (!$pattern) {
	$pattern = ""
}

$tests = FindTests $pattern

if ($verb -match "^help") {
	# TODO
	echo "This will display the help some day."
} elseif ($verb -match "^print") {
	PrintTests $tests
} elseif ($verb -match "^run") {
	RunTests $tests
} else {
	Write-Host "Unrecognized verb: $verb"
}