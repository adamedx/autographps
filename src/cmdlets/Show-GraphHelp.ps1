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

function Show-GraphHelp {
    [cmdletbinding()]
    param(
        [String] $ResourceName = $null,

        [ValidateSet('Default', 'v1.0', 'beta')]
        [String] $Version = 'Default'
    )

    Enable-ScriptClassVerbosePreference

    $targetVersion = if ( $Version -eq 'Default' ) {
        $currentVersion = ($::.GraphContext |=> GetCurrent).version
        if ( $currentVersion -in 'v1.0', 'beta' ) {
            $currentVersion
        } else {
            write-warning "Unable to locate help for current graph's version '$currentVersion', defaulting to help for 'v1.0'"
            'v1.0'
        }
    } else {
        $Version
    }

    $uriTemplate = 'https://developer.microsoft.com/en-us/graph/docs/api-reference/{0}/resources/{1}'

    $uri = if ( $ResourceName ) {
        $uriTemplate -f $targetVersion, $ResourceName
    } else {
        'https://docs.microsoft.com/en-us/graph/overview'
    }

    write-verbose "Accessing documentation with URI '$uri'"
    start-process $uri
}
