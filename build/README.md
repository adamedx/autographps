Build README
============

This document describes how to build AutoGraphPS and provides additional information on build customizations and advanced development scenarios.

## Prerequisites

**AutoGraphPS** development requires the following:

* A **Windows 10** operating system or later
* The [NuGet version 4.0 or later](https://nuget.org) command-line tools, which can be installed [here](https://dist.nuget.org/win-x86-commandline/latest/nuget.exe).
* [PowerShellGet](https://www.powershellgallery.com/packages/PowerShellGet) module [version 1.6.0](https://www.powershellgallery.com/packages/PowerShellGet/1.6.0). Other versions are not currently supported due to known incompatibilities.
* [Git command-line tools](https://git-for-windows.github.io/) to clone this repository locally:

```powershell
git clone https://github.com/adamedx/AutoGraphPS
cd AutoGraphPS
```

Note: PowerShellGet version 1.6.6 is incompatible with AutoGraphPS due to a code defect. Versions other than 1.6.0 have not been tested; [install 1.6.0](https://www.powershellgallery.com/packages/PowerShellGet/1.6.0) in order to build this module.

### Simple building and debugging
The most common case is to build the module and then execute it in a new shell.

### Build a new module
To create a new version of the module in the `pkg` output directory, run this command:

```powershell
.\build\configure-tools.ps1 # only needed before your first build
.\build\build-package.ps1 -downloaddependencies
```

The `-downloaddependencies` option is only required the first time you perform a build, or if you've run a "clean build" command or realize you need to update the project's non-[PowerShell Gallery](https://powershellgallery.com) dependencies (dependent modules are sources from PowerShell Gallery and are managed through subsequent build operations described below). Note that you do not need to do this every time you make a code change -- it is only strictly necessary when you want to test module installation or generate an installable / publishable module package, or if you simply want to verify that you haven't broken the build.

### Test your code changes
It is best to test your code changes in a shell session in which all dependent modules are loaded. The commands below will create such a shell. Note that you do not need to run these commands to test every code change. For ad-hoc testing, it is generally sufficient to launch the shell, and then enable your code changes by simply dot-sourcing the file(s) in which you've made changes. To run automated tests or to perform extended interactive scenario testing, it is actually best to run these commands to create the new shell:

```powershell
.\build\publish-moduletodev.ps1
```

This creates a local PowerShell Gallery-compatible repository under the directory `.psrepo` that contains the PowerShell module and dependencies copied down any PowerShell modules from which it depends from PowerShell Gallery. This then allows commands like `install-module` to install the module to your test system for real-world testing.

It also allows you to simply start a shell in which the module is loaded with your code changes for ad-hoc testing without module installation or making any configuration / applications changes to your system with the following command:

```powershell
.\build\import-devmodule.ps1
```

The resulting shell can be used as if you had installed your module for ad-hoc testing, and you can also run the module's automated tests from it.

#### Automated tests
AutoGraphPS's automated tests can be executed by starting a shell via the previously described `import-devmodule` script and executing the following command from within the shell:

```powershell
invoke-pester
```

#### Debugging and testing tips
Maintaining a fast dev / test / debug loop is crucial for your productivity, and also for your sanity.

Once you've invoked `publish-moduletodev` and `import-devmodule` as described above, do you need to run them every time you make a code change (i.e. after you fix a defect found from automated or ad-hoc testing)? Most of the time the answer is *no*: you can usually re-use the existing PowerShell session after refreshing the code, and even when you can't, you can usually get a new session fairly quickly. Here's how that works:

* If you edit one of the module's existing source files that is already loaded into your dev session:
  * **Dot-source:** In most cases, you an just dot-source the source file with your change. Note that some files may reset shared state and require you to dot-source other files or otherwise compensate. This is fastest of course -- only a small number of files is processed, and any variables or ad-hoc state you created in the session is still there for you to retry your scenarios.
  * **Create a new session:** For cases where dot-sourcing resets shared state or runs into issues with double-initialization, it may be safest just to start a new session using `import-devmodule` from another PowerShell terminal (usually the one from which you first executed `import-devmodule`). This launches a fresh session without the affects of any commands executed in your previous session.
* If you're making a change that will require an update to the module manifest (`.psd1` file) including adding or removing a source file, adding or removing a module dependency, or changing other aspects of the module manifest that affect its runtime behavior, you'll need to **rebuild the module and create a new session**.

This translates into the following commands:

* **Dot-source** files you've edited that are not new to the module and have simple initialization:

        . .\src\cmdlets\get-graphchilditem.ps1 # Run this in the existing session where you did your testing

* **Create a new session** from your existing built module if you didn't change anything about the module manifest (`.psd1` file), i.e. you haven't added or removed source files, added or removed dependencies, etc.:

        # Don't run this from your dev session, use a new terminal
        # or use the one where you originally ran import-devmodule
        .\build\import-devmodule.ps1

* **Rebuild your module** for all other cases or if you're not sure if your sessions reflect a valid state:

        # Don't run this from your dev session, use a new terminal
        # or use the one where you originally ran import-devmodule
        .\build\build-package.ps1
        .\build\publish-moduletodev.ps1
        .\build\import-devmodule.ps1

## Publish the module to a PowerShell repository
Use the command below to publish the package generated by the `build-package` command to a PowerShell Gallery compatible module repository:

```powershell
.\build\publish-modulepackage.ps1 [your-module-repo] [ repositoryKeyFile your-access-key-if-needed]
```

After you've published the module to a repository, you can use commands such as `install-module` targeted at that repository to install an AutoGraphPS module with your code changes from that repository.

## Clean build
To remove all artifacts generated by the build process such as files under `pkg`, downloaded dependencies, etc., run the following command

```powershell
.\build\clean-build.ps1
```

It is advisable to run this command prior to publishing the module or performing acceptance tests -- this ensures that you're testing your latest changes and that possibly hidden or removed dependencies are identified prior to module being published to a repository.

After you've executed this, you'll need to include the `-downloaddependencies` option `build-package` to rebuild the package:

```powershell
.\build\build-package -downloaddependencies
```

## Installing from source
If you'd like to install the module from source, either to test installation itself or to make use of changes (your own or other forks / branches of the project) on your own system, you can simply run the following command

```powershell
.\build\install-fromsource.ps1
```

Note that this script simply automates the sequence of a clean build, build, publish to a local developer repository, followed by installation from that repository. A faster way to achieve this result follows if you've already had at least one successful `build-package` execution:

```powershell
.\build\build-package.ps1 # skip if you haven't changed code since last build-package
.\build\publish-moduletodev.ps1
.\build\install-devmodule.ps1
```

## Advanced scenarios
The `publish-moduletodev`, `import-devmodule`, and `install-devmodule` scripts support parameters that allow you to obtain dependencies from a repository other than PowerShell Gallery. This may be required because your changes to AutoGraphPS are dependent on changes that you're making to a dependency (e.g. [`ScriptClass`](https://github.com/adamedx/scriptclass) that have not yet been accepted to that dependency and uploaded to PowerShell Gallery.

In this use case, you can clone the dependency, build it, and publish it to your own repository, whether a local file-system based repository or a hosted (NuGet) module repository at some remote URI. The repository must be registered via the `Register-PSRepository` cmdlet, and then the name under which it is registered supplied to `publish-moduletodev`, `import-devmodule`, or `install-devmodule`.

Without this type of feature, developers would need to manually provision dependencies for use in testing `AutoGraphPS`, or implement their own automation to compensate for the omission.

## Build script inventory

All of the build scripts used in this project are given below with their uses -- for more information, see the actual build scripts in this [directory](.) and review their supported options.

|   | Script                         | Purpose                                                                                        |
|---|--------------------------------|------------------------------------------------------------------------------------------------|
| 1 | [build-package.ps1](build-package.ps1)         | Builds the Powershell module package for AutoGraphPS that can be published to a repository     |
| 2 | [publish-moduletodev.ps1](publish-moduletodev.ps1)   | Copies a built module to a local repository along with its module dependencies                 |
| 3 | [import-devmodule.ps1](import-devmodule.ps1)      | Creates a new shell with your module imported -- does not require a recent build as long as the required module dependencies are avaialble from a previous execution of `publish-moduletodev.ps1`                                        |
| 4 | [publish-modulepackage.ps1](publish-modulepackage.ps1) | Publishes the module to a PowerShell Gallery package repository                                |
| 5 | [install-devmodule.ps1](install-devmodule.ps1)     | Installs the module published via `publish-moduletodev.ps1` to the system                 |
| 6 | [clean-build.ps1](clean-build.ps1)           | Deletes all artifacts generated by any of the build scripts                                    |
| 7 | [install-fromsource.ps1](install-fromsource.ps1)    | Installs the module by automating 6, 1, 2, and 5.                                              |
| 8 | [quickstart.ps1](quickstart.ps1)            | Starts a shell with AutoGraphPS imported with hints / and tips without installing to the system  |

