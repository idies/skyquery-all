skyquery-all
============

Complete SkyQuery project tree with submodules




Notes on submodules:

This repository is a collection of modules (supermodule) required to build SkyQuery. To clone this repository, make sure you do the following:

git clone --recursive git@github.com:idies/skyquery-all.git 

This will create and clone all submodules under the main repo. In TortoiseGit, check the Recursive box.

When submodules are cloned they always point to a specific commit and not to a branch. Consequently, changes made to the submodules cannot be commited without checking out the HEAD of a specific branch first. This can be done the usual way from the submodule's directory:

git checkout develop

Or using the Switch/Checkout... menu option from TortoiseGit.

Should anything in a submodule change, you will need to commit the changes to the submodule, push those changes and then commit changes to the supermodule and push those changes too. This is to track the latest commit of submodules by the supermodule. Failing to push submodule changes before pushing the supermoddule will result in an error when someone else clones the repository from remote.
