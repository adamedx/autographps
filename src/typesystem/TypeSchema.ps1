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

ScriptClass TypeSchema {
    static {

        $EnumScript = {
            enum GraphTypeClass {
                Unknown
                Primitive
                Enumeration
                Complex
                Entity
            }
        }

        function GetTypeNameInfo($namespace, $qualifiedTypeName) {
            $unqualifiedTypeName = if ( $namespace ) {
                $qualifiedTypeName.substring($namespace.length + 1, $qualifiedTypeName.length - $namespace.length - 1)
            } else {
                $qualifiedTypeName
            }

            [PSCustomObject] @{
                Namespace = $namespace
                Name = $unqualifiedTypeName
            }
        }

        function GetQualifiedTypeName($namespace, $unqualifiedName) {
            if ( $namespace ) {
                $namespace, $unqualifiedName -join '.'
            } else {
                $unqualifiedName
            }
        }

        function GetNormalizedPropertyTypeInfo($typeSpec) {
            $isCollection = $false
            $typeName = if ($typeSpec -match 'Collection\((?<typename>.+)\)') {
                $isCollection = $true
                $matches.typename
            } else {
                $typeSpec
            }

            [PSCustomObject] @{
                TypeFullName = $typeName
                IsCollection = $isCollection
            }
        }
    }
}
