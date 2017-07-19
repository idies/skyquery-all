$GRAYWULF="v1.3/develop"
$SKYQUERY="v1.3/develop"
$SHARPFITSIO="develop"
$SPHERICAL="develop"
$SCISERVER="skyquery"

cd graywulf
git checkout -B $GRAYWULF remotes/origin/$GRAYWULF --

cd ../graywulf-build
git checkout -B $GRAYWULF remotes/origin/$GRAYWULF --

cd ../graywulf-plugins
git checkout -B $GRAYWULF remotes/origin/$GRAYWULF --

cd ../graywulf-tools
git checkout -B $GRAYWULF remotes/origin/$GRAYWULF --

cd ../graywulf-sciserver-init
git checkout -B $GRAYWULF remotes/origin/$GRAYWULF --

cd ../sharpfitsio
git checkout -B $SHARPFITSIO remotes/origin/$SHARPFITSIO --

cd ../skyquery
git checkout -B $SKYQUERY remotes/origin/$SKYQUERY --

cd ../skyquery-config
git checkout -B $SKYQUERY remotes/origin/$SKYQUERY --

cd ../skyquery-skynodes
git checkout -B $SKYQUERY remotes/origin/$SKYQUERY --

cd ../spherical
git checkout -B $SPHERICAL remotes/origin/$SPHERICAL --

cd ../sciserver-logging
git checkout -B $SCISERVER remotes/origin/$SCISERVER --

cd ..