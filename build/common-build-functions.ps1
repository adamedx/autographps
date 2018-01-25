# Copyright 2017, Adam Edwards
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set-strictmode -version 2
$erroractionpreference = 'stop'

$moduleOutputSubdirectory = 'modules'

function Get-SourceRootDirectory {
    (get-item (split-path -parent $psscriptroot)).fullname
}

function Get-ModuleName {
    (get-item (split-path -parent $psscriptroot)).name
}

function Get-ModuleManifestPath {
    $basedirectory = get-item (split-path -parent $psscriptroot)
    $basepath = $basedirectory.fullname
    $moduleName = Get-ModuleName
    join-path $basepath "$moduleName.psd1"
}

function Get-ModuleFromManifest {
    $moduleManifestPath = Get-ModuleManifestPath
    test-modulemanifestsafe $moduleManifestPath -verbose
}

function Get-OutputDirectory {
    $basedirectory = get-item (split-path -parent $psscriptroot)
    $basepath = $basedirectory.fullname
    join-path $basepath 'pkg'
}

function Get-ModuleOutputRootDirectory {
    join-path (Get-OutputDirectory) $moduleOutputSubdirectory
}

function Get-ModuleOutputDirectory {
    $module = Get-ModuleFromManifest
    join-path (Get-OutputDirectory) "$moduleOutputSubdirectory/$($module.name)/$($module.version)"
}

function Validate-Nugetpresent {
    get-command nuget | out-null

    if (! $?) {
        throw "Nuget is not installed. Please visit https://nuget.org to install, then restart PowerShell and try again."
    }
}

function Validate-Prerequisites {
    param ([switch] $verifyInstalledLibraries)

    validate-nugetpresent

     if ($verifyInstalledLibraries.ispresent) {
        $libPath = join-path (Get-SourceRootDirectory) lib

        $libFilesExist = if ( ! ( test-path $libPath ) ) {
            $false
        } else {
            (ls -r $libPath -filter *.dll) -ne $null
        }

        if (! $libFilesExist ) {
            $installScriptPath = join-path (get-sourcerootdirectory) 'build\install.ps1'
            throw "No .dll files found under directory '$libPath' or the directory does not exist -- please run '$installScriptPath' to install these dependencies and try again"
        }
    }
}

function Clean-BuildDirectories {
    $libPath =     join-path $psscriptroot '../lib'
    if (test-path $libPath) {
        join-path $psscriptroot '../lib' | rm -r -force
    }

    $outputDirectory = Get-OutputDirectory

    if (test-path $outputDirectory) {
        $outputDirectory | rm -r -force
    }
}

function New-ModuleOutputDirectory {
    [cmdletbinding()]
    param($targetDirectory = $null, [boolean] $clean)

    $outputDirectory = if ( $targetDirectory -ne $null ) {
        $targetDirectory
    } else {
        Get-OutputDirectory
    }

    if ( ! (test-path $outputDirectory) ) {
        mkdir $outputDirectory | out-null
    } elseif ($clean) {
        ls $outputDirectory | rm -r -force
    }

    (gi $outputDirectory).fullname
}

