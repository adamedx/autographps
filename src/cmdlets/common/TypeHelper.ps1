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

. (import-script ../../typesystem/TypeDefinition)

ScriptClass TypeHelper {
    static {
        const DisplayTypeName 'GraphTypeDisplayType'

        $displayProperties = @{
            TypeId = 'TypeId'
            Namespace = 'Namespace'
            TypeClass = 'Class'
            BaseType = 'BaseType'
            Properties = 'Properties'
            NavigationProperties = 'NavigationProperties'
            IsComposite = 'IsComposite'
            NativeSchema = 'NativeSchema'
        }


        function __initialize {
            __RegisterDisplayType
        }

        function ToPublic( $privateObject ) {
            $result = [PSCustomObject] @{
                TypeId = $privateObject.($this.displayProperties.TypeId)
                Namespace = $privateObject.($this.displayProperties.Namespace)
                TypeClass = $privateObject.($this.displayProperties.TypeClass)
                BaseType = $privateObject.($this.displayProperties.BaseType)
                Properties = [PSCustomObject] ($privateObject.($this.displayProperties.Properties))
                NavigationProperties = [PSCustomObject] ($privateObject.($this.displayProperties.NavigationProperties))
                IsComposite = $privateObject.($this.displayProperties.IsComposite)
                NativeSchema = $privateObject.($this.displayProperties.NativeSchema)
            }

            $result.psobject.typenames.add($this. DisplayTypeName)
            $result
        }

        function __RegisterDisplayType {
            remove-typedata -typename $this.DisplayTypeName -erroraction ignore

            $coreProperties = @('TypeId', 'TypeClass', 'BaseType', 'IsComposite', 'Properties', 'NavigationProperties')

            $displayTypeArguments = @{
                TypeName = $this.DisplayTypeName
                DefaultDisplayPropertySet = $coreProperties
            }

            Update-TypeData -force @displayTypeArguments

            $this.displayProperties.keys | foreach {
                $memberArgs = @{
                    TypeName = $this.DisplayTypeName
                    MemberType = 'NoteProperty'
                    MemberName = $_
                    Value = $null
                }

                Update-TypeData -force @memberArgs
            }
        }
    }
}

$::.TypeHelper |=> __initialize
