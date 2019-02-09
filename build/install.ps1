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

[cmdletbinding()]
param([switch] $clean)

. "$psscriptroot/common-build-functions.ps1"

function InstallDependencies($clean) {
    validate-nugetpresent

    $appRoot = join-path $psscriptroot '..'
    $packagesDestination = join-path $appRoot lib

    if ( $clean -and (test-path $packagesDestination) ) {
        write-host -foregroundcolor cyan "Clean install specified -- deleting '$packagesDestination'"
        remove-item -r -force $packagesDestination
    }

    write-host "Installing dependencies to '$appRoot'"

    if ( ! (test-path $packagesDestination) ) {
        psmkdir $packagesDestination | out-null
    }

    $configFilePath = join-path $appRoot 'NuGet.Config'
    $nugetConfigFileArgument = if ( Test-Path $configFilePath ) {
        $configFileFullPath = (gi (join-path $appRoot 'NuGet.Config')).fullname
        Write-Warning "Using test NuGet config file '$configFileFullPath'..."
        "-configfile '$configFileFullPath'"
    } else {
        ''
    }
    $packagesConfigFile = join-path -path (join-path $psscriptroot ..) -child packages.config
    ls ./lib | out-host
    if ( ! ( test-path $packagesConfigFile ) ) {
        return
    }

    $restoreCommand = if ( $PSVersionTable.PSEdition -eq 'Desktop' ) {
        "& nuget restore '$packagesConfigFile' $nugetConfigFileArgument -packagesDirectory '$packagesDestination' -packagesavemode nuspec"
    } else {
        $psCorePackagesCSProj = New-DotNetCoreProjFromPackagesConfig $packagesConfigFile $packagesDestination
        "dotnet restore '$psCorePackagesCSProj' --packages '$packagesDestination' /verbosity:normal --no-cache"
    }
    write-host "Executing command: $restoreCommand"
    iex $restoreCommand | out-host

    $nuspecFile = get-childitem -path $approot -filter '*.nuspec' | select -expandproperty fullname

    if ( $nuspecFile -is [object[]] ) {
        throw "More than one nuspec file found in directory '$appRoot'"
    }

    Normalize-LibraryDirectory $packagesConfigFile $packagesDestination

    $allowedLibraryDirectories = get-allowedlibrarydirectoriesfromnuspec $nuspecFile

    # Remove nupkg files
    get-childitem -r $packagesDestination -filter '*.nupkg' | remove-item -erroraction ignore

    # Remove everything that is not listed as an allowed library directory in the nuspec
    $allowedFiles = $allowedLibraryDirectories | foreach {
        $allowedPath = join-path '.' $_
        get-childitem -path $allowedPath -filter *.dll
    }

    $allObjects = get-childitem ./lib -r
    $filesToRemove = $allObjects | where PSIsContainer -eq $false | where {
        ! $allowedFiles -or $allowedFiles.FullName -notcontains $_.FullName
    }

    $filesToRemove | remove-item

    $directoriesToRemove = $allObjects | where PSIsContainer -eq $true | where {
        $children = get-childitem -r $_.fullname | where PSISContainer -eq $false
        $null -eq $children
    }
    $directoriesToRemove | foreach { if ( test-path $_.fullname ) { $_ | remove-item -r -force } }
}

InstallDependencies $clean