function build-module {
    [cmdletbinding()]
    param($module, $outputDirectory, [switch] $noclean, [switch] $includeInstalledLibraries)

    if ( ! (test-path $outputDirectory ) ) {
        throw "Specified output directory '$outputDirectory' does not exist"
    }

    $modulesDirectory = join-path $outputDirectory $moduleOutputSubdirectory

    if ( (test-path $modulesDirectory) -and ! $noclean.ispresent ) {
        rm -r -force $modulesDirectory
    }

    $thisModuleDirectory = join-path $modulesDirectory $module.name
    $targetDirectory = join-path $thisModuleDirectory $module.version.tostring()

    $verifyInstalledLibrariesArgument = @{verifyInstalledLibraries=$includeInstalledLibraries}
    validate-prerequisites @verifyInstalledLibrariesArgument

    # Work around a defect in test-modulemanifest by generating
    # placeholder manifest files for dependencies. This is necessary
    # to enable the module to be publishable later.
    Generate-SyntheticVersionedNestedModules (Get-ModuleManifestPath)

    mkdir $targetDirectory | out-null

    $ignorableSegmentCount = ($module.modulebase -split '\\').count
    $sourceFileList = @()
    $destinationFileList = @()
    $module.filelist | foreach {
        $segments = $_ -split '\\'
        $relativeSegments = @()
        $ignorableSegmentCount..($segments.length - 1) | foreach {
            $relativeSegments += $segments[$_]
        }

        $relativePath = $relativeSegments -join '\'

        $sourceFileList += join-path $module.moduleBase $relativePath
        $destinationFileList += join-path $targetDirectory $relativePath
    }

     0..($sourceFileList.length - 1) | foreach {
        $parent = split-path -parent $destinationFileList[ $_ ]
        if ( ! (test-path $parent) ) {
            mkdir $parent | out-null
        }

        cp $sourceFileList[ $_ ] $destinationFileList[ $_ ]
     }

    if ($includeInstalledLibraries.ispresent) {
        $libSource = join-path $module.moduleBase lib
        $libTarget = join-path $targetDirectory lib
        cp -r $libSource $libTarget

        $copiedLibs = ls -r $libTarget -filter *.dll

        if ($copiedLibs.length -lt 1) {
            throw "No libraries copied from '$libSource' to '$libTarget'"
        }
    }

    $targetDirectory
}

