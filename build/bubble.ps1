# Copyright 2019, Adam Edwards
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

$__originalModulePath = $env:psmodulepath
$__bubbleStack = @()
$__BubbleCacheSourceName = 'PowerShellBubbleCache'
$__BubbleConfigFileName = 'BubbleFile'

set-alias bubble invoke-bubble
set-alias pop-bubble uninstall-bubble

function getBubblePath {
    join-path (gi .).fullname .bubble
}

function getBubbleConfigPath {
    join-path (gi .).fullname $__BubbleConfigFileName
}

function getModulePackageConfigPath {
    $packageConfigName = (gi .).name

    join-path (gi .).fullname "$($packageConfigName).nuspec"
}

function getAssemblyPackagesListFilePath {
    join-path (gi .).fullname "packages.config"
}

function getBubbleCachePath {
    join-path $env:localappdata PowerShellBubbleCache
}

function getExistingBubbleCache {
    try {
        get-packagesource $__BubbleCacheSourceName 2>$null
    } catch {
        $null
    }
}

function getBubbleCache {
    $existingCacheSource = getExistingBubbleCache

    if ( ! (isCacheValid $existingCacheSource) ) {
        remove-bubblecache
    }

    $cacheSource = createBubbleCacheIfNeeded
    $cacheSource.Name
}

function getDependencies {
    $packageConfigPath = getModulePackageConfigPath

    $configData = [Xml] (get-content $packageConfigPath)

    # Should throw exception if a node does not exist, i.e.
    # if the schema is invalid
    $configData.package.metadata.dependencies.dependency
}

function getAssemblyPackagesFromFile($assemblyListFilePath) {
    $packageData = [Xml] (get-content $assemblyListFilePath)

    # Should throw exception if a node does not exist, i.e.
    # if the schema is invalid
    $packageData.packages.package
}

function getAssemblyDependencies {
    $packageListPath = getAssemblyPackagesListFilePath
    getAssemblyPackagesFromFile $packageListPath
}

new-variable nugetSearchBaseUri -value 'https://api-v2v3search-1.nuget.org/query' -option readonly -force

# e.g. 'https://api-v2v3search-1.nuget.org/query?q=PackageId:myorg.myassembly+version:3.17.1'
new-variable nugetSearchTemplate -value "$($nugetSearchBaseUri)?prerelease=true&q=PackageId:{0}" -option readonly -force

function findPackage($bubbleConfig, $packageId, $version, $source = $null) {
    $sources = customObjectToHashTable $bubbleConfig.packagesources
    if ($sources.containskey($packageId)) {
        $packageSource = $sources[$packageId]
        write-verbose "Using source '$packageSource' for package id '$packageId' with version '$version'"
        $packageResult = try {
            $findArguments = @{name=$packageId;allowprereleaseversions=$true}
            if ($version -ne $null) {
                $findArguments['requiredversion'] = $version
            }
            write-verbose "Searching package source..."
            $result = find-package @findArguments -source $packageSource 2>$null
            $result
        } catch {
            throw $_
        }

        $bestPackage = $packageResult | select -last 1
        write-verbose "Found package '$packageId' "
        @{
            id = $packageId
            version = $bestPackage.version
            source = $packageSource
            packageFileName = $bestPackage.PackageFileName
        }
    } else {
        searchPackage $bubbleConfig $packageId $version $source
    }
}

