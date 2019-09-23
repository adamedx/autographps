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

$actionRequired = $true

if ( $Force.IsPresent ) {
    write-verbose "Force specified, removing existing bin directory..."
    Clean-Tools
}

$destinationPath = join-path (split-path -parent $psscriptroot) bin

if ( ! ( test-path $destinationPath ) ) {
    write-verbose "Destination directory '$destinationPath' does not exist, creating it..."
    new-directory -name $destinationPath | out-null
}

if ( $PSVersionTable.PSEdition -eq 'Desktop' ) {
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

        if ( ! ( test-path $nugetPath ) ) {
            write-verbose "Downloading latest nuget executable to '$nugetPath'..."
            Invoke-WebRequest -usebasicparsing https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -outfile $nugetPath
            write-verbose "Download of nuget executable complete."
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
} else {
    write-verbose "Not running on Windows, explicitly checking for required 'dotnet' tool for .net runtime..."

    $dotNetToolPath = (get-command dotnet -erroraction ignore) -ne $null

    # TODO: distinguish between dotnet sdk vs runtime only -- we need dotnet sdk.
    # We assume if dotnet is present it is the SDK, but it could just be the runtime.
    # An additional check for successful execution of 'dotnet cli' is one way to
    # determine this, but it's not clear how to remediate if dotnet runtime is installed
    # and SDK isn't. Failing on detection of that case may be the most deterministic option.
    if ( ! $dotNetToolPath ) {
        write-verbose "Required 'dotnet' tool not detected, updating PATH to look under home directory and retrying..."
        set-item env:PATH ($env:PATH + ":" + ("/home/$($env:USER)/.dotnet"))
    }

    $hasValidVersion = $false
    $dotNetToolPathUpdated = (get-command dotnet -erroraction ignore) -ne $null
    $minimumVersionString = '2.2.300'

    if ( $dotNetToolPathUpdated ) {
        write-verbose 'Found dotnet tool, will check version'
        get-command dotnet | write-verbose
        $minimumVersion = $minimumVersionString -split '\.'
        $dotNetVersionString = ( & dotnet --version )
        $dotNetVersion = $dotNetVersionString -split '\.'
        write-verbose "Looking for minimum version '$minimumVersionString'"
        write-verbose "Found dotnet version '$dotNetVersionString'"

        if ( ([int]$dotNetVersion[0]) -ge [int]$minimumVersion[0] -and
             ([int]$dotNetVersion[1]) -ge [int]$minimumVersion[1] -and
             ([int]$dotNetVersion[2]) -ge [int]$minimumVersion[2] ) {
                 write-verbose 'Detected version meets minimum version requirement, no download necessary.'
                 $hasValidVersion = $true
             } else {
                 write-verbose 'Detected version does not meet minimum version requirement, download will be required.'
             }
    }

    if ( ! $hasValidVersion ) {
        write-verbose "Executable 'dotnet' not found after PATH update or incorrect version, will install required .net runtime in default location..."

        $versionArgument = '-version'
        $dotNetInstallerFile = if ( $PSVersionTable.Platform -eq 'Win32NT' ) {
            'dotnet-install.ps1'
        } else {
            $versionArgument = '--version'
            'dotnet-install.sh'
        }

        $dotNetInstallerPath = join-path $destinationPath $dotNetInstallerFile

        if ( ! ( test-path $dotNetInstallerPath ) ) {
            $installerUri = if ( $PSVersionTable.Platform -eq 'Win32NT' ) {
                'https://dot.net/v1/dotnet-install.ps1'
            } else {
                'https://dot.net/v1/dotnet-install.sh'
            }

            write-verbose "Downloading .net installer script to '$dotNetInstallerPath'..."
            Invoke-WebRequest -usebasicparsing $installerUri -OutFile $dotNetInstallerPath
            if ( $PSVersionTable.Platform -ne 'Win32NT' ) {
                & chmod +x $dotNetInstallerPath
            }
        }

        # Installs runtime and SDK
        write-verbose 'Installing new .net version...'
        (& $dotNetInstallerPath $versionArgument $minimumVersionString) | write-verbose

        $dotNetToolFinalVerification = (get-command dotnet -erroraction ignore) -ne $null

        if ( ! $dotNetToolFinalVerification ) {
            throw "Unable to install or detect required .net runtime tool 'dotnet'"
        }

        $newDotNetVersion = (& dotnet --version)
        write-verbose "After installation dotnet version '$newDotNetVersion' detected..."
    } else {
        $actionRequired = $false
    }

    # Pester is present on the default Windows installation, but not for Linux
    # TODO: May make sense to update to a specific version on both platforms.
    if ( ! ( get-command invoke-pester -erroraction ignore ) ) {
        $actionRequired = $true
        write-verbose "Test tool 'pester' not found, installing the Pester Module..."
        install-module -scope currentuser Pester -verbose
    }
}


$changeDisplay = if ( $actionRequired ) {
    'Changes'
} else {
    'No changes'
}

write-host -fore green ("Tools successfully configured in directory '$destinationPath'. {0} were required." -f $changeDisplay)
