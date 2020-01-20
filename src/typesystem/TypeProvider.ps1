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

. (import-script TypeDefinition)

ScriptClass TypeProvider {
    $graph = $null
    $derived = $null

    function __initialize($derived, $graph) {
        $this.derived = $derived
        $this.graph = $graph
    }

    function GetTypeDefinition($typeClass, $typeId) {
        if ( ! $this.derived ) {
            throw "Abstract class '$($this.scriptclass.classname)' may not be directly instantiated"
        }
        $this.derived |=> GetTypeDefinition $typeClass $typeId
    }

    static {
        . {}.Module.NewBoundScriptBlock($::.TypeSchema.EnumScript)

        const REQUIRED_ENUM_AS_PRIMITIVE_TYPE (
            [PSCustomObject] @{
                TypeClass = . { [GraphTypeClass]::Primitive }
                TypeId = 'Edm.String'
            }
        )

        $providersByScriptClass = @{}

        $providerModels = @{
            Unknown = 'CompositeTypeProvider'
            Primitive = 'ScalarTypeProvider'
            Enumeration = 'ScalarTypeProvider'
            Complex = 'CompositeTypeProvider'
            Entity = 'CompositeTypeProvider'
        }

        function GetDefaultNamespace([GraphTypeClass] $typeClass, $graph) {
            $providerModel = GetProviderForClass $typeClass
            $providerModel |::> GetDefaultNamespace $typeClass $graph
        }

        function GetRequiredTypeInfo {
            @($this.REQUIRED_ENUM_AS_PRIMITIVE_TYPE)
        }

        function GetTypeProvider([GraphTypeClass] $typeClass, $graph) {
            $providerModel = GetProviderForClass $typeClass
            GetTypeProviderByObjectClass $::.$providerModel $graph
        }

        function GetTypeProviderByObjectClass($classObject, $graph) {
            $classProviderTable = GetProviderTable $classObject
            GetItemByObject $classProviderTable $graph {param($className, $graph) new-so $className $graph} $classObject.classname, $graph
        }

        function GetProviderForClass([GraphTypeClass] $typeClass) {
            $this.providerModels[$typeClass.tostring()]
        }

        function GetProviderTable($class) {
            GetItemByObject $this.providersByScriptClass $class {@{}}
        }

        function GetItemByObject($table, $object, $createBlock, $createArguments) {
            $itemId = $object |=> GetScriptObjectHashCode

            $item = $table[$itemId]

            if ( ! $item ) {
                $item = invoke-command $createBlock -argumentlist $createArguments
                $table.Add($itemId, $item)
            }

            $item
        }

        function GetGraphNamespace($graph) {
            ($::.GraphManager |=> GetGraph $graph).namespace
        }

        function ValidateTypeClass($derivedClass, [GraphTypeClass] $typeClass) {
            $supportedClasses = $derivedClass |=> GetSupportedTypeClasses

            if ( ! ( $typeClass -in $supportedClasses ) ) {
                throw "The '$($this.scriptclass.classname)' type provider does not support type class '$typeClass'"
            }
        }
    }
}
