param (
	[string]$config = "Debug"
)

$SolutionDir=pwd

& "C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe" `
	/P:SolutionDir="$SolutionDir\" `
	/P:SolutionName="skyquery-all" `
	/p:Configuration="$config" `
	/consoleloggerparameters:"Summary" `
	graywulf-build\src\Jhu.Graywulf.Build.ConfigUtil\Jhu.Graywulf.Build.ConfigUtil.csproj

& "C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe" `
	/target:rebuild `
	/verbosity:normal `
	/detailedsummary `
	/maxcpucount:16 `
	/consoleloggerparameters:"Summary" `
	/fileLogger /fileloggerparameters:ForceNoAlign `
	/p:Configuration="$config" `
	skyquery-all.sln