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

        [parameter(parametersetname='bytype', position=1, mandatory=$true)]
        [parameter(parametersetname='byuri', position=1)]
        [string] $MethodName,

        [parameter(parametersetname='byuri', mandatory=$true)]
        [Uri] $Uri,

        [parameter(parametersetname='byobject', valuefrompipeline=$true, mandatory=$true)]
        [PSCustomObject] $GraphItem,

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

    $targetTypeName = if ( $TypeName ) {
        $TypeName
    } else {
        $graphNameArgument = if ( $GraphName ) { @{GraphName=$GraphName} } else { @{} }
        $isFullyQualifiedTypeName = $true
        $uriInfo = Get-GraphUriInfo $Uri -erroraction stop @graphNameArgument
        if ( $uriInfo.Class -in 'Action', 'Function' ) {
            $targetMethodName = $uriInfo.Name
            $typeUriInfo = Get-GraphUriInfo $uriInfo.ParentPath -erroraction stop @graphNameArgument
            $typeUriInfo.FullTypeName
        } elseif ( $targetMethodName ) {
            $uriInfo.FullTypeName
        } else {
            throw [ArgumentException]::new("The URI '$Uri' is not a method but the MethodName parameter was not specified -- please specify a method URI or include the MethodName parameter and retry the command")
        }
    }

    $type = Get-GraphType -TypeName $targetTypeName -TypeClass Any -FullyQualifiedTypeName:$isFullyQualifiedTypeName -erroraction stop

    $method = $type.methods | where name -eq $targetMethodName

    if ( ! $method ) {
        throw [ArgumentException]::new("The method '$MethodName' does not exist for the type '$($type.TypeId)'")
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
