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
. (import-script common/QueryHelper)
. (import-script common/GraphParameterCompleter)
. (import-script common/TypeParameterCompleter)
. (import-script common/TypePropertyParameterCompleter)
. (import-script common/WriteOperationParameterCompleter)

function Get-GraphItem {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='bytypeandid')]
    param(
        [parameter(position=0, parametersetname='bytypeandid', mandatory=$true)]
        [parameter(position=0, parametersetname='typeandpropertyfilter', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeandfilter', mandatory=$true)]
        $TypeName,

        [parameter(position=1, parametersetname='bytypeandid', valuefrompipeline=$true, mandatory=$true)]
        $Id,

        [parameter(position=2, parametersetname='bytypeandid')]
        [parameter(position=2, parametersetname='typeandpropertyfilter')]
        [parameter(position=2, parametersetname='bytypeandfilter')]
        [parameter(position=2, parametersetname='byuri')]
        [parameter(position=2, parametersetname='byuriandfilter')]
        [string[]] $Property,

        [parameter(parametersetname='byuri', mandatory=$true)]
        [parameter(parametersetname='byuriandfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandpropertyfilter', mandatory=$true)]
        [Uri] $Uri,

        $GraphName,

        [parameter(parametersetname='typeandpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandpropertyfilter', mandatory=$true)]
        $PropertyFilter,

        [parameter(parametersetname='bytypeandfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandfilter', mandatory=$true)]
        $Filter,

        [switch] $ContentOnly,

        [switch] $ChildrenOnly,

        [switch] $FullyQualifiedTypeName,

        [switch] $SkipPropertyCheck
    )

    begin {
        Enable-ScriptClassVerbosePreference

        $filterParameter = @{}
        $filterValue = $::.QueryHelper |=> ToFilterParameter $PropertyFilter $Filter
        if ( $filterValue ) {
            $filterParameter['Filter'] = $filterValue
        }
    }

    process {
        $targetId = if ( $Id ) {
            $Id
        }

        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $targetId $null

        if ( ! $SkipPropertyCheck.IsPresent ) {
            $::.QueryHelper |=> ValidatePropertyProjection $requestInfo.TypeInfo $Property
        }

        if ( $requestInfo.IsCollection -and ! $ChildrenOnly.IsPresent ) {
            $requestInfo.TypeInfo.UriInfo
        } else {
            Get-GraphResourceWithMetadata -Uri $requestInfo.Uri -GraphName $requestInfo.Context.name -erroraction 'stop' -select $Property @filterParameter -ContentOnly:$($ContentOnly.IsPresent) -ChildrenOnly:$($ChildrenOnly.IsPresent)
        }
    }

    end {}
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem TypeName (new-so WriteOperationParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem Property (new-so WriteOperationParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem Uri (new-so GraphUriParameterCompleter ([GraphUriCompletionType]::LocationOrMethodUri ))
