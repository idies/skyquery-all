skyquery-all
============

Complete SkyQuery project tree with submodules


**Notes on submodules:**
--------------------

This repository is a collection of modules (supermodule or superproject) required to build SkyQuery. To clone this repository, make sure you do the following:

git clone --recursive git@github.com:idies/skyquery-all.git 

This will create and clone all submodules under the main repo. In TortoiseGit, check the Recursive box.

When submodules are cloned they always point to a specific commit and not to a branch. Consequently, changes made to the submodules cannot be commited without checking out the HEAD of a specific branch first. This can be done the usual way from the submodule's directory:

git checkout develop

Or using the Switch/Checkout... menu option from TortoiseGit.

Should anything in a submodule change, you will need to commit the changes to the submodule, push those changes and then commit changes to the supermodule and push those changes too. This is to track the latest commit of submodules by the supermodule. Failing to push submodule changes before pushing the supermoddule will result in an error when someone else clones the repository from remote.

When commiting the supermodule, Git marks submodules as dirty when untracked files are present within submodule directories. To circumvent this, simply uncheck submodules at commit. When submodules are modified, pushing them should happen recursively when pushing the superproject.


**A few build issues**

Many projects in the solution are configured to use NuGet. NuGet packages are not always automatically restored (downloaded) on build. To force package restore, right click on the solution and enable package restore. Certain packages required by REST WCF are tricky to restore (Microsoft.Bcl is an especially picky one). If these don't restore automatically, try restarting Visual Studio.

--

This research project is supported by the following Hungarian grants: OTKA NN 103244, OTKA NN 114560
