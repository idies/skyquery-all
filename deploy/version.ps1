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
	Write-Host `
"SkyQuery version tagging script.

Usage: .\version.ps1 <verb> [parameters] ...
Verbs:
	help 
		display this info
	print
		show modules with version numbers
	update [module_list]
		update version numbers automatically
	set <module_list> <version>
		set version number to exact value
	tag <module_list> <tag>
		create git tag

Parameters:
	module_list
		comma separated list or * for all
	version
		number in major.minor.revision format

Typical usage:
	1. Commit changes of all submodules
	2. Update version: .\version.ps1 update
	4. Push
"
} elseif ($verb -match "^print") {
	PrintGitVersion $modules
} elseif ($verb -match "^update") {
	UpdateGitVersion $modules
	echo "Don't forget to push tags!"
} elseif ($verb -match "^set") {
	SetGitVersion $modules $version
	echo "Don't forget to push tags!"
} elseif ($verb -match "^tag") {
	CreateTag $modules $tag
	echo "Don't forget to push tags!"
} else {
	Write-Host "Unrecognized verb: $verb."
	Write-Host "Type .\version.ps1 help to display usage."
}