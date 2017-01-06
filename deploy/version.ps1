# Source install libraries
. .\deploy\instutil.ps1
. .\deploy\instlib.ps1

WrapItself $PSCommandPath $args

$verb = $args[1]
$modules = $args[2]
$version = $args[3]

if (!$modules -or ($modules -eq "*")) {
	$modules = @(".")
	$modules += GetSubmodules
}

$modules = $modules | where { Test-Path "$_\build.config" }

if ($verb -match "^help") {
	# TODO
	echo "This will display the help some day."
} elseif ($verb -match "^print") {
	PrintConfigVersion $modules
} elseif ($verb -match "^update") {
	[datetime]$now = Get-Date
	UpdateConfigVersion $modules $now
	echo "Don't forget to commit before tagging!"
} elseif ($verb -match "^set") {
	SetConfigVersion $modules $version
	echo "Don't forget to commit before tagging!"
} elseif ($verb -match "^tag") {
	# Create tag base on current version
	CreateTag $modules
	echo "Don't forget to push tags!"
} else {
	Write-Host "Unrecognized verb: $verb"
}