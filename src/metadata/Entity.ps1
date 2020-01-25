# Copyright 2019, Adam Edwards
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

ScriptClass Entity {
    $namespace = $null
    $namespaceAlias = $null
    $name = $null
    $type = $null
    $typeData = $null
    $navigations = $null

    function __initialize($schema, $namespace, $namespaceAlias) {
        $this.namespace = $namespace
        $this.namespaceAlias = $namespaceAlias

        $schemaElement = $schema | select -first 1
        $this.type = $schemaElement | select -expandproperty localname
        $this.name = $schemaElement | select -first 1 | select -expandproperty name
        $this.typeData = GetEntityTypeData $schema
        $this.navigations = if ( ($schema | gm navigationproperty) -ne $null ) {
            $schema.navigationproperty | foreach {
                new-so Entity $_ $namespace $namespaceAlias
            }
        }
    }

    function GetEntityId {
        '{0}:{1}:{2}' -f $this.type, $this.namespace, $this.name
    }

    function GetEntityTypeData($schema) {
        $typeData = switch ($this.type) {
            'NavigationProperty' {
                $this.scriptclass |=> GetEntityTypeDataFromTypeName $this.namespace $this.namespaceAlias $schema.type
            }
            'NavigationPropertyBinding' {
                $this.scriptclass |=> GetEntityTypeDataFromTypeName $this.namespace $this.namespaceAlias $schema.parameter.bindingparameter.type
            }
            'Function' {
                $this.scriptclass |=> GetEntityTypeDataFromTypeName $this.namespace $this.namespaceAlias $schema.ReturnType
            }
        }

        if ( ! $typeData ) {
            $isCollection = $false
            $typeName = switch ($this.type) {
                'Singleton' {
                    $schema.type
                }
                'EntityType' {
                    $::.Entity |=> QualifyName $this.namespace $schema.name
                }
                'EntitySet' {
                    $isCollection = $true
                    $schema.entitytype
                }
                'Action' {
                    if ( $schema | gm ReturnType ) {
                        write-verbose "'$($this.name)' is an Action that should have no return type but it is specified to have a return type of $($schema.returntype.type)"
                        $schema.returntype.type
                    }
                }
                '__Scalar' {
                    $schema.name
                }
                '__Root' {
                    $schema.name
                }
                default {
                    throw "Unknown entity type $($this.type) for entity name $($this.name)"
                }
            }
            $typeData = [PSCustomObject]@{EntityTypeName=$typeName;IsCollection=$isCollection}
        }

        $typeData
    }

    static {
        function QualifyName($namespace, $name) {
            "{0}.{1}" -f $namespace, $name
        }

        function UnAliasQualifiedName($namespace, $namespaceAlias, $name) {
            if ( $namespaceAlias -and $name.contains('.') ) {
                $unqualified = $name -split '\.' | select -last 1
                $prefix = $name.substring(0, $name.length - $unqualified.length - 1)
                if ( $prefix -eq $namespaceAlias ) {
                    QualifyName $namespace $unqualified
                } else {
                    $name
                }
            } else {
                $name
            }
        }

        function GetEntityTypeDataFromTypeName($namespace, $namespaceAlias, $entityTypeName) {
            $isCollection = $false
            $scalarTypeName = if ($entityTypeName -match 'Collection\((?<typename>.+)\)') {
                $isCollection = $true
                $matches.typename
            } else {
                $entityTypeName
            }

            $canonicallyQualifiedTypeName = if ( $scalarTypeName ) {
                UnAliasQualifiedName $namespace $namespaceAlias $scalarTypeName
            }

            [PSCustomObject]@{EntityTypeName=$canonicallyQualifiedTypeName;IsCollection=$isCollection}
        }
    }
}
