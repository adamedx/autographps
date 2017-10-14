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

function ValidateNugetPresent {
    get-command nuget | out-null

    if (! $?) {
        throw "Nuget is not installed. Please visit https://nuget.org to install, then restart PowerShell and try again."
    }
}

function InstallDependencies {
    ValidateNugetPresent
    $appRoot = join-path $psscriptroot '..'
    $packagesDestination = join-path $appRoot lib
    $nugetConfigFileArgument = if ( Test-Path $appRoot ) {
        $configFilePath = (gi (join-path $appRoot 'NuGet.Config')).fullname
        Write-Warning "Using test NuGet config file '$configFilePath'..."
        "-configfile '$configFilePath'"
    } else {
        ''
    }
    $packagesConfigFile = join-path -path (join-path $psscriptroot ..) -child packages.config
    iex "& nuget restore '$packagesConfigFile' -packagesdirectory '$packagesDestination' $nugetConfigFileArgument" | out-host
}

InstallDependencies
