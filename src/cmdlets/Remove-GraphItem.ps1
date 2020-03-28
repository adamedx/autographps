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
. (import-script Get-GraphItem)

function Remove-GraphItem {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='bytypeandid')]
    param(
        [parameter(position=0, parametersetname='bytypeandid', mandatory=$true)]
        $TypeName,

        [parameter(position=1, parametersetname='bytypeandid', valuefrompipeline=$true, mandatory=$true)]
        $Id,

        [parameter(parametersetname='byuri', mandatory=$true)]
        [Uri] $Uri,

        $GraphName,

        [parameter(parametersetname='bytypeandid')]
        [parameter(parametersetname='byuri')]
        $Filter,

        [switch] $FullyQualifiedTypeName
    )

    begin {
        Enable-ScriptClassVerbosePreference

        $filterParameter = @{}
        $filterValue = $::.QueryHelper |=> ToFilterParameter $null $Filter
        if ( $filterValue ) {
            $filterParameter['Filter'] = $filterValue
        }
    }

    process {
        $targetId = if ( $Id ) {
            $Id
        }

        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $targetId $null

        $objects = Get-GraphResource $requestInfo.Uri @filterParameter -erroraction stop

        foreach ( $targetObject in $objects ) {
            if ( ! ( $targetObject | gm id -erroraction ignore ) ) {
                break
            }

            $targetUri = $::.TypeUriHelper |=> GetUriFromDecoratedObject $requestInfo.Context $targetObject
            Invoke-GraphRequest $targetUri -Method DELETE -erroraction stop -connection $requestInfo.Context.Connection | out-null
        }
    }

    end {}
}

$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItem TypeName (new-so WriteOperationParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItem GraphName (new-so GraphParameterCompleter)
