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
    $graphContext = $null
    $graphDataModel = $null
    $derived = $null

    function __initialize($derived, $graphContext) {
        $this.derived = $derived
        $this.graphContext = $graphContext
        $this.graphDataModel = ($::.GraphManager |=> GetGraph $this.graphContext).builder.datamodel
    }

    function GetTypeDefinition($typeClass, $typeId) {
        if ( ! $this.derived ) {
            throw "Abstract class '$($this.scriptclass.classname)' may not be directly instantiated"
        }
        $this.derived |=> GetTypeDefinition $typeClass $typeId
    }

    function GetSortedTypeNames($typeClass) {
        if ( ! $this.derived ) {
            throw "Abstract class '$($this.scriptclass.classname)' may not be directly instantiated"
        }
        $this.derived |=> GetSortedTypeNames $typeClass
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

        function GetDefaultNamespace([GraphTypeClass] $typeClass, $graphContext) {
            $providerModel = GetProviderForClass $typeClass
            $providerModel |::> GetDefaultNamespace $typeClass $graphContext
        }

        function GetRequiredTypeInfo {
            @($this.REQUIRED_ENUM_AS_PRIMITIVE_TYPE)
        }

        function GetTypeProvider([GraphTypeClass] $typeClass, $graphContext) {
            $providerModel = GetProviderForClass $typeClass
            GetTypeProviderByObjectClass $::.$providerModel $graphContext
        }

        function GetSortedTypeNames([GraphTypeClass] $typeClass, $graphContext) {
            $provider = GetTypeProvider $typeClass $graphContext
            $provider |=> GetSortedTypeNames $typeClass
        }

        function GetTypeProviderByObjectClass($classObject, $graphContext) {
            $classProviderTable = GetProviderTable $classObject
            GetItemByObject $classProviderTable $graphContext {param($className, $graphContext) new-so $className $graphContext} $classObject.classname, $graphContext
        }

        function RemoveTypeProvidersForGraph($graphContext) {
            foreach ( $providerTable in $this.providersByScriptClass.Values ) {
                __RemoveItemByObject $providerTable $graphContext
            }
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

        function __RemoveItemByObject($table, $object) {
            $itemId = $object |=> GetScriptObjectHashCode

            $item = $table[$itemId]

            if ( $item ) {
                $table.Remove($itemId)
            }
        }

        function GetGraphNamespace($graphContext) {
            ($::.GraphManager |=> GetGraph $graphContext) |=> GetDefaultNamespace
        }

        function ValidateTypeClass($derivedClass, [GraphTypeClass] $typeClass) {
            $supportedClasses = $derivedClass |=> GetSupportedTypeClasses

            if ( ! ( $typeClass -in $supportedClasses ) ) {
                throw "The '$($this.scriptclass.classname)' type provider does not support type class '$typeClass'"
            }
        }
    }
}
