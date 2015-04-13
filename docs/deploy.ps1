cd C:\data\dobos\project\skyquery-all\bin\Debug

$controller = "scitest02"
$nodes = "gw06", "gw07", "gw08", "gw09"
$servers = "scitest02", "gw06", "gw07", "gw08", "gw09"

foreach ( $s in $servers ) { mkdir \\$s\data\data0\graywulf\bin\debug }

foreach ( $s in $servers ) { rm \\$s\data\data0\graywulf\bin\debug\* -Force -Recurse }

foreach ( $s in $servers ) { cp * \\$s\data\data0\graywulf\bin\debug -Force -Recurse }

# Install remoting service (need to run manually because asks for password
& 'C:\windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe' C:\data\data0\graywulf\bin\debug\gwrsvr.exe

# Install scheduler (need to run manually because asks for password
& 'C:\windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe' C:\data\data0\graywulf\bin\debug\gwscheduler.exe


# Start services
icm $servers { net start GWRSvr }
icm $controller { net start SchedulerService }


# Copy web site
cp C:\Data\dobos\project\skyquery-all\bin \\scitest02\data\dobos\project\skyquery-all -Force -Recurse
cp C:\Data\dobos\project\skyquery-all\www \\scitest02\data\dobos\project\skyquery-all -Force -Recurse