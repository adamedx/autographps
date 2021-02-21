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

    function GetSortedTypeNames($typeClass) {
        if ( ! $this.derived ) {
            throw "Abstract class '$($this.scriptclass.classname)' may not be directly instantiated"
        }
        $this.derived |=> GetSortedTypeNames $typeClass
    }

    function UpdateTypeIndexes($indexes, $typeClasses) {
        if ( ! $this.derived ) {
            throw "Abstract class '$($this.scriptclass.classname)' may not be directly instantiated"
        }
        $this.derived |=> UpdateTypeIndexes $indexFields
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

        function GetProviderForClass([GraphTypeClass] $typeClass) {
            $this.providerModels[$typeClass.tostring()]
        }

        function ValidateTypeClass($derivedClass, [GraphTypeClass] $typeClass) {
            $supportedClasses = $derivedClass |=> GetSupportedTypeClasses

            if ( ! ( $typeClass -in $supportedClasses ) ) {
                throw "The '$($this.scriptclass.classname)' type provider does not support type class '$typeClass'"
            }
        }
    }
}
