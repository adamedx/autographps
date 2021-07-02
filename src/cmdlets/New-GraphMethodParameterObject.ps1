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
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='byobject')]
    param(
        [parameter(parametersetname='bytype', position=0, mandatory=$true)]
        $TypeName,

        [parameter(parametersetname='byobject', position=1, mandatory=$true)]
        [parameter(parametersetname='bytype', position=1, mandatory=$true)]
        [parameter(parametersetname='byuri', position=1)]
        [string] $MethodName,

        [parameter(parametersetname='byuri', mandatory=$true)]
        [Uri] $Uri,

        [parameter(parametersetname='byobject', valuefrompipeline=$true, mandatory=$true)]
        [PSTypeName('GraphResponseObject')] $GraphItem,

        $GraphName,

        [switch] $FullyQualifiedTypeName,

        [switch] $Json,

        [switch] $NoRecurse,

        [switch] $NoValues,

        [switch] $SetDefaultValues
    )

    Enable-ScriptClassVerbosePreference

    $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $GraphName

    $typeManager = $::.TypeManager |=> Get $targetContext

    $isFullyQualifiedTypeName = $FullyQualifiedTypeName.IsPresent

    $targetMethodName = $MethodName

    $commandParameters = @{}

    foreach ( $commandParameter in
              'GraphItem',
              'GraphName',
              'Uri',
              'MethodName',
              'TypeName',
              'FullyQualifiedTypeName' ) {
                  if ( $PSBoundParameters.ContainsKey($commandParameter) ) {
                      $commandParameters.Add($commandParameter, $PSBoundParameters[$commandParameter])
                  }
              }

    $method = Get-GraphMethod @commandParameters

    if ( ! $method ) {
        throw [ArgumentException]::new("The specified method does not exist for the Graph location, type, or object")
    }

    if ( ( $method | measure-object ).count -gt 1 ) {
        throw "Unexpected error -- multiple methods matching the specified criteria were found"
    }

    $parameterObject = @{}

    foreach ( $parameter in $method.parameters ) {
        $parameterTypeName = $parameter.TypeId

        $prototype = if ( ! $NoValues.IsPresent ) {
            $typeManager |=> GetPrototype 'Unknown' $parameterTypeName $true $SetDefaultValues.IsPresent ( ! $NoRecurse.IsPresent ) $null $null $null $false $parameter.IsCollection
        }

        $parameterObject.Add($parameter.Name, $prototype.ObjectPrototype)
    }

    $parametersAsJson = $parameterObject | convertto-json -depth 24

    if ( $Json.IsPresent ) {
        $parametersAsJson
    } else {
        $parametersAsJson | convertfrom-json
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphMethodParameterObject TypeName (new-so TypeParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphMethodParameterObject MethodName (new-so MethodUriParameterCompleter MethodName)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphMethodParameterObject GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphMethodParameterObject Uri (new-so GraphUriParameterCompleter ([GraphUriCompletionType]::LocationOrMethodUri ))