function searchPackage($bubbleConfig, $packageId, $version, $source = $null) {
    write-verbose "Searching for package '$packageId'"

    $searchResult = $null
    if ( $source -eq $null ) {
        write-verbose "using nuget"
        $queryUri = ($nugetSearchTemplate -f $packageId)
        write-verbose "Querying with uri '$queryUri'"
        $searchResult = try {
            invoke-restmethod -uri $queryUri
        } catch {
            throw $_
        }
    } else {
        throw "PackageManagementSource is currently not supported"
    }

    if ( $searchResult.totalHits -eq 0 ) {
        write-verbose "No packages found for package '$packageId'"
        throw "No packages found for package '$packageId'"
    } else {
        write-verbose "Found $($searchResult.totalHits) packages"
    }

    write-verbose "Successfully queried for package"

    $bestPackage = if ($version -eq $null) {
        write-verbose 'Selecting package with highest version'
        $searchResult.data.versions | select -last 1

    } else {

        write-verbose "Selecting package with specific version '$version'"
        try {
            $searchResult.data.versions | where { $_.version -eq $version }
        } catch {
            write-error $_
        }
    }
    write-verbose "Found package with version '$($bestPackage.version)'"
    $packageMetadata = if ($bestPackage -ne $null) {
        $packageUri = $bestPackage | select -expandproperty '@id'
        write-verbose "Found a package, searching for details at uri '$packageUri'"
        try {
            invoke-restmethod -uri $packageUri
        } catch {
            throw $_
        }
    } else {
        write-verbose "Search for package yielded 0 results"
        $null
    }

    if ($packageMetadata -ne $null) {
        write-verbose "Found package details"
        @{
            id = $packageId
            version = $bestPackage.version
            downloadUri = $packageMetadata.packageContent
        }
    }
}

function savePackage($packageData, $localDestinationPath) {
    write-verbose "Request to save '$($packageData.Id) versio= $($packageData.version)' to '$localDestinationPath'"

    $packageUri = $null
    $packageName = if ($packageData.containskey('source')) {
        write-verbose "Using source package repository '$($packageData.source)'"
        $packageData.PackageFileName
    } else {
        write-verbose "Using source uri '$($packageData.downloadUri)' to '$localDestinationPath'"
        $packageUri = new-object 'System.uri' -argumentlist $packageData.downloadUri
        $uriPath = $packageUri.getcomponents([System.UriComponents]::Path, [System.UriFormat]::safeunescaped)
        $uripath -split '/' | select -last 1
    }

    $localPackagePath = $localDestinationPath, $packageName -join '/'
    if ( test-path $localPackagePath ) {
        write-verbose "Skipping download because '$localPackagePath' already exists"
    } elseif ($packageUri -ne $null) {
        write-verbose "Downloading '$($packageData.downloadUri)' to '$localPackagePath'"
        try {
            invoke-webrequest -uri $packageData.downloadUri -outfile $localPackagePath
        } catch {
            throw $_
        }
    } else {
        save-package -name $packageData.Id -source $packageData.source -requiredVersion $packagedata.version -literalpath (getBubbleCachePath) | out-null
    }

    write-verbose "Package id='$($packageData.id)', version='$($packageData.version)' successfully saved to '$localDestinationPath'"
}

function cachePackage($bubbleConfig, $packageId, $version) {
    $findArguments = @{name=$packageId;allowprereleaseversions=$true}
    if ($version -ne $null) {
        $findArguments['requiredversion'] = $version
    }

    $packageAndDependencies = try {
        write-verbose ("Searching for remote package id='{0}'" -f $packageId)
        findPackage $bubbleConfig $packageId $version
    } catch {
        write-verbose "Unable to find a remote package"
        $null
    }

    $localVersion = $version
    $remotePAckage = $null

    if ( $packageAndDependencies -ne $null ) {
        write-verbose "Found some packages"
        $remotePackage = $packageandDependencies
        $localVersion = $remotePackage.version
    }

    $localFindArguments = @{name=$packageId;allowprereleaseversions=$true}

    if ($localVersion -ne $null) {
        $localFindArguments['requiredversion'] = $localVersion
    }

    $localPackage = try {
        write-verbose ("Searching for local package id='{0}'" -f $packageId)
        find-package -source $__BubbleCacheSourceName @localFindArguments 2>$null
    } catch {
        write-verbose "Unable to find local package with required version"
        $null
    }

    if ( $remotePackage -eq $null -and $localPackage -eq $null ) {
        throw ("Unable to find a package for package id='{0}' version={1} in the remote repository or from a local cache" -f $packageId, $version)
    }

    if ( $localPackage -eq $null ) {
        savePackage $remotePackage (getBubbleCachePath)
    } else {
        write-verbose ("Found local package '{0}', version='{1}'" -f $localPackage.Name, $localPackage.version)
    }

    $packageAndDependencies
}

