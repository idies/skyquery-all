echo "Exporting cluster settings..."
.\bin\Debug\gwregutil.exe export -root "Cluster:Graywulf" -Output "SkyQuery_Cluster.xml" -Cluster -ExcludeUserCreated
if ($LastExitCode -gt 0) { exit }

echo "Exporting SkyQuery federation..."
.\bin\Debug\gwregutil.exe export -root "Federation:Graywulf\SciServer\SkyQuery" -Output "SkyQuery_Federation.xml" -Federation -ExcludeUserCreated
if ($LastExitCode -gt 0) { exit }

echo "Exporting SkyQuery layout..."
.\bin\Debug\gwregutil.exe export -root "Federation:Graywulf\SciServer\SkyQuery" -Output "SkyQuery_Layout.xml" -Layout -ExcludeUserCreated
if ($LastExitCode -gt 0) { exit }