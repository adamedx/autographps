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
. (import-script common/TypeParameterCompleter)

function New-GraphObject {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='optionallyqualified')]
    param(
        [parameter(position=0, mandatory=$true)]
        $TypeName,

        [ValidateSet('Primitive', 'Enumeration', 'Complex', 'Entity')]
        $TypeClass = 'Entity',

        [parameter(parametersetname='optionallyqualified')]
        $Namespace,

        $GraphName,

        [string[]] $Property,

        [object[]] $Value,

        [parameter(parametersetname='fullyqualified', mandatory=$true)]
        [switch] $FullyQualifiedTypeName,

        [switch] $Json,

        [switch] $Recurse,

        [switch] $SetDefaultValues
    )

    Enable-ScriptClassVerbosePreference

    $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $GraphName

    $typeManager = $::.TypeManager |=> Get $targetContext

    $isFullyQualified = $FullyQualifiedTypeName.IsPresent -or ( $typeClass -ne 'Primitive' -and $TypeName.Contains('.') )

    $prototype = $typeManager |=> GetPrototype $typeClass $TypeName $isFullyQualified $SetDefaultValues.IsPresent $Recurse.IsPresent $Property $Value

    $prototypeJson = $prototype | convertto-json -depth 24

    if ( $Json.IsPresent ) {
        $prototypeJSON
    } else {
        $prototypeJSON | convertfrom-json
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphObject TypeName (new-so TypeParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphObject GraphName (new-so GraphParameterCompleter)
