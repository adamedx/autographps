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

param($packagePath = $null, $targetFeedUri = $null)

set-strictmode -version 2
$erroractionpreference = 'stop'

$packageName = 'adamedx.poshgraph'

$basepath = (get-item (split-path -parent $psscriptroot)).fullname

$feedUri = if ( $targetFeedUri -ne $null ) {
    $targetFeedUri
} else {
    'https://adamedx.pkgs.visualstudio.com/_packaging/SecretPackages/nuget/v3/index.json'
}

$packageLocation = if ( $packagePath -ne $null ) {
    $packagePath
} else {
    $packageDirectory = join-path  $basepath 'pkg'
    $packages = ls $packageDirectory -filter "$($packageName)*.nupkg"
    if ( $packages -isnot [System.IO.FileSystemInfo] ) {
        throw "Found more than one .nupkg file matching $($packageName)*.nupkg in directory '$packageDirectory'. Delete the directory, rebuild, and retry this script."
    }
    $packages[0].fullname
}

$nugetpushcmd = "& nuget.exe push -source '$feedUri' -apikey ignorablekey '$packageLocation'"

write-host "Publishing nuget package '$packageLocation' to '$feedUri'..."
write-host "Executing command: ", $nugetpushcmd

iex $nugetpushcmd

$pushresult = $lastexitcode

if ( $pushresult -ne 0 ) {
    write-host -f red "Publish failed with exit status '$pushresult'"
    throw "Command '$nugetpushcmd' failed with exit status '$pushresult'"
}

write-host -foregroundcolor green "Publish NuGet package succeeded."


