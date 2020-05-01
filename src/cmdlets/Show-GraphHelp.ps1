# Copyright 2020, Adam Edwards
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
    [cmdletbinding(defaultparametersetname='bydefaultversion', positionalbinding=$false)]
    param(
        [parameter(position=0)]
        [String] $ResourceName = $null,

        [ValidateSet('Default', 'v1.0', 'beta')]
        [parameter(position=1, parametersetname='byversion', mandatory=$true)]
        [parameter(position=1, parametersetname='byversionpassthru', mandatory=$true)]
        [String] $Version = 'Default',

        [parameter(parametersetname='bygraph', mandatory=$true)]
        [parameter(parametersetname='bygraphpassthru', mandatory=$true)]
        $GraphName,

        [switch] $ShowHelpUri,

        [parameter(parametersetname='bygraphpassthru', mandatory=$true)]
        [parameter(parametersetname='byversionpassthru', mandatory=$true)]
        [parameter(parametersetname='bydefaultversionpassthru', mandatory=$true)]
        [switch] $PassThru
    )

    Enable-ScriptClassVerbosePreference

    $targetVersion = if ( $GraphName ) {
        $graphVersion = ($::.LogicalGraphManager |=> Get |=> GetContext $GraphName).version
        if ( ! $graphVersion ) {
            throw "No Graph with the specified name '$GraphName' for the GraphName parameter could be found"
        }
        $graphVersion
    } elseif ( $Version -eq 'Default' ) {
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
        $unqualifiedName = $ResourceName -split '\.' | select -last 1
        $uriTemplate -f $targetVersion, $unqualifiedName
    } else {
        'https://docs.microsoft.com/en-us/graph/overview'
    }

    if ( ! $ShowHelpUri.IsPresent ) {
        write-verbose "Accessing documentation with URI '$uri'"
        start-process $uri -passthru:($PassThru.IsPresent)
    } else {
        ([Uri] $uri).tostring()
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Show-GraphHelp ResourceName (new-so TypeParameterCompleter Entity, Complex $true)
$::.ParameterCompleter |=> RegisterParameterCompleter Show-GraphHelp GraphName (new-so GraphParameterCompleter)
