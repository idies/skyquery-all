# Source install libraries
. .\deploy\instutil.ps1
. .\deploy\instlib.ps1

WrapItself $PSCommandPath $args

$verb = $args[1]
$config = $args[2]
$pattern = $args[3]

. Configure $config

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