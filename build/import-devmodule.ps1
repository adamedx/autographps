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

param($InitialCommand = $null, [switch] $NoNewShell, [switch] $Wait, [switch] $ReuseConsole, [switch] $ExitOnCommandComplete)

. "$psscriptroot/common-build-functions.ps1"

$moduleName = Get-ModuleName
$currentpsmodulepath = gi env:PSModulePath
$devDirectory = Get-DevModuleDirectory
$OSPathSeparator = ';'

try {
    if ( $PSVersionTable.PSEdition -eq 'Core' ) {
        if ( $PSVersionTable.Platform -ne 'Windows' -and $PSVersionTable.Platform -ne 'Win32NT' ) {
            $OSPathSeparator = ':'
        }
    }
} catch {
}

if (! $NoNewShell.ispresent) {
    $newpsmodulepath = $devDirectory + $OSPathSeparator + $currentpsmodulepath.value
    write-verbose "Using updated module path in new process to import module '$moduleName': 'newpsmodulepath'"
    $shouldWait = $Wait.IsPresent
    $noNewWindow = $ReuseConsole.IsPresent
    $commandArguments = if ( $ExitOnCommandComplete.IsPresent ) {
        @()
    } else {
        , @('-NoExit')
    }

    $commandArguments += @('-command', "si env:PSModulePath '$newpsmodulepath';import-module '$moduleName'; $InitialCommand")

    start-process $PowerShellExecutable -ArgumentList $commandArguments -Wait:$shouldWait -NoNewWindow:$noNewWindow | out-null

    write-host "Successfully launched module '$moduleName' in a new PowerShell console."
    return
}

write-host -foregroundcolor yellow "Run the following command to import the module into your current session:"
write-host -foregroundcolor cyan "`n`t. ($($myinvocation.mycommand.path) -nonewshell)`n"
$moduleManifestPath = get-childitem -r -path $devDirectory -filter *.psd1 | where basename -eq $moduleName | select -expandproperty fullname

$scriptBlock = @"
    # You can also run these commands directly in your PowerShell session

    # Remove any pre-existing version of this module
    remove-module -force '$moduleName' -erroraction silentlycontinue

    # Set the PSModulePath environment variable so that import-module can find the dev module
    si env:PSModulePath ('$devDirectory' + '$OSPathSeparator' + '$($currentpsmodulepath.value)')

    try {

        # Import the dev module
        write-verbose "Using updated module path to import module '$moduleName': '`$(`$env:PSModulePath)'"
        write-verbose "Will import module directly with module manifest path '$moduleManifestPath'"
        import-module '$moduleManifestPath' -force -verbose

    } finally {

        # Restore the original PSModulePath
        si env:psmodulepath '$($currentpsmodulepath.value)'

    }
"@

[ScriptBlock]::Create($scriptBlock)

