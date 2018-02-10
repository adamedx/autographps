# Copyright 2018, Adam Edwards
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

function Get-DevModuleDirectory {
    join-path (Get-SourceRootDirectory) '.devmodule'
}

function Get-DevRepoDirectory {
    join-path (Get-SourceRootDirectory) '.psrepo'
}

function Get-ModuleName {
    (get-item (split-path -parent $psscriptroot)).name
}

function Get-ModuleNameFromManifestPath($manifestPath) {
    ((split-path -leaf $manifestPath) -split '.', 0, 'simplematch')[0]
}

function Get-ModuleManifestPath {
    $basedirectory = get-item (split-path -parent $psscriptroot)
    $basepath = $basedirectory.fullname
    $moduleName = Get-ModuleName
    join-path $basepath "$moduleName.psd1"
}

function Get-ModuleFromManifest($moduleManifestPath, $moduleReferencePath) {
    # Work around a defect in test-modulemanifest by generating
    # placeholder manifest files for dependencies. This is necessary
    # to enable the module to be publishable later.
    Test-ModuleManifestWithModulePath $moduleManifestPath $moduleReferencePath
}

function Get-OutputDirectory {
    $basedirectory = get-item (split-path -parent $psscriptroot)
    $basepath = $basedirectory.fullname
    join-path $basepath 'pkg'
}

