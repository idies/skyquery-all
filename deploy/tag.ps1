$verb = $args[0]
$configfile = Get-Item build.config
[xml]$config = Get-Content $configfile
[string]$version = $config.config.version

if ($verb -match "^help") {
	# TODO
	echo "This will display the help some day."
} elseif ($verb -match "^update") {
	# Update version number
	# Build number is the number of days since January 1, 2000
	[datetime]$start='01/01/2000'
	[datetime]$now = Get-Date
	# Update version number.
	$parts = $version.Split('.')
	[string]$major = $parts[0]
	[string]$minor = $parts[1]
	[string]$build = ($now - $start).Days
	if ($build -match $parts[2]) {
		[string]$revision = $([int]$parts[3]) + 1
	} else {
		[string]$revision = "0"
	}
	[string]$version = "$major.$minor.$build.$revision"
	$config.config.version = $version
	$config.Save($configfile.FullName)
	echo $version
	echo "Don't forget to rebuild and commit before tagging!"
} elseif ($verb -match "^version") {
	# Print current version number
	echo $version
} elseif ($verb -match "^create") {
	# Create tag base on current version
	git tag "skyquery-$version"
	# Get a list of submodules
	$modules=git config --file .gitmodules --name-only --get-regexp path | %{"$($_.Split('.')[1])"}
	foreach ($module in $modules) {
		cd $module
		git tag "skyquery-v$version"
		cd ..
	}
	echo "Don't forget to push tags!"
} else {
	Write-Host "Unrecognized verb: $verb"
}