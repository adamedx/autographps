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

. "$psscriptroot/../src/lib/stdlib/enable-stdlib.ps1"

include-source "src/app/common/assemblyhelper"

. "$($global:ApplicationRoot)/src/lib/stdlib/enable-include.ps1"

function ValidateNugetPresent {
    get-command nuget | out-null

    if (! $?) {
        throw "Nuget is not installed. Please visit https://nuget.org to install, then restart PowerShell and try again."
    }
}

function InstallDependencies {
    ValidateNugetPresent
    $packagesDestination = (GetAssemblyRoot)
    $packagesConfigFile = join-path -path $global:ApplicationRoot -child packages.config
    & nuget restore $packagesConfigFile -packagesdirectory $packagesDestination
}

InstallDependencies
