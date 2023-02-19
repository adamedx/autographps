# Copyright 2023, Adam Edwards
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

$PowerShellExecutable = if ( $PSVersionTable.PSEdition -eq 'Desktop' ) {
    'powershell.exe'
} else {
    'pwsh'
}

$OSPathSeparator = ';'
$IsNonWindowsPlatform = $false

$ToolsSettings = $null

try {
    if ( $PSVersionTable.PSEdition -eq 'Core' ) {
        if ( $PSVersionTable.Platform -ne 'Windows' -and $PSVersionTable.Platform -ne 'Win32NT' ) {
            $isNonWindowsPlatform = $true
            $OSPathSeparator = ':'
        }
    }
} catch {
}


function new-directory {
    param(
        [Parameter(mandatory=$true)]
        $Name,
        $Path,
        [switch] $Force
    )
    $fullPath = if ( $Path ) {
        join-path $Path $Name
    } else {
        $Name
    }
    $forceArgument = @{
        Force=$Force
    }

    new-item -ItemType Directory $fullPath @forceArgument
}

set-alias psmkdir new-directory -erroraction ignore

function Get-SourceRootDirectory {
    (get-item (split-path -parent $psscriptroot)).fullname
}

function Get-DevModuleDirectory {
    join-path (Get-SourceRootDirectory) '.devmodule'
}

function Get-GeneratedTestsDirectory {
    join-path (Get-SourceRootDirectory) '.test'
}

function Get-GeneratedDocsDirectory {
    join-path (Get-SourceRootDirectory) '.doc'
}

function Get-DevRepoDirectory {
    join-path (Get-SourceRootDirectory) '.psrepo'
}

function Get-PackageTempDirectory {
    join-path (Get-SourceRootDirectory) 'tmplib'
}

function Get-ProjectFilePath {
    $projectFileBase = join-path (get-SourceRootDirectory) (Get-ModuleName)
    "$($projectFileBase).csproj"
}

