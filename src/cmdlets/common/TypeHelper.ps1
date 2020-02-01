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

        function __initialize {
            __RegisterDisplayType
        }

        function ToPublic( $privateObject ) {
            # Seems like ScriptClass constants have a strange behavior when used as a typename here.
            # To work around this, use ToString()
            [PSCustomObject]@{
                PSTypeName = ($this.DisplayTypeName.tostring())
                TypeId = $privateObject.TypeId
                Namespace = $privateObject.Namespace
                TypeClass = $privateObject.Class
                BaseType = $privateObject.BaseType
                Properties = $privateObject.Properties
                IsComposite = $privateObject.IsComposite
                NativeSchema = $privateObject.NativeSchema
            }
        }

        function __RegisterDisplayType {
            remove-typedata -typename $this.DisplayTypeName -erroraction ignore

            $coreProperties = @('TypeId', 'TypeClass', 'BaseType', 'IsComposite', 'Properties')

            $displayTypeArguments = @{
                TypeName    = $this.DisplayTypeName
                DefaultDisplayPropertySet = $coreProperties
            }

            Update-TypeData -force @displayTypeArguments
        }
    }
}

$::.TypeHelper |=> __initialize
