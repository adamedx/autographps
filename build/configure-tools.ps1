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

# Make sure we're running the latest version of powershellget
$minimumPowerShellGetVersion = [Version]::new('2.2.5')

write-verbose "Checking for required version of PowerShellGet module '$minimumPowerShellGetVersion'"
$latestPowerShellGetVersion = (get-module -listavailable PowerShellGet | sort-object version | select-object -last 1).Version
write-verbose "Found latest version of PowerShellGet '$latestPowerShellGetVersion'"

$meetsPowerShellGetRequirement = $latestPowerShellGetVersion -and $latestPowerShellGetVersion -ge $minimumPowerShellGetVersion

if ( ! $meetsPowerShellGetRequirement ) {
    # Don't bother using Update-Module since on Windows there is a "built-in" version that can't be updated with "Update-Module". :)
    write-verbose "Installing new version of PowerShellGet to meet minimum version requirement"
    Install-Package -scope CurrentUser -minimumVersion $minimumPowerShellGetVersion PowerShellGet -allowclobber -force | out-null
}

write-verbose "Checking for required 'dotnet' tool for .net runtime..."

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

$isWindowsOS = $PSEdition -eq 'Desktop' -or $PSVersionTable.Platform -eq 'Win32NT'

if ( ! $hasValidVersion ) {
    write-verbose "Executable 'dotnet' not found after PATH update or incorrect version, will install required .net runtime in default location..."

    $versionArgument = '-version'
    $dotNetInstallerFile = if ( $isWindowsOS ) {
        'dotnet-install.ps1'
    } else {
        $versionArgument = '--version'
        'dotnet-install.sh'
    }

    $dotNetInstallerPath = join-path $destinationPath $dotNetInstallerFile

    if ( ! ( test-path $dotNetInstallerPath ) ) {
        $installerUri = if ( $isWindowsOS ) {
            'https://dot.net/v1/dotnet-install.ps1'
        } else {
            'https://dot.net/v1/dotnet-install.sh'
        }

        write-verbose "Downloading .net installer script to '$dotNetInstallerPath'..."
        Invoke-WebRequest -usebasicparsing $installerUri -OutFile $dotNetInstallerPath
        if ( ! $isWindowsOS ) {
            & chmod +x $dotNetInstallerPath
        }
    }

    # Installs runtime and SDK
    write-verbose 'Installing new .net version...'
    (invoke-expression "$dotNetInstallerPath $versionArgument $minimumVersionString") | write-verbose

    $dotNetToolFinalVerification = (get-command dotnet -erroraction ignore) -ne $null

    if ( ! $dotNetToolFinalVerification ) {
        throw "Unable to install or detect required .net runtime tool 'dotnet'"
    }

    $newDotNetVersion = (& dotnet --version)
    write-verbose "After installation dotnet version '$newDotNetVersion' detected..."
} else {
    $actionRequired = $false
}

$requiredPesterVersion = '4.8.1'
write-verbose "Checking for required version of 'Pester' version '$requiredPesterVersion'"
$pesterModule = import-module Pester -RequiredVersion $requiredPesterVersion -passthru -erroraction ignore
if ( ! $pesterModule ) {
    # Need to use skippublishercheck because on Windows there is already a signed version installed.
    write-verbose "Test tool 'Pester' with required version '$requiredPesterVersion' not found, installing the required version of the Pester Module..."
    install-module -scope currentuser Pester -RequiredVersion $requiredPesterVersion -AllowClobber -force -skippublishercheck -Verbose
    import-module Pester -RequiredVersion $requiredPesterVersion | out-null
} else {
    write-verbose "Required version of Pester found, no update needed."
}


$changeDisplay = if ( $actionRequired ) {
    'Changes'
} else {
    'No changes'
}

write-host -fore green ("Tools successfully configured in directory '$destinationPath'. {0} were required." -f $changeDisplay)
