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

param([switch] $clean)

. "$psscriptroot/common-build-functions.ps1"

function InstallDependencies($clean) {
    validate-nugetpresent

    $appRoot = join-path $psscriptroot '..'
    $packagesDestination = join-path $appRoot lib

    if ( $clean -and (test-path $packagesDestination) ) {
        write-host -foregroundcolor cyan "Clean install specified -- deleting '$packagesDestination'"
        rm -r -force $packagesDestination
    }

    write-host "Installing dependencies to '$appRoot'"

    if ( ! (test-path $packagesDestination) ) {
        mkdir $packagesDestination | out-null
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
    iex "& nuget restore '$packagesConfigFile' $nugetConfigFileArgument -packagesDirectory '$packagesDestination'" | out-host

    # Rename any powershell modules so they can be imported from the containing folder
    ls $packagesDestination -r '*.psd1' | foreach {
        $source = $_.directory.fullname
        $destination = (join-path (split-path -parent $_.directory.fullname) $_.basename)
        if ( ! (test-path $destination) ) {
            write-host -foregroundcolor cyan "Moving '$source' to '$destination'"
            mv $source $destination
            mkdir $source | out-null
        } else {
            write-host "Skipping move of '$source' to '$destination' because it already exists"
        }
    }
}

InstallDependencies $clean