function isCacheValid($cacheSource) {
    if ($cacheSource -eq $null) {
        $false
    } elseif ($cacheSource.location -ne (getBubblePath)) {
        $false
    } elseif ($cacheSource.providername -ne 'PowerShellGet') {
        $false
    } elseif ($cacheSource.istrusted -eq $true) {
        $false
    } elseif ($cacheSource.isregistered -eq $false) {
        $false
    } else {
        $true
    }
}

function createBubbleCacheIfNeeded {
    write-verbose "Creating bubble cache only if needed"
    if ( ! (test-path -pathtype container (getBubbleCachePath)) ) {
        try {
            mkdir (getbubbleCachePath) | out-null
            write-verbose "Created directory $(getbubbleCachePath) because it did not exist"
        } catch {
            throw $_.Exception
        }
    }

    $cacheSource = getExistingBubbleCache

    if ( $null -eq $cacheSource ) {
        write-verbose "Bubble cache source '$__BubbleCacheSourceName'' not found"
        $cacheSource = Register-PackageSource $__BubbleCacheSourceName (getBubbleCachePath) -provider nuget
        write-verbose "Successfully created cache source '$__BubbleCacheSourceName'"
    }

    $cacheSource
}

function customObjectToHashTable($customObject) {
    if ( $customObject -isnot [HashTable] ) {
        $hashtable = @{}
        $hashTableProperties = $hashTable | get-member -membertype property
        $excluded = @{}
        $hashTableProperties | foreach { $excluded[$_.name] = $true }
        $customObject.psobject.properties | foreach {
            if ( $excluded[$_.name] -eq $null ) {
                $hashtable[$_.Name] = $_.value
            }
        }
        $hashtable
    } else {
        $customObject
    }
}

function get-bubbleconfig {
    $configData = @{}
    if (test-path (getBubbleConfigPath)) {
        $configObject = ( get-content -path (getBubbleConfigPath) ) | convertfrom-json
        $configData = customObjectToHashTable $configObject
    }
    $configData
}

function writeBubbleConfig($configData) {
    $jsonConfigData = ($configData | convertto-json)
    set-content -encoding utf8 -path (getBubbleConfigPath) -value $jsonConfigData
}

function set-bubbleconfig {
    param(
        [parameter(mandatory=$true)] [validateset("PackageSources")] $setting,
        [parameter(mandatory=$true)] $value
    )

    setBubbleConfig $setting $value
}

function remove-bubbleconfig {
    param(
        [parameter(mandatory=$true)] [validateset("PackageSources")] $setting
    )

    setBubbleConfig $setting $null
}

function setBubbleConfig($setting, $value) {
    $configData = get-bubbleconfig
    $dataChanged = $false

    if ($value -eq $null) {
        $configData.Remove($setting)
        $dataChanged = $true
    } else {
        if ( $setting -eq 'PackageSources' ) {
            if ( $value -isnot [HashTable] ) {
                throw "Specified value type of '$($value.gettype())' for setting 'PackageSource' was not of required type [HashTable]"
            }

            if (! $configData.containskey($setting)) {
                $configData[$setting] = @{}
                $dataChanged = $true
            }

            $packageSourcesData = customObjectToHashTable $configData[$setting]
            $configData[$setting] = $packageSourcesData

            $value.getenumerator() | foreach {
                $dataChanged = $packageSourcesData[$_.key] -ne $_.value
                if ( $_.value -ne $null ) {
                    $packageSourcesData[$_.key] = $_.value
                } else {
                    $packageSourcesData.Remove($_.key)
                }
            }
        } else {
            throw "Setting value '$setting' is not a valid setting"
        }
    }

    if ($dataChanged) {
        writeBubbleConfig $configdata
    }
}

