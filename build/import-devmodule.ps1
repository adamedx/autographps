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
param($InitialCommand = $null, [switch] $NoNewShell, [switch] $Wait, [switch] $ReuseConsole)

. "$psscriptroot/common-build-functions.ps1"

$moduleName = Get-ModuleName
$currentpsmodulepath = gi env:PSModulePath
$devDirectory = Get-DevModuleDirectory
$OSPathSeparator = ';'
$moduleManifestPath = get-childitem -r -path $devDirectory -filter *.psd1 | where basename -eq $moduleName | select -expandproperty fullname

try {
    if ( $PSVersionTable.PSEdition -eq 'Core' ) {
        if ( $PSVersionTable.Platform -ne 'Windows' -and $PSVersionTable.Platform -ne 'Win32NT' ) {
            $OSPathSeparator = ':'
        }
    }
} catch {
}

if (! $NoNewShell.ispresent ) {
    $newpsmodulepath = $devDirectory + $OSPathSeparator + $currentpsmodulepath.value
    write-verbose "Using updated module path in new process to import module '$moduleName' with psmodulepath '$newpsmodulepath'"
    $shouldWait = $Wait.IsPresent

    $noNewWindow = $ReuseConsole.IsPresent

    write-verbose ("WaitForProcess = {0}, ReuseWindow = {1}" -f $shouldWait, $noNewWindow)

    # Strange things occur when I use -NoNewWindow:$false -- going to just
    # duplicate the command with the additional -NoNewWindow param :(
    if ( ! $NoNewWindow ) {
        start-process $PowerShellExecutable '-noexit', '-command', "si env:PSModulePath '$newpsmodulepath';import-module '$moduleName'; $InitialCommand" -Wait:$shouldWait | out-null
    } else {
        start-process $PowerShellExecutable '-noexit', '-command', "si env:PSModulePath '$newpsmodulepath';import-module '$moduleName'; $InitialCommand" -Wait:$shouldWait -nonewwindow | out-null
    }
    write-host "Successfully launched module '$moduleName' in a new PowerShell console."
    return
}

write-host -foregroundcolor yellow "Run the following command to import the module into your current session:"
write-host -foregroundcolor cyan "`n`t. ($($myinvocation.mycommand.path) -nonewshell)`n"

$scriptBlock = @"
    # You can also run these commands directly in your PowerShell session

    # Remove any pre-existing version of this module
    remove-module -force '$moduleName' -erroraction silentlycontinue

    # Set the PSModulePath environment variable so that import-module can find the dev module
    si env:PSModulePath ('$devDirectory' + '$OSPathSeparator' + '$($currentpsmodulepath.value)')

    try {

        # Import the dev module
        write-verbose "Using updated module path to import module '$moduleName': '`$(`$env:PSModulePath)'"
        write-verbose "Will import module by name '`$moduleName'"
        `$moduleExpectedParent = split-path -parent '$moduleManifestPath'

        # Be careful about using '-force' here -- force doesn't just reload
        # the module you specify it reloads its dependecies as well. If those deps
        # have state that your target module depends on, you can hit strange falures.
        # So for now, we assume its not already loaded -- maybe we can add a check
        # for that and fail in the future to avoid situations where one runs with
        # pre-existing state rather than the latest version of the module
        `$moduleInfo = import-module '$moduleName' -verbose -passthru # No '-force' -- see above!

        `$moduleBase = `$moduleInfo.moduleBase
        if ( `$moduleBase -ne `$moduleExpectedParent ) {
            throw "Module loaded from '`$moduleBase',  expected location to be '`$moduleExpectedParent'"
        }
    } finally {

        # Restore the original PSModulePath
        si env:psmodulepath '$($currentpsmodulepath.value)'

    }
"@

[ScriptBlock]::Create($scriptBlock)

