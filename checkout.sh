#!/bin/bash
#git clone --recursive --branch v1.1/develop git@github.com:idies/skyquery-all.git

cd graywulf
git checkout -b v1.1/develop remotes/origin/v1.1/develop --

cd ../graywulf-plugins
git checkout -b v1.1/develop remotes/origin/v1.1/develop --

cd ../graywulf-tools
git checkout -b v1.1/develop remotes/origin/v1.1/develop --

cd ../skyquery
git checkout -b v1.1/develop remotes/origin/v1.1/develop --

cd ../skyquery-config
git checkout -b v1.1/develop remotes/origin/v1.1/develop --

cd ..