function renameModulePackage {
    [cmdletbinding()]
    param ( $packageName, $packagesDirectory )

    $stateFile = join-path $packagesDirectory "$($packageName).json"

    if ( test-path $stateFile ) {
        write-verbose "Found existing relocation file '$stateFile'"
        $stateData = get-content $stateFile | convertfrom-json
        write-verbose "exiting rename"
        return $stateData
    } else {
        write-verbose "File '$statefile' not found"
    }

    $isValidPackage = $packageName -match '(?<installsubdir>[^.]+)\.(?<packageversion>.+)\.nupkg'

    if ( ! $isValidPackage ) {
        throw "Package file name '$packageName ' was not of the form '<package>.nupkg'"
    }

    $installSubdirectory = $matches['installSubdir']
    $packageVersion = $matches['packageversion']

    $installedLocation = join-path $packagesDirectory "$($installSubdirectory).$($packageVersion)"

    if ( test-path $installedLocation ) {
        write-verbose "package dir = '$installsubdirectory', version = '$packageversion', location = '$installedLocation'"
        $moduleManifestResults = (ls $installedLocation -r -filter *.psd1)

        $moduleName = $null
        $moduleVersion = $null

        if ( $moduleManifestResults -ne $null ) {
            $moduleManifestPath = $moduleManifestResults[0]
            $moduleManifest = test-modulemanifest $moduleManifestPath.FullName
            $moduleName = $moduleManifest.Name
            $moduleVersion = $moduleManifest.Version
        } else {
            $moduleManifestResults = (ls $installedLocation -r -filter *.psm1)
            $moduleName = $moduleManifestResults[0].Name
            $moduleVersion = ''
            write-verbose "No module manifest found, taking module name and version from package name '$moduleName'"
        }

        $moduleDirectory = join-path $packagesDirectory $moduleName
        $destination = join-path $moduleDirectory $moduleVersion

        if ( test-path $destination ) {
            try {
                rm -r -force $destination
            } catch {
                throw $_
            }
        }

        if ( ! (test-path $moduleDirectory) ) {
            write-verbose "Creating directory '$moduleDirectory'"
            mkdir $moduleDirectory | out-null
        }

        write-verbose "Moving '$installedLocation' to '$destination'"
        mv $installedLocation $destination

        $moveState = @{originalModuleInstalledLocation = $installedLocation;relocatedModuleLocation = $destination}
        $moveState | convertto-json | out-file -encoding utf8 $stateFile
    } else {
        write-verbose "Nothing to move because '$installedLocation does not exist'"
    }
}

function installPackage( $packageName, $source, $destination ) {
    write-verbose "Attempting to install '$packageName' from source '$source' to destination '$destination'"
    $verboseLevel = if ( $verbosepreference -eq 'SilentlyContinue' ) {
        'normal'
    } else {
        'detailed'
    }

    $installCommand = "nuget.exe install '$packageName' -source '$source' -outputdirectory '$destination' -verbosity $verboseLevel -prerelease"

    write-verbose "Executing command $installCommand"
    $result = invoke-expression $installCommand
    $commandResult = $lastexitcode
    if ( $lastexitcode -ne 0 ) {
        throw "Command failed with exit status '$commandResult'`n$($result)"
    }
    write-verbose "Successfully installed '$packageName'"
}

function installDependencies($dependencies, $isPowerShellModule) {
    $dependencies | foreach {
        write-verbose "Dependency: '$($_.id)'"
        $version = try {
            $_.version
        } catch {
            $null
        }

        try {
            cachePackage $bubbleConfig $_.id $version | out-null
        } catch {
            throw $_
        }

        $packageData = $null
        try {
            write-verbose "Installing package..."
            installPackage -packageName $_.id -source $cacheSource -destination $bubblePath
            if ($isPowerShellModule) {
                write-verbose "Package is a PowerShell module"
                write-verbose "Looking for package metadata for '$($_.id)'"
                $packageData = find-package -name $_.id -source powershellbubblecache -requiredversion $version
                renameModulePackage -packageName $packageData.packagefilename -packagesDirectory $bubblePath | out-null
            }
        } catch {
            throw $_
        }

        write-verbose "Processed package $($_.id)"
    }
}