function Get-ModuleOutputRootDirectory {
    join-path (Get-OutputDirectory) $moduleOutputSubdirectory
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
    $libPath = join-path $psscriptroot '../lib'
    if (test-path $libPath) {
        join-path $psscriptroot '../lib' | rm -r -force
    }

    $outputDirectory = Get-OutputDirectory

    if (test-path $outputDirectory) {
        $outputDirectory | rm -r -force
    }

    $devModuleLocation = Get-DevModuleDirectory

    if (test-path $devModuleLocation) {
        $devModuleLocation | rm -r -force
    }

    $devRepoLocation = Get-DevRepoDirectory

    if (test-path $devRepoLocation) {
        $devRepoLocation | rm -r -force
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

function Get-RepositoryKeyFromFile($path) {
    $fileData = get-content $path
    $keyContent = if ( $fileData -is [string] ) {
        $fileData
    } else {
        $fileData[0]
    }

    $keyContent.trim()
}


function publish-modulebuild {
    [cmdletbinding()]
    param(
        $moduleSourceDirectory = $null,
        $destinationRepositoryName = $null,
        $repositoryKey = $null,
        [switch] $force)

    $manifestPaths = ls $moduleSourceDirectory -filter *.psd1
    if ( $manifestPaths.length -lt 1 ) {
        throw "No '.psd1' PowerShell module manifest files found at path '$moduleSourceDirectory'"
    }

    if ( $manifestPaths -is [Object[]] ) {
        $manifestPaths | fl
        throw "More than one '.psd1' PowerShell module manifest files found at path '$moduleSourceDirectory'"
    }

    if ( (get-psrepository $destinationRepositoryName 2>$null) -eq $null ) {
        throw "Unable to find destination repository '$destinationRepositoryName' -- supply the correct repository name or register one with register-psrepository"
    }

    $moduleRootDirectory = split-path -parent (split-path -parent $moduleSourceDirectory)
    $targetModuleManifestPath = $manifestPaths[0].fullname

    Generate-ReferenceModules $targetModuleManifestPath $moduleRootDirectory

    $optionalArguments = ''

    if ( $force ) {
        $optionalArguments += '-force'
        }

    if ( $repositoryKey -ne $null ) {
        $optionalArguments += " -nugetapikey = $repositoryKey"
    }

    Invoke-CommandWithModulePath "publish-module -path '$moduleSourceDirectory' -repository '$destinationRepositoryName' -verbose $optionalArguments" $moduleRootDirectory
}

function Invoke-CommandWithModulePath($command, $modulePath) {

    # Note that the path must be augmented rather than replaced
    # in order for modules related to package management to be loade
    $commandScript = [Scriptblock]::Create("si env:psmodulepath `"`$env:psmodulepath;$modulePath`";$command")

    write-verbose "Executing command '$commandScript'"
    $result = powershell -noprofile -command ($commandScript)

    # Use of the powershell command with a script block may not result in an exception
    # when the script block throws an exception. However, $? is reliably set to a failure code in this case, so we check for that
    # and use the captured stderr redirected to stdout and throw it
    if ( ! $? ) {
        throw "Failed to execute publishing command '$command' using module path '$modulePath' with error information '$result'"
    }

    $result
}

function Get-ModuleMetadataFromManifest ( $manifestPath ) {
    # Load the module contents and deserialize it by evaluating
    # it (module files  are just hash tables expressed as PowerShell script)
    $moduleContentLines = get-content $manifestPath
    $moduleData = $moduleContentLines | out-string | iex
    $moduleData['Name'] = get-modulenamefrommanifestpath $manifestPath
    $moduledata
}

# Work around a defect in test-modulemanifest by generating
# placeholder manifest files for dependencies. This is necessary
# to enable the module to be publishable later.
function Generate-ReferenceModules($manifestPath, $referenceModuleRoot) {
    $moduleData = Get-ModuleMetadataFromManifest $manifestPath

    # Only create the versioned modules -- publish-module
    # and test-modulemanifest can handled unversioned nested modules
    # without errors, it's the versioned ones that must be present
    # to work around the defect
    $moduleData.NestedModules | foreach {
        if ( $_ -is [HashTable] ) {
            $nestedModuleDirectory = join-path $referenceModuleRoot (join-path $_.ModuleName $_.ModuleVersion)
            mkdir -force $nestedModuleDirectory | out-null
            $syntheticModuleManifest = join-path $nestedModuleDirectory "$($_.ModuleName).psd1"
            set-content $syntheticModuleManifest @"
# Synthetic module -- for publishing dependent module only
@{
ModuleVersion = '$($_.ModuleVersion)'
GUID = '$($_.GUID)'
}
"@
        }
    }
}

function Test-ModuleManifestWithModulePath( $manifestPath, $modulePath ) {
    Invoke-CommandWithModulePath "test-modulemanifest '$manifestPath' -verbose" $modulePath
}

function Get-DefaultPSModuleSourceName {
    'PSGallery'
}

function Get-DefaultRepositoryFallbackUri {
    'https://www.powershellgallery.com/api/v2/'
}

function Get-TemporaryPSModuleSourceName {
    ("__PSGallery_{0}__" -f (Get-ModuleName) )
}

function Clear-TemporaryPSModuleSources {
    $temporarySource = Get-TemporaryPSModuleSourceName
    if ( ( Get-PSRepository $temporarySource -erroraction silentlycontinue ) -ne $null ) {
        unregister-PSrepository $temporarySource
    }
}

function Get-DefaultPSModuleSource($noRegister = $false) {
    $defaultSourceName = Get-DefaultPSModuleSourceName

    write-verbose "Checking for default PS Repository source '$defaultSourceName'..."
    $defaultPSGetSource = get-psrepository $defaultSourceName -erroraction silentlycontinue

    $defaultSource = if ( $defaultPSGetSource -ne $null ) {
        write-verbose "Found default repository source '$defaultSourceName', will use it"
        $defaultSourceName
    } elseif (! $noRegister ) {
        $temporarySource = Get-TemporaryPSModuleSourceName
        $sourceUri = Get-DefaultRepositoryFallbackUri
        write-verbose "PS repository source '$defaultPSGetSource' not found, will create new source"
        write-verbose "Creating '$temporarySource' with uri '$sourceUri'"
        Unregister-psrepository $temporarySource -erroraction silentlycontinue
        Register-psrepository $temporarySource -sourcelocation (Get-DefaultRepositoryFallbackUri)
        $temporarySource
    } else {
        write-verbose "Default module repository '$defaultSourceName' does not exist and caller did not specifed not to create it, caller must handle creating it"
    }

    $defaultSource
}

function publish-modulelocal {
    [cmdletbinding()]
    param ( $customSource = $null, $customModuleLocation = $null, $customRepoLocation = $null )

    write-verbose "Publishing module to local destination with custom module source '$customSource' and custom output location '$customModuleLocation'"
    $dependencySource = if ( $customSource -eq $null ) {
        Get-DefaultPSModuleSource
    } else {
        $customSource
    }

    $moduleName = Get-ModuleName
    $moduleManifestPath = Get-ModuleManifestPath
    $moduleOutputRootDirectory = Get-ModuleOutputRootDirectory

    Generate-ReferenceModules $moduleManifestPath $moduleOutputRootDirectory

    $module = Get-ModuleFromManifest $moduleManifestPath $moduleOutputRootDirectory
    $modulePath = join-path $moduleOutputRootDirectory $moduleName
    $modulePathVersioned = join-path $modulePath $module.Version

    write-verbose "Publishing module '$module' from build location '$modulePathVersioned'..."

    # Make sure the module is actually built
    if ( ! ( test-path $modulePathVersioned ) ) {
        throw "No module exists at $modulePath"
    }

    # Working around some strange behavior when there is only one
    # item in the directory and ls gives back a non-array...
    $locations = @(@((Get-DevModuleDirectory), $customModuleLocation), @((Get-DevRepoDirectory), $customRepoLocation)) | foreach {
        $targetDirectory = if ( $_[1] -eq $null ) {
            $defaultLocation = $_[0]
            if ( ! (test-path $defaultLocation) ) {
                mkdir $defaultLocation | out-null
            }
            $defaultLocation
        } else {
            $_[1]
        }

        $existingFiles = @()
        $existingFiles += (ls $targetDirectory -filter *)

        $existingFiles | foreach {
            rm $_.fullname -r -force
        }
        $targetDirectory
    }

    $devModuleLocation = $locations[0]
    $PsRepoLocation = $locations[1]

    write-verbose "Using location '$devModuleLocation' as the output location for modules"
    write-verbose "Using location '$PsRepoLocation' as the local package destination repository for module packages"
    write-verbose "Using PS Repository '$dependencySource' as the source for package dependencies"

    # Working around more strange behaviors when dealing with more than
    # one item in the collection
    $nestedModuleCount = 0
    $nestedModules = if ( $module.nestedModules -ne $null ) {
        $nestedModuleCount = if ( $module.nestedModules -is [object[]] ) {
            $module.nestedModules.length
        } else {
            1
        }
        $module.nestedModules
    } else {
        @()
    }

    write-verbose "Found $nestedModuleCount module dependencies from module manifest"

    $nestedModules | foreach {
        $nestedModuleVersion = $null
        $nestedModuleName = if ( $_ -isnot [Object[]] ) {
            $nestedModuleVersion = $_.Version
            $_.Name.tostring()
        } else {
            $_.tostring()
        }

        # Download the module -- and its dependencies into the local module location
        save-module -name $nestedModuleName -requiredversion $nestedModuleVersion -repository $dependencysource -path $devModuleLocation
    }

    $targetModuleDestination = join-path $devModuleLocation $moduleName
    if ( test-path $targetModuleDestination ) {
        rm -r -force $targetModuleDestination
    }

    # Copy the built module to the location where its dependencies already exist
    cp -r $modulePath $devModulelocation

    $modulePackagePath = join-path (Get-OutputDirectory) nuget
    $modulePackage = ls $modulePackagePath -filter "$moduleName.*.nupkg"

    # Try to use an existing nuget package produced by the build -- if it exists
    if ( $modulePackagePath -ne $null -and $modulePackagePath.length -gt 0 ) {
        write-verbose "Copying target module '$modulepath' from build output to publish location '$devModuleLocation'"
        cp $modulePackage.fullname $PsRepoLocation
    } else {
        # Fall back to just using the module that was built -- this is
        # *much* slower than using an existing nuget package
        $repository = get-temporarymodulepsrepository $moduleName $PsRepoLocation
        write-verbose "Publishing target module '$modulepath' from build output to publish location '$devModuleLocation'"
        try {
            publish-modulebuild $modulePathVersioned $repository
        } finally {
            unregister-psrepository $repository
        }
    }

    [PSCustomObject]@{ImportableModuleDirectory=$devModuleLocation;ModulePackageRepositoryDirectory=$PsRepoLocation}
}

function get-temporarymodulepsrepository($moduleName, $repositoryPath)  {

    $localPSRepositoryName = "__$($moduleName)__localdev"
    $localPSRepositoryDirectory = $repositoryPath

    if ( ! ( test-path $localPSRepositoryDirectory ) ) {
        throw "Directory '$localPSRepositoryDirectory' does not exist"
    }

    $existingRepository = get-psrepository $localPSRepositoryName -erroraction silentlycontinue

    if ( $existingRepository -ne $null ) {
        unregister-psrepository $localPSRepositoryName
    }

    register-psrepository $localPSRepositoryName $localPSRepositoryDirectory

    $localPSRepositoryName
}
