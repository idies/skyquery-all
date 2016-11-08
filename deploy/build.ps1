param (
	[string]$root = "config\default"
)

# Set config root
$configfile = Get-Item gwconfig.xml
[xml]$xml = Get-Content $configfile
$xml.config.root = $root
$xml.Save($configfile.FullName)

. $root\configure.ps1

$SolutionDir=pwd

echo "Starting build for config '$root' with target '$skyquery_target'"
echo "Building config tool..."

& "C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe" `
	/target:rebuild `
	/maxcpucount:16 `
	/P:SolutionDir="$SolutionDir\" `
	/P:SolutionName="skyquery-all" `
	/p:Configuration="$skyquery_target" `
	/clp:Summary `
	/verbosity:normal `
	"graywulf-build\src\Jhu.Graywulf.Build.ConfigUtil\Jhu.Graywulf.Build.ConfigUtil.csproj"

echo "Building SQL CLR scripting tool..."

& "C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe" `
	/target:rebuild `
	/maxcpucount:16 `
	/P:SolutionDir="$SolutionDir\" `
	/P:SolutionName="skyquery-all" `
	/p:Configuration="$skyquery_target" `
	/clp:Summary `
	/verbosity:normal `
	"graywulf-build\src\Jhu.Graywulf.SqlClrUtil\Jhu.Graywulf.SqlClrUtil.csproj"

echo "Building SkyQuery..."

& "C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe" `
	/target:rebuild `
	/maxcpucount:16 `
	/verbosity:normal `
	/clp:"Summary;EnableMPLogging" `
	/fileLogger /fileloggerparameters:ForceNoAlign `
	/p:Configuration="$skyquery_target" `
	"skyquery-all.sln"