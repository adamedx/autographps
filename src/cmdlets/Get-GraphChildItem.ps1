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

function Get-GraphChildItem {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, supportsshouldprocess=$true)]
    param(
        [parameter(position=0)]
        [Uri[]] $ItemRelativeUri = @('.'),

        [parameter(position=1)]
        [String] $Query = $null,

        [String] $ODataFilter = $null,

        [String] $Search = $null,

        [String[]] $Select = $null,

        [String[]] $Expand = $null,

        [Alias('Sort')]
        $OrderBy = $null,

        [Switch] $Descending,

        [Object] $ContentColumns = $null,

        [switch] $RawContent,

        [switch] $AbsoluteUri,

        [switch] $IncludeAll,

        [switch] $Recurse,

        [switch] $DetailedChildren,

        [switch] $DataOnly,

        [Switch] $RequireMetadata,

        [HashTable] $Headers = $null,

        [string] $ResultVariable = $null
    )

    Enable-ScriptClassVerbosePreference

    $targetParameters = @{}

    $PSBoundParameters.keys | foreach {
        $targetParameters[$_] = $PSBoundParameters[$_]
    }

    $targetParameters['StrictOutput'] = [System.Management.Automation.SwitchParameter]::new($true)

    Get-GraphItemWithMetadata @targetParameters
}
