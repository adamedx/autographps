# Copyright 2021, Adam Edwards
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

ScriptClass MethodDisplayType {
    $Name = $null
    $MethodType = $null
    $ReturnType = $null
    $Parameters = $null

    function __initialize($typeMethod) {
        $this.Name = $typeMethod.Name
        $this.MethodType = $typeMethod.MethodType
        $this.ReturnType = [PSCUstomObject] @{
            TypeId = $typeMethod.TypeId
            IsCollection = $typeMethod.IsCollection
        }
        $this.Parameters = $typeMethod.Parameters
    }

    static {
        function __RegisterDisplayType {
            $displayTypeName = $this.ClassName

            $displayProperties = @('Name', 'MethodType', 'ReturnType', 'Parameters')

            remove-typedata -typename $displayTypeName -erroraction ignore

            $displayProperties | foreach {
                $memberArgs = @{
                    TypeName = $displayTypeName
                    MemberType = 'NoteProperty'
                    MemberName = $_
                    Value = $null
                }

                Update-TypeData -force @memberArgs
            }

            $displayTypeArguments = @{
                TypeName = $displayTypeName
                DefaultDisplayPropertySet = $displayProperties
            }

            Update-TypeData -force @displayTypeArguments
        }

        function ToPublicParameterList($method) {
            if ( $method.parameters ) {
                $result = $method.parameters | foreach {
                    $newParameter = [PSCustomObject] @{
                        MethodName = $method.Name
                        Name = $_.Name
                        TypeId = $_.TypeId
                        IsCollection = $_.IsCollection
                    }
                    $newParameter.pstypenames.insert(0, 'MethodParameterType')
                    $newParameter
                }

                $result
            }
        }
    }
}


$::.MethodDisplayType |=> __RegisterDisplayType
