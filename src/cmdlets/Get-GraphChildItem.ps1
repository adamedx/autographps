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

function Get-GraphChildItem {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='byuri')]
    param(
        [parameter(position=0, parametersetname='byuri', mandatory=$true)]
        [parameter(position=0, parametersetname='byuriandfilter', mandatory=$true)]
        [parameter(position=0, parametersetname='byuriandpropertyfilter', mandatory=$true)]
        [Uri] $Uri,

        [parameter(parametersetname='bytypeandid', mandatory=$true)]
        [parameter(parametersetname='typeandpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='bytypeandfilter', mandatory=$true)]
        $TypeName,

        [parameter(position=1, parametersetname='bytypeandid', valuefrompipeline=$true, mandatory=$true)]
        $Id,

        [parameter(position=2, parametersetname='byuri')]
        [parameter(position=2, parametersetname='byuriandfilter')]
        [parameter(position=2, parametersetname='typeandpropertyfilter')]
        [parameter(position=2, parametersetname='bytypeandfilter')]
        [string[]] $Property,

        $GraphName,

        [parameter(parametersetname='typeandpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandpropertyfilter', mandatory=$true)]
        $PropertyFilter,

        [parameter(parametersetname='bytypeandfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandfilter', mandatory=$true)]
        $Filter,

        [switch] $ContentOnly,

        [switch] $FullyQualifiedTypeName,

        [switch] $SkipPropertyCheck
    )
    Get-GraphItem @PSBoundParameters -ChildrenOnly:$true
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem Uri (new-so GraphUriParameterCompleter ([GraphUriCompletionType]::LocationOrMethodUri ))
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem TypeName (new-so WriteOperationParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem Property (new-so WriteOperationParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem GraphName (new-so GraphParameterCompleter)

