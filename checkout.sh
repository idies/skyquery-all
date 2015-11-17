#!/bin/bash
#git clone --recursive --branch v1.1/develop git@github.com:idies/skyquery-all.git

cd graywulf
git checkout -B v1.1/develop remotes/origin/v1.1/develop --

cd ../graywulf-plugins
git checkout -B v1.1/develop remotes/origin/v1.1/develop --

cd ../graywulf-tools
git checkout -B v1.1/develop remotes/origin/v1.1/develop --

cd ../sharpfitsio
git checkout -B develop remotes/origin/develop --

cd ../skyquery
git checkout -B v1.1/develop remotes/origin/v1.1/develop --

cd ../skyquery-config
git checkout -B v1.1/develop remotes/origin/v1.1/develop --

cd ../skyquery-skynodes
git checkout -B v1.1/develop remotes/origin/v1.1/develop --

cd ../spherical
git checkout -B develop remotes/origin/develop --

cd ..