function Get-ModuleName {
    # For compatibility on case sensitive file systems such as Linux,
    # assume the module manifest has the correct casing rather than relying
    # on the name of the directory in which the source is cloned to have
    # the correct case.
    $moduleManifestFiles = get-childitem (split-path -parent $psscriptroot) -filter '*.psd1'
    if ( $moduleManifestFiles -is [object[]] ) {
        throw "More than one module manifest found in module directory: $moduleManifestFiles"
    }

    $moduleManifestFiles | select -expandproperty basename
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

function Validate-Prerequisites {
    param ([switch] $verifyInstalledLibraries)

    if ($verifyInstalledLibraries.ispresent) {
        $libPath = join-path (Get-SourceRootDirectory) lib

        # Assume if the lib path is there that it is correctly populted,
        # which may mean it has nothing at all (if there are actually
        # no dependencies)
        if ( ! ( test-path $libPath ) ) {
            $installScriptPath = join-path (get-sourcerootdirectory) 'build/install.ps1'
            throw "No .dll files found under directory '$libPath' or the directory does not exist -- please run '$installScriptPath' to install these dependencies and try again"
        }
    }
}

function Get-ToolsDirectory {
    join-path (split-path -parent $psscriptroot) bin
}

function Get-SettingsPath {
    join-path $psscriptroot ToolsSettings.json
}

function Get-ToolsSettings {
    $settingsPath = Get-SettingsPath
    if ( $script:ToolsSettings -eq $null ) {
        if ( test-path $settingsPath ) {
            write-verbose "Reading tools settings from path '$settingsPath'"
            $settings = get-content -raw (Get-SettingsPath) | convertfrom-json
            $script:ToolsSettings = @{}
            $settings | gm -membertype noteproperty | foreach {
                $script:ToolsSettings.Add($_.name, $settings.$($_.name))
            }
        } else {
            write-warning "Tools settings file '$settingsPath' not found -- default settings values will be used."
            $script:ToolsSettings = @{}
        }
    }
    $script:ToolsSettings
}

function Get-ToolsModulesDirectory {
    join-path (Get-ToolsDirectory) modules
}

function Get-LogsDirectory {
    join-path (split-path -parent $psscriptroot) .logs
}

function Get-DefaultDocsDirectory {
    join-path (split-path -parent $psscriptroot) 'docs/CommandReference'
}

function Get-DocsLogPath {
    join-path (Get-LogsDirectory) 'documentation-log.json'
}

function Get-DocModuleName {
    'platyPS'
}

function Get-DocModulePath {
    $docModuleName = Get-DocModuleName
    $modulesPath = Get-ToolsModulesDirectory
    get-childitem $modulesPath -r "$docModuleName.psd1"
}

function Install-DocTools {
    $settings = Get-ToolsSettings

    $docToolVersion = 'latest'
    $requiredVersion = if ( $settings['platyps'] ) {
        $version = $settings['platyps'].version
        if ( ! $version ) {
            throw "Invalid tools settings for 'platyps' -- no version was found. Correct or remove tools settings file and retry."
        }
        $docToolVersion = $version
        @{RequiredVersion=$version}
    } else {
        write-warning "No configuration found for 'platyps' in tools settings -- using latest version as a default"
        @{}
    }

    $modulesPath = Get-ToolsModulesDirectory
    $docModuleName = Get-DocModuleName
    $docModulePath = Get-DocModulePath

    if ( ! $docModulePath ) {
        write-verbose "Doc tool '$docModuleName' not found under path '$modulesPath', will download version '$docToolVersion'"
        remove-item -r -force (join-path $modulesPath $docModuleName) -erroraction ignore
        Save-Module $docModuleName -path $modulesPath -repository psgallery @requiredversion

        $moduleAtNewPath = Get-DocModulePath
        if ( ! $moduleAtNewPath ) {
            throw "Documentation module '$docModuleName' was installed, but the module manifest file '$docModuleName.psd1' could not be found under the directory $modulesPath"
        }
        $true
    } else {
        write-verbose "Doc tool was found at '$($docModulePath.fullname)', no update necessary"
        $false
    }
}

function Clean-Tools {
    $binPath = join-path $psscriptroot '../bin'

    if ( test-path $binPath ) {
        remove-item -r -force $binPath
    }
}

function Clean-TestDirectories {
    $generatedTestsLocation = Get-GeneratedTestsDirectory

    if (test-path $generatedTestsLocation) {
        $generatedTestsLocation | remove-item -r -force
    }
}

function Clean-DocDirectories {
    $generatedDocsLocation = Get-GeneratedDocsDirectory

    if (test-path $generatedDocsLocation) {
        $generatedDocsLocation | remove-item -r -force
    }
}

function Clean-PackageTempDirectory {
    $tmppkg = Get-PackageTempDirectory

    if ( test-path $tmppkg ) {
        remove-item -r -force $tmppkg
    }
}

function Clean-BuildDirectories {
    Clean-TestDirectories

    Clean-PackageTempDirectory

    $libPath = join-path $psscriptroot '../lib'
    if (test-path $libPath) {
        join-path $psscriptroot '../lib' | remove-item -r -force
    }

    $testResultsPath = join-path $psscriptroot '../test/results'
    if (test-path $testResultsPath) {
        remove-item -r -force $testResultsPath
    }

    $logsPath = Get-LogsDirectory

    if ( test-path $logsPath ) {
        remove-item -r -force $logsPath
    }

    $outputDirectory = Get-OutputDirectory

    if (test-path $outputDirectory) {
        $outputDirectory | remove-item -r -force
    }

    $devModuleLocation = Get-DevModuleDirectory

    if (test-path $devModuleLocation) {
        $devModuleLocation | remove-item -r -force
    }

    $devRepoLocation = Get-DevRepoDirectory

    if (test-path $devRepoLocation) {
        $devRepoLocation | remove-item -r -force
    }

    $generatedDocsLocation = Get-GeneratedDocsDirectory

    if (test-path $generatedDocsLocation) {
        $generatedDocsLocation | remove-item -r -force
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
        psmkdir $outputDirectory | out-null
    } elseif ($clean) {
        get-childitem $outputDirectory | remove-item -r -force
    }

    (gi $outputDirectory).fullname
}

function New-LogsDirectory {
    $logsPath = Get-LogsDirectory

    if ( test-path $logsPath ) {
        (gi  $logsPath ).fullname
    } else {
        (psmkdir $logsPath).fullname
    }
}

function build-module {
    [cmdletbinding()]
    param($module, $outputDirectory, [switch] $noclean, [switch] $includeInstalledLibraries)

    if ( ! (test-path $outputDirectory ) ) {
        throw "Specified output directory '$outputDirectory' does not exist"
    }

    $modulesDirectory = join-path $outputDirectory $moduleOutputSubdirectory

    if ( (test-path $modulesDirectory) -and ! $noclean.ispresent ) {
        remove-item -r -force $modulesDirectory
    }

    $thisModuleDirectory = join-path $modulesDirectory $module.name
    $targetDirectory = join-path $thisModuleDirectory $module.version.tostring()

    $verifyInstalledLibrariesArgument = @{verifyInstalledLibraries=$includeInstalledLibraries}
    validate-prerequisites @verifyInstalledLibrariesArgument

    psmkdir $targetDirectory | out-null

    $ignorableSegmentCount = ($module.modulebase.replace("`\", '/') -split '/').count
    $sourceFileList = @()
    $destinationFileList = @()
    $module.filelist | foreach {
        $normalizedFile = $_.replace("`\", '/')
        $segments = $normalizedFile -split '/'
        $relativeSegments = @()
        $ignorableSegmentCount..($segments.length - 1) | foreach {
            $relativeSegments += $segments[$_]
        }

        $relativePath = $relativeSegments -join '/'

        $sourceFileList += join-path $module.moduleBase $relativePath
        $destinationFileList += join-path $targetDirectory $relativePath
    }

    0..($sourceFileList.length - 1) | foreach {
         $parent = split-path -parent $destinationFileList[ $_ ]
         if ( ! (test-path $parent) ) {
            psmkdir $parent | out-null
         }

         $destinationName = split-path -leaf $destinationFileList[ $_ ]
         $syntaxOnlySourceName = split-path -leaf $sourceFileList[ $_ ]
         $sourceActualName = (get-childitem (split-path -parent $sourceFileList[ $_ ]) -filter $syntaxOnlySourceName).name

         if ( $destinationName -cne $sourceActualName ) {
             throw "The case-sensitive name of the file at source path '$($sourceFileList[$_])' is actually '$sourceActualName' and it does not match the case of the last element of destination path '$($destinationFileList[$_])' -- the case of the file names must match exactly in order to support environments with case-sensitive file systems. This can be corrected in the module manifest by specifying the case of the file exactly as it exists in the module source code directory"
         }

         copy-item $sourceFileList[ $_ ] $destinationFileList[ $_ ]
     }

    if ($includeInstalledLibraries.ispresent) {
        $libSource = join-path $module.moduleBase lib
        $libTarget = join-path $targetDirectory lib
        copy-item -r $libSource $libTarget
    }

    $targetDirectory
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

    $manifestPaths = get-childitem $moduleSourceDirectory -filter *.psd1
    if ( ! $manifestPaths -or (, $manifestPaths).length -lt 1 ) {
        throw "No '.psd1' PowerShell module manifest files found at path '$moduleSourceDirectory'"
    }

    if ( $manifestPaths -is [Object[]] ) {
        throw "More than one '.psd1' PowerShell module manifest files found at path '$moduleSourceDirectory'"
    }

    if ( (get-psrepository $destinationRepositoryName -erroraction ignore) -eq $null ) {
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
        $optionalArguments += " -nugetapikey $repositoryKey"
    }

    Invoke-CommandWithModulePath "publish-module -path '$moduleSourceDirectory' -repository '$destinationRepositoryName' -verbose $optionalArguments" $moduleRootDirectory
}

function Invoke-CommandWithModulePath($command, $modulePath) {
    # Note that the path must be augmented rather than replaced
    # in order for modules related to package management to be loade
    $commandScript = [Scriptblock]::Create("import-module -verbose PowerShellGet;si env:PSModulePath `"$env:PSModulePath$OSPathSeparator$modulePath`";$command")

    write-verbose "Executing command '$commandScript'"
    $result = if ( $PSVersionTable.PSEdition -ne 'Desktop' -and $PSVersionTable.Platform -eq 'Win32NT' ) {
        $result2 = $null
        (& $commandScript) | tee-object -variable result2 | out-host
        $result2
    } else {
        & $PowerShellExecutable -noninteractive -noprofile -command ($commandScript)
    }

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

    if ( ! $moduleData['NestedModules'] ) {
        return @()
    }

    # Only create the versioned modules -- publish-module
    # and test-modulemanifest can handled unversioned nested modules
    # without errors, it's the versioned ones that must be present
    # to work around the defect
    $moduleData.NestedModules | foreach {
        if ( $_ -is [HashTable] ) {
            $nestedModuleDirectory = join-path $referenceModuleRoot (join-path $_.ModuleName $_.ModuleVersion)
            psmkdir -force $nestedModuleDirectory | out-null
            $syntheticModuleManifest = join-path $nestedModuleDirectory "$($_.ModuleName).psd1"
            set-content $syntheticModuleManifest @"
# Synthetic module -- for publishing dependent module only
@{
ModuleVersion = '$($_.ModuleVersion)'
GUID = '$($_.Guid)'
}
"@
        }
    }
}

function Test-ModuleManifestWithModulePath( $manifestPath, $modulePath ) {
    # This method returns the module manifest in a format that is
    # semi-compatible with the output of Test-ModuleManifest.
    # It is preferable to use Test-ModuleManifest here, but it
    # gets tripped up by module paths for dependencies -- to avoid
    # this, we directly read the manifest and do minimal validation --
    # mostly we just want the fields of the file. This function *does*
    # validate the presence of the files -- if they are not present,
    # the method will throw an exception.

    # Read the module file -- it's just a hash table :)
    $moduleHash = get-content  $manifestPath | out-string | iex

    # Add renamed versions of some fields of the table for compatibility
    # with the names of fields returned by Test-ModuleManifest
    $moduleHash['ModuleBase'] = split-path -parent $manifestPath
    $moduleHash['Name'] = (gi $manifestPath).basename
    $moduleHash['Version'] = $moduleHash.ModuleVersion

    # File names expressd directly in the manifest are relative path names --
    # retrieve them as fill names the way they are returned by Test-ModuleManifest and reassign
    $moduleFilesValidatedFullPaths = $moduleHash['FileList'] | foreach { (gi $_).fullname }
    $moduleHash['FileList'] = $moduleFilesValidatedFullPaths

    # Nested modules need to have the fields 'Version' and 'Name' instead of
    # 'ModuleVersion' and 'ModuleName'
    $nestedModules = $moduleHash['NestedModules']

    if ( $nestedModules ) {
        $normalizedNestedModules = $moduleHash['NestedModules'] | foreach { $_['Version'] = $_.ModuleVersion; $_['Name'] = $_.ModuleName; $_ }
        $moduleHash['NestedModules'] = $normalizedNestedModules
    } else {
        $moduleHash['NestedModules'] = @()
    }

    # Return it as a PSCustomObject like Test-ModuleManifest
    [PSCustomObject] $moduleHash
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
        unregister-PSrepository $temporarySource | out-null
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
        Unregister-psrepository $temporarySource -erroraction silentlycontinue | out-null
        Register-psrepository $temporarySource -sourcelocation (Get-DefaultRepositoryFallbackUri) | out-null
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

    $module = Get-ModuleFromManifest $moduleManifestPath $moduleOutputRootDirectory
    $modulePath = join-path $moduleOutputRootDirectory $moduleName
    $modulePathVersioned = join-path $modulePath $module.Version

    write-verbose "Publishing module '$module' from build location '$modulePathVersioned'..."

    # Make sure the module is actually built
    if ( ! ( test-path $modulePathVersioned ) ) {
        throw "No module exists at $modulePath"
    }

    # Working around some strange behavior when there is only one
    # item in the directory and get-childitem gives back a non-array...
    $locations = @(@((Get-DevModuleDirectory), $customModuleLocation), @((Get-DevRepoDirectory), $customRepoLocation)) | foreach {
        $targetDirectory = if ( $_[1] -eq $null ) {
            $defaultLocation = $_[0]
            if ( ! (test-path $defaultLocation) ) {
                psmkdir $defaultLocation | out-null
            }
            $defaultLocation
        } else {
            $_[1]
        }

        $existingFiles = @()
        $existingFiles += (get-childitem $targetDirectory -filter *)

        $existingFiles | foreach {
            remove-item $_.fullname -r -force
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

    $temporaryPackageSource = get-temporarypackagerepository $module.Name $dependencySource

    $nestedModules | foreach {
        $nestedModuleVersion = $null
        $nestedModuleName = if ( $_ -isnot [Object[]] ) {
            $nestedModuleVersion = $_.Version
            $_.Name.tostring()
        } else {
            $_.tostring()
        }

        # Download this this dependency into the local module location.
        # This will enable importing the target module since its dependencies
        # will be in the same directory with it
        save-module -name $nestedModuleName -requiredversion $nestedModuleVersion -repository $dependencysource -path $devModuleLocation

        # Also download its package file to the ps repo location so that the directory can be used when
        # installing the package from the ps repo a repository.
        $savedPackages = save-package -name $nestedModuleName -requiredversion $nestedModuleVersion -source $temporaryPackageSource -path $PsRepoLocation -erroraction silentlycontinue
        if ( ! $? ) {
            write-verbose "First package save attempted failed, retrying..."
            # Sometimes save-package fails the first time, so try it again, and then it succeeds.
            # Don't ask.
            $savedPackages = save-package -name $nestedModuleName -requiredversion $nestedModuleVersion -source $temporaryPackageSource -path $PsRepoLocation
        }

        $savedPackage = $savedPackages | where name -eq $nestedModuleName

        $savedPackageFullName = "$($savedPackage.name).$($savedPackage.version).nupkg"
        $targetPackageFullName = "$nestedModuleName.$($savedPackage.version).nupkg"
        $namesDifferInCase = ! ( $savedPackageFullName -ceq $targetPackageFullName )

        if ( ! $namesDifferInCase ) {
            write-verbose "Saved package name and target package name have identical case: '$targetPackageFullName', no action needed on any platform"
        } else {
            write-verbose 'Saved package name and target package name differ in casing:'
            write-verbose "Saved package name '$savedPackageFullName'"
            write-verbose "Target package name: $targetPackageFullName'"
            if ( $isNonWindowsPlatform ) {
                write-verbose 'Package name casees differ and running on non-Windows platform, attempting rename of downloaded package to match official module name'
                $savedPackagePath = join-path $PsRepoLocation $savedPackageFullName
                $targetPackagePath = join-path $PsRepoLocation $targetPackageFullName
                write-verbose "Setting name of downloaded package at '$savedPackagePath' to '$targetPackagePath'"
                # A two-stage move is required because move-item apparently does a no-op when names
                # compare the same case insensitively.
                move-item $savedPackagePath "$targetPackagePath.tmp"
                move-item "$targetPackagePath.tmp" $targetPackagePath
            } else {
                write-verbose 'Running on Windows, so difference in case for package names is ok, no action will be taken'
            }
        }
    }

    unregister-packagesource -force $temporaryPackageSource | out-null

    $targetModuleDestination = join-path $devModuleLocation $moduleName
    if ( test-path $targetModuleDestination ) {
        remove-item -r -force $targetModuleDestination
    }

    # Copy the built module to the location where its dependencies already exist
    copy-item -r $modulePath $devModulelocation

    # Use the module that was built to publish, though it is *much* slower than using an
    # existing nuget package built via nuget.exe.
    $repository = get-temporarymodulepsrepository $moduleName $PsRepoLocation

    write-verbose "Publishing target module '$modulepath' from build output to publish location '$devModuleLocation'"
    try {
        publish-modulebuild $modulePathVersioned $repository | out-null
    } finally {
        unregister-psrepository $repository | out-null
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
        unregister-psrepository $localPSRepositoryName | out-null
    }

    register-psrepository $localPSRepositoryName $localPSRepositoryDirectory | out-null

    $localPSRepositoryName
}

function get-temporarypackagerepository($moduleName, $moduleDependencySource)  {
    write-verbose "Getting location of module dependency source '$moduleDependencySource'"

    $localPackageRepositoryName = "__$($moduleName)__package_dependency"
    $localPackageRepositoryLocation = (get-psrepository $moduleDependencySource).sourceLocation

    write-verbose "Module source '$moduleDependencySource' uses location '$localPackageRepositoryLocation'"

    $existingRepository = get-packagesource $localPackageRepositoryName -erroraction silentlycontinue

    if ( $existingRepository -ne $null ) {
        unregister-packagesource $localPackageRepositoryName | out-null
    }

    register-packagesource $localPackageRepositoryName $localPackageRepositoryLocation -providername nuget | out-null

    $localPackageRepositoryName
}

function InitDirectTestRun {
    $testDir = join-path (Get-SourceRootDirectory) test/CI
    $testInitPath = join-path $testDir PesterDirectRunInit.ps1
    if ( test-path $testInitPath ) {
        write-verbose "Found init script '$testInitPath', will execute it"
        $devDirectory = Get-DevModuleDirectory
        $newpsmodulepath = $devDirectory + $OSPathSeparator + (gi env:PSModulePath).value
        write-verbose "Updated PSModulePath environment variable to '$newpsmodulepath'"
        . $testInitPath
    } else {
        write-verbose "No init script found at '$testInitPath', skipping direct test run init"
    }
}

function Get-ModulePSMPath($moduleName) {
    $moduleParent = Get-DevModuleDirectory
    # Rather than use test-path which is subject to case-sensitive comparisons on Linux,
    # read the file names and do a normal PowerShell case-insensitive compare (i.e.
    # use '-eq' rather than 'ceq' on strings) so we can find the module name regardless
    # of how it is cased. This is ok because it is not possible to have two modules with
    # the same case-insensitive name but different case-insensitive name in module repo --
    # module names must be unique from a case-insensitive standpoint.
    $moduleDir = get-childItem $moduleParent | where name -eq $moduleName
    if ( ! $moduleDir ) {
        write-verbose "Cannot find a directory for '$moduleName' under '$moduleParent'"
        write-verbose "***Begin listing contents of directory '$moduleParent'"
        (get-childitem $moduleParent) | write-verbose
        write-verbose '***End listing contents'
        throw "Cannot load psm file for module '$moduleName' because path '$moduleName' does not exist under directory '$moduleParent'"
    }

    $moduleDirPath = $moduleDir.fullname

    write-verbose "Found '$moduleName' directory at '$moduleDirPath'"

    $psmFileName = $moduleName + '.psm1'

    $psmFiles = get-childitem -r $moduleDirPath -filter $psmFileName

    if ( ! $psmFiles ) {
        throw "Cannot find file '$psmFileName' under module directory '$moduleDirPath'"
    }

    # Now that we have found the module via a query of the file system,
    # we can get the name according to what the query returned from the
    # the file system -- now callers can safely access the file on either
    # Linux or Windows because the case will match the file system.
    $targetPsmFile = $psmFiles[0].fullname

    write-verbose "Found psm1 file for module '$moduleName' at '$targetPsmFile'"

    $targetPsmFile
}
