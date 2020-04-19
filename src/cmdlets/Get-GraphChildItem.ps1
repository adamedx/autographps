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

. (import-script ../typesystem/TypeManager)
. (import-script common/TypeUriHelper)
. (import-script common/GraphParameterCompleter)
. (import-script common/TypeParameterCompleter)
. (import-script common/TypePropertyParameterCompleter)
. (import-script common/TypeUriParameterCompleter)

function Get-GraphChildItem {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, defaultparametersetname='byuri')]
    param(
        [parameter(position=0, parametersetname='byuri', mandatory=$true)]
        [parameter(position=0, parametersetname='byuriandpropertyfilter', mandatory=$true)]
        [Uri] $Uri,

        [parameter(parametersetname='bytypecollection', mandatory=$true)]
        [parameter(parametersetname='bytypecollectionpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='bytypeandid', mandatory=$true)]
        [parameter(parametersetname='typeandpropertyfilter', mandatory=$true)]
        $TypeName,

        [parameter(position=1, parametersetname='bytypeandid', valuefrompipeline=$true, mandatory=$true)]
        $Id,

        [parameter(position=2, parametersetname='byuri')]
        [parameter(position=2, parametersetname='bytypeandid')]
        [parameter(position=2, parametersetname='bytypecollection')]
        [parameter(position=2, parametersetname='typeandpropertyfilter')]
        [string[]] $Property,

        $GraphName,

        [parameter(parametersetname='bytypecollectionpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='typeandpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandpropertyfilter', mandatory=$true)]
        $PropertyFilter,

        [parameter(parametersetname='bytypecollection')]
        [parameter(parametersetname='bytypecollectionpropertyfilter')]
        $Filter,

        [String] $Search,

        [string[]] $Expand,

        [Alias('Sort')]
        [string] $OrderBy = $null,

        [Switch] $Descending,

        [switch] $ContentOnly,

        [switch] $RawContent,

        [switch] $FullyQualifiedTypeName,

        [switch] $SkipPropertyCheck
    )
    $remappedParameters = $PSBoundParameters

    $remappedUri = if ( $TypeName -and ! $Id -and ! $Filter ) {
        $remappedParameters = @{}
        foreach ( $parameterName in $remappedParameters.Keys ) {
            if ( $parameterName -ne 'TypeName' ) {
                $remappedParameter.Add($parameterName, $PSBoundParameters[$parameterName])
            }
        }
        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $null $null $null
        $remappedParameters['Uri'] = $requestInfo.Uri
    }

    Get-GraphItem @remappedParameters -ChildrenOnly:$true
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem Uri (new-so GraphUriParameterCompleter ([GraphUriCompletionType]::LocationOrMethodUri ))
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem TypeName (new-so TypeUriParameterCompleter TypeName $true)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem Property (new-so TypeUriParameterCompleter Property $true)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem OrderBy (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem Expand (new-so TypeUriParameterCompleter Property $true NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem GraphName (new-so GraphParameterCompleter)

