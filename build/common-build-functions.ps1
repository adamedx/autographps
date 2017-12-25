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

function Get-ModuleFromManifest {
    $basedirectory = get-item (split-path -parent $psscriptroot)
    $basepath = $basedirectory.fullname
    $moduleName = Get-ModuleName
    $moduleManifestPath = join-path $basepath "$moduleName.psd1"
    test-modulemanifest $moduleManifestPath
}

function Get-OutputDirectory {
    $basedirectory = get-item (split-path -parent $psscriptroot)
    $basepath = $basedirectory.fullname
    join-path $basepath 'pkg'
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
    } elseif (! $clean) {
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

    $module = Test-ModuleManifest $manifestPaths[0]

    if ( (get-psrepository $destinationRepositoryName 2>$null) -eq $null ) {
        throw "Unable to find destination repository '$destinationRepositoryName' -- supply the correct repository name or register one with register-psrepository"
    }

    $forceArgument = @{force=$force}
    publish-module -path $moduleSourceDirectory -repository $destinationRepositoryName -verbose @forceArgument
}
