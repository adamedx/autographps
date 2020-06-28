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

ScriptClass MethodInfo {
    $Name = $null
    $MethodType = $null
    $Parameters = $null
    $ReturnTypeInfo = $null

    function __initialize($graph, $methodBindingSchema, $methodType) {
        if ( $methodType -eq 'Action' ) {
            $this.MethodType = 'Action'
        } elseif ( $methodType -eq 'Function' ) {
            $this.MethodType = 'Function'
        } else {
            throw [ArgumentException]::new("The specified method type '$methodType' is not valid, it must be one of 'Action', 'Function'.")
        }

        $this.Name = $methodBindingSchema.Name

        $unaliasedReturnType = $null
        $typeInfo = $null

        if ( ( $methodBindingSchema | gm ReturnType -erroraction ignore ) -and
             ( $methodBindingSchema.ReturnType | gm Type -erroraction ignore ) ) {
                 $typeInfo = $::.TypeSchema |=> GetNormalizedPropertyTypeInfo $null $methodBindingSchema.ReturnType.Type
                 $unaliasedReturnType = $graph |=> UnaliasQualifiedName $typeInfo.TypeFullName

                 $this.ReturnTypeInfo = [PSCustomObject] @{
                     TypeId = $unaliasedReturnType
                     IsCollection = $typeInfo.IsCollection
                 }
             }

        $this.Parameters = foreach ( $parameter in $methodBindingSchema.Parameter ) {
            if ( $parameter.name -ne 'bindingParameter' ) {
                $parameterTypeInfo = $::.TypeSchema |=> GetNormalizedPropertyTypeInfo $null $parameter.type
                $unaliasedParameterType = $graph |=> UnaliasQualifiedName $parameterTypeInfo.TypeFullName

                [PSCustomObject] @{
                    Name = $parameter.name
                    TypeId = $unaliasedParameterType
                    IsCollection = $parameterTypeInfo.IsCollection
                }
            }
        }
    }
}