function install-bubble {
    [cmdletbinding()]
    param()
    write-verbose "Install-Bubble cmdlet..."
    $modulePackageConfigPath = getModulePackageConfigPath
    if (! (test-path $modulePackageConfigPath)) {
        throw "Cannot install a new bubble because the file '$modulePackageConfigPath' does not exist. Execute the command from a directory that has package config .nuspec file"
    }

    $bubblePath = getBubblePath
    if (test-path $bubblePath) {
        throw "Cannot install a new bubble at path '$bubblePath' because it already exists -- use update-bubble to update it instead, or use uninstall-bubble to remove it and try again"
    }

    mkdir .bubble | out-null

    update-bubble
    write-verbose "Install-bubble completed for bubble at path '$bubblePath'"
}

function update-bubble {
    [cmdletbinding()]
    param(
        $packageConfigName = $null
    )

    write-verbose "Update-Bubble cmdlet..."

    $bubblePath = getBubblePath
    if (! (test-path $bubblePath)) {
        throw "Cannot update bubble at path '$bubblePath' because it does not exist -- create the bubble using install-bubble and try again"
    }

    $bubbleConfig = get-bubbleconfig

    $cacheSource = getBubbleCache

    $moduleDependencies = getDependencies
    $assemblyPackages = getAssemblyDependencies

    installDependencies $moduleDependencies $true
    installDependencies $assemblyPackages $false

@'
    $dependencies | foreach {
        write-verbose "Dependency: '$($_.id)'"
        $version = try {
            $_.version
        } catch {
            $null
        }

        try {
            cachePackage $bubbleConfig $_.id $version | out-null
        } catch {
            throw $_
        }

        $packageData = $null
        try {
            write-verbose "Looking for package '$($_.id)'"
            $packageData = find-package -name $_.id -source powershellbubblecache -requiredversion $version
            $isPowerShellModule = $false;
            $currentPackageId = $_.id
            $tags = -split $packageData.metadata['tags']
            for ($tagIndex = 0; $tagIndex -lt $tags.length; $tagIndex++) {
                if ( $tags[$tagIndex] -eq 'PSModule' ) {
                    $isPowerShellModule = $true
                    write-verbose "Package $currentPackageId is a PowerShell module"
                    break
                }
            }

            write-verbose "Installing package..."
            installPackage -packageName $_.id -source $cacheSource -destination $bubblePath
            if ($isPowerShellModule) {
                renameModulePackage -packageName $packageData.packagefilename -packagesDirectory $bubblePath | out-null
            } else {
                write-verbose "Package $currentPackageId is not a PowerShell module"
            }
        } catch {
            throw $_
        }

        write-verbose "Processed package $($_.id)"
    }
'@ | out-null
    write-verbose "Update-Bubble completed for bubble at path '$bubblePath'"
}

function uninstall-bubble {
}

function enter-bubble([switch] $nonisolated) {
    if (! (test-path env:__OriginalPSModulePath) ) {
        si env:__OriginalPSModulePath $env:PSModulePath
    }

    if ( ! $nonisolated.ispresent ) {
        si env:PSModulePath (getBubblePath)
    } else {
        si env:PSModulePath (getBubblePath, $env:__OriginalPSModulePath -join ';')
    }
}

function exit-bubble {
    si env:PSModulePath $env:__OriginalPSModulePath
    rm env:__OriginalPSModulePath
}

function join-bubble {
    enter-bubble -nonisolated
}

function invoke-bubble {
    param (
    [parameter(mandatory=$true)] $command
    )

    $scriptCommand = [ScriptBlock]::Create($command)
    enter-bubble

    $result = try {
        invoke-command -scriptblock $scriptCommand -argumentlist $args
    } finally {
        exit-bubble
    }

    $result
}

function remove-bubblecache {
}

