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
param([switch] $Force)

. "$psscriptroot/common-build-functions.ps1"

if ( $PSVersionTable.PSEdition -eq 'Desktop' ) {
    $actionRequired = $true
    if ( $Force.IsPresent ) {
        write-verbose "Force specified, removing existing bin directory..."
        Clean-Tools
    }

    $destinationPath = join-path (split-path -parent $psscriptroot) bin
    $nugetPath = join-path $destinationPath nuget.exe

    $nugetPresent = try {
        Validate-NugetPresent
        $hasCorrectNuget = (get-command nuget).source -eq $nugetPath
        write-verbose ("Nuget is present at '$nugetPath' -- IsNugetLocationValid = {0}" -f $hasCorrectNuget)
        if ( ! $hasCorrectNuget ) {
            write-verbose "The detected nuget is invalid, will update configuration to fix."
        }
        $hasCorrectNuget
    } catch {
        $false
    }

    if ( ! $nugetPresent -or $Force.IsPresent ) {
        write-verbose "Tool configuration update required or Force was specified, updating tools..."

        if ( ! ( test-path $destinationPath ) ) {
            write-verbose "Destination directory '$destinationPath' does not exist, creating it..."
            new-directory -name $destinationPath | out-null
        }

        if ( ! ( test-path $nugetPath ) ) {
            write-verbose "Downloading nuget executable to '$nugetPath'..."
            Invoke-WebRequest -usebasicparsing https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -outfile $nugetPath
        }

        if ( ! ($env:path).tolower().startswith($destinationPath.tolower()) ) {
            write-verbose 'Environment is missing local bin directory -- updating PATH environment variable...'
            si env:PATH "$destinationPath;$($env:path)"
        } else {
            write-verbose 'Environment already contains local bin directory, skipping PATH environment variable update'
        }

        Validate-NugetPresent
        $detectedNuget = (get-command nuget).source
        $hasCorrectNuget = $detectedNuget -eq $nugetPath

        if ( ! $hasCorrectNuget ) {
            throw "Installed nuget to '$nugetPath', but environment is using a different nuget at path '$detectedNuget'"
        }
    } else {
        $actionRequired = $false
        write-verbose "Tool configuration validated successfully, no action necessary."
    }

    $changeDisplay = if ( $actionRequired ) {
        'Changes'
    } else {
        'No changes'
    }

    write-host -fore green ("Tools successfully configured in directory '$destinationPath'. {0} were required." -f $changeDisplay)
}
