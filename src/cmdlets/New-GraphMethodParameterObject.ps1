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
. (import-script common/TypePropertyParameterCompleter)
. (import-script common/MethodNameParameterCompleter)
. (import-script common/MethodUriParameterCompleter)

function New-GraphMethodParameterObject {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='optionallyqualified')]
    param(
        [parameter(position=0, mandatory=$true)]
        $TypeName,

        [parameter(position=1, parametersetname='optionallyqualified')]
        [parameter(position=1, parametersetname='fullyqualified')]
        [string] $MethodName,

        $GraphName,

        [parameter(parametersetname='fullyqualified', mandatory=$true)]
        [parameter(parametersetname='fullyqualifiedpropmap', mandatory=$true)]
        [switch] $FullyQualifiedTypeName,

        [switch] $Json,

        [switch] $NoRecurse,

        [switch] $NoValues,

        [switch] $NoSetDefaultValues
    )

    Enable-ScriptClassVerbosePreference

    $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $GraphName

    $typeManager = $::.TypeManager |=> Get $targetContext

    $type = Get-GraphType -TypeName $TypeName -TypeClass Any -FullyQualifiedTypeName:$($FullyQualifiedTypeName.IsPresent)

    $method = $type.methods | where name -eq $methodName

    if ( ! $method ) {
        throw [ArgumentException]::new("The method '$MethodName' does not exist for the type '$($type.TypeId)'")
    }

    $parameters = $method.memberdata.parameters

    $parameterObject = @{}

    foreach ( $parameterNameValue in $parameters.keys ) {
        $parameterTypeName = $parameters[$parameterNameValue]
        $value = if ( ! $NoValues.IsPresent ) {
            $prototype = $typeManager |=> GetPrototype 'Unknown' $parameterTypeName $true ( ! $NoSetDefaultValues.IsPresent ) ( ! $NoRecurse.IsPresent ) $null $null $null $false
            $prototype.ObjectPrototype
        }

        $parameterObject.Add($parameterNameValue, $value)
    }

    if ( $Json.IsPresent ) {
        $parameterObject | convertto-json -depth 24
    } else {
        [PSCustomObject] $parameterObject
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphMethodParameterObject TypeName (new-so TypeParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphMethodParameterObject MethodName (new-so MethodNameParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphMethodParameterObject GraphName (new-so GraphParameterCompleter)