function build-nugetpackage {
    [cmdletbinding()]
    param(
        $module,
        $outputDirectory,
        [switch] $includeInstalledLibraries
    )

    if( !( test-path $outputDirectory) ) {
        throw "Specified output path '$outputDirectory' does not exist"
    }

    $nugetManifest = join-path $module.modulebase "$($module.name).nuspec"

    write-host "Using .nuspec file '$nugetManifest'..."

    $packageOutputDirectory = join-path $outputDirectory 'nuget'

    if ( ! (test-path $packageOutputDirectory) ) {
        mkdir $packageOutputDirectory | out-null
    } else {
        ls -r $packageOutputDirectory *.nupkg | rm
    }

    $verifyInstalledLibrariesArgument = @{verifyInstalledLibraries=$includeInstalledLibraries}
    validate-prerequisites @verifyInstalledLibrariesArgument

    write-host "Building nuget package from manifest '$nugetManifest'..."
    write-host "Output directory = '$packageOutputDirectory'..."

    $nugetbuildcmd = "& nuget pack '$nugetManifest' -outputdirectory '$packageOutputdirectory' -nopackageanalysis -version '$($module.version)'"
    write-host "Executing command: ", $nugetbuildcmd

    iex $nugetbuildcmd
    $buildResult = $lastexitcode

    if ( $buildResult -ne 0 ) {
        write-host -f red "Build failed with status code $buildResult."
        throw "Command `"$nugetbuildcmd`" failed with exit status $buildResult"
    }

    $packagePath = ((ls $packageOutputdirectory -filter *.nupkg) | select -first 1).fullname
    $packageName = split-path -leaf $packagePath

    $packageVersion = $packageName.substring($module.name.length + 1, $packageName.length - ($module.name.length + ".nupkg".length + 1))

    if ( $packageVersion -ne $module.version ) {
        throw "Generated package version '$packageVersion' does not match module version '$($module.version)' for package '$($module.name)'"
    }

    $packagePath
}

function publish-modulebuild {
    [cmdletbinding()]
    param(
        $moduleSourceDirectory = $null,
        $destinationRepositoryName = $null,
        [switch] $force)

    $manifestPaths = ls $moduleSourceDirectory -filter *.psd1
    if ( $manifestPaths.length -lt 1 ) {
        throw "No '.psd1' PowerShell module manifest files found at path '$moduleSourceDirectory'"
    }

    if ( $manifestPaths -is [Object[]] ) {
        $manifestPaths | fl
        throw "More than one '.psd1' PowerShell module manifest files found at path '$moduleSourceDirectory'"
    }

    $module = Test-ModuleManifestSafe $manifestPaths[0].fullname

    if ( (get-psrepository $destinationRepositoryName 2>$null) -eq $null ) {
        throw "Unable to find destination repository '$destinationRepositoryName' -- supply the correct repository name or register one with register-psrepository"
    }

    $augmentedPath = (Get-ModuleOutputRootDirectory) + ';' + $env:psmodulepath

    # Build a script block for execution in another process that
    # alters the psmodulepath environment variable so that
    # the synthetic modules are picked up by publish-module
    $publishModuleScript = [ScriptBlock]::Create("si env:psmodulepath '$augmentedPath';publish-module -path '$moduleSourceDirectory' -repository '$destinationRepositoryName' -verbose -force")

    # Run a separate powershell process to publish the module and
    # avoid polluting this process's environment variables
    powershell -noprofile -noninteractive -command ($publishModuleScript)
}

function Get-ModuleFromManifestSafe ( $manifestPath ) {
    # Load the module contents and deserialize it by evaluating
    # it (module files  are just hash tables expressed as PowerShell script)
    $moduleContentLines = get-content $manifestPath
    $moduleContentLines | out-string | iex
}

function Generate-SyntheticVersionedNestedModules($manifestPath) {
    $moduleData = Get-ModuleFromManifestSafe $manifestPath

    # Only create the versioned modules -- publish-module
    # and test-modulemanifest can handled unversioned nested modules
    # without errors, its the versioned ones that must be present
    # to work around the defect
    $moduleData.NestedModules | foreach {
        if ( $_ -is [HashTable] ) {
            $nestedModuleDirectory = join-path (Get-ModuleOutputRootDirectory) (join-path $_.ModuleName $_.ModuleVersion)
            mkdir -force $nestedModuleDirectory | out-null
            $syntheticModuleManifest = join-path $nestedModuleDirectory "$($_.ModuleName).psd1"
            set-content $syntheticModuleManifest @'
# Synthetic module -- for publishing dependent module only
@{
ModuleVersion = '0.11.53'
GUID = '9b0f5599-0498-459c-9a47-125787b1af19'
}
'@
        }
    }
}

# Function to work around known defect
# in the Test-ModuleManifest cmdlet
function Test-ModuleManifestSafe( $manifestPath ) {
    # For nestmodules, there is a defect in Test-ModuleManifest
    # where if instead of specifying a module as a versionless string
    # a hashtable is specified, Test-ModuleManifest will fail unless
    # it can find that actual module on the system with the version
    # specified in the hash table.

    # To work around this issue, we'll replace the hashtable with
    # a versionless string module name

    $moduleData = Get-ModuleFromManifestSafe $manifestPath

    $originalModulePath = (gi $manifestPath).fullname
    $originalmoduleName = ((split-path -leaf $manifestPath) -split '.', 0, 'simplematch')[0]
    $originalNestedModules = $moduleData.NestedModules
    $originalPrivateData = $moduleData.PrivateData

    # Remember just the module names from nested module hashes
    $moduleData.NestedModules = $originalNestedModules | foreach {
        if ( $_ -is [HashTable] ) {
            $_.ModuleName
        } else {
            $_
        }
    }

    # In order to pass this data to new-modulemanifest, it is
    # actually embedded within another member, so move it
    # up a level so new-modulemanifest does the right thing
    $moduleData.PrivateData = $moduleData.PrivateData.PSData

    # Now create a new temporary one from the augmented original,
    # and use splatting to pass the members since the command's
    # parameter names map 1-1 with the file format
    $filteredManifestPath = $manifestPath + ".tmp.psd1"
    new-modulemanifest $filteredManifestPath @moduleData

    $filteredManifest = Test-ModuleManifest $filteredManifestPath -verbose

    rm $filteredManifestPath

    # Return the filtered manifest -- it is missing accurate
    # Representations of nestedmodules and PrivateData, but
    # these are not currently used in the build process,
    # and we can always return the original values in a separate
    # object in the future if they are needed
#    $filteredManifest

    $safeManifest = @{}

    $filteredManifest | gm -membertype Properties | foreach {
        $safeManifest[$_.name] = $filteredManifest | select -expandproperty $_.name
    }

    $safeManifest.NestedModules = $originalNestedModules
    $safeManifest.PrivateData = $originalPrivateData
    $safeManifest['Path'] = $originalModulePath
    $safeManifest['Name'] = $originalModuleName

    $safeManifest
}

