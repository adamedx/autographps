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

ScriptClass TypeDefinition {
    . {}.module.newboundscriptblock($::.TypeSchema.EnumScript)

    $TypeId = $null
    $BaseType = $null
    $Name = $null
    $Namespace = $null
    $Properties = $null
    $NavigationProperties = $null
    $Class = $null
    $IsComposite = $false
    $DefaultValue = $null
    $DefaultCollectionValue = $null
    $NativeSchema = $null
    $Methods = $null

    function __initialize($typeId, [GraphTypeClass] $class, $name, $namespace, $baseType, $properties, $defaultValue, $defaultCollectionValue, $isComposite, $nativeSchema, $navigationProperties, $methods) {
        if ( $class -eq 'Unknown' ) {
            throw [ArgumentException]::new("Error creating definition for type '$typeId': the specified type class 'Unknown' is not valid -- the type must be Enumeration, Complex, Primitive, or Entity")
        }

        $this.TypeId = $typeId
        $this.Class = $class
        $this.BaseType = $baseType
        $this.Name = $name
        $this.Properties = @()
        $this.NavigationProperties = @()
        $this.Methods = @()
        $this.Namespace = $namespace
        $this.IsComposite = $IsComposite
        $this.DefaultValue = $defaultValue
        $this.DefaultCollectionValue = $defaultCollectionValue
        $this.NativeSchema = $nativeSchema

        # Also, we only assign to them if the values are not null or empty -- in either case,
        # if we return '@()' in an if statement, it gets converted to $nuill on assignment (!) which is not what we want. So we init these
        # members to the desired value of @() and then assign to them only if there's something to assign.
        if ( $Properties ) {
            # Ensure that these members are *ALWAYS* arrays by overriding some PowerShell semantics with singleton arrays via ','
            $this.Properties = if ( ! $properties -or $properties.GetType().IsArray ) { $properties } else { , @($properties) }
        }
        if ( $NavigationProperties ) {
            # See the singleton override workaround for the same case above for Properties
            $this.NavigationProperties = if ( ! $navigationProperties -or $navigationProperties.GetType().IsArray ) { $navigationProperties } else { , @($navigationProperties) }
        }

        if ( $Methods ) {
            $this.Methods = if ( ! $methods -or $methods.GetType().IsArray ) { $methods } else { , @($methods) }
        }
    }
}

