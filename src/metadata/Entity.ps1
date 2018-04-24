# Copyright 2018, Adam Edwards
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
    $schema = $null
    $namespace = $null
    $name = $null
    $type = $null
    function __initialize($schema, $namespace) {
        $this.schema = $schema
        $this.namespace = $namespace

        $schemaElement = $schema | select -first 1
        $this.type = $schemaElement | select -expandproperty localname
        $this.name = $schemaElement | select -first 1 | select -expandproperty name
    }

    function GetEntityId {
        '{0}:{1}:{2}' -f $this.type, $this.namespace, $this.name
    }

    function GetEntityTypeData {
        $typeData = switch ($this.type) {
            'NavigationProperty' {
                $this.scriptclass |=> GetEntityTypeDataFromTypeName $this.schema.type
            }
            'NavigationPropertyBinding' {
                $this.scriptclass |=> GetEntityTypeDataFromTypeName $this.schema.parameter.bindingparameter.type
            }
            'Function' {
                $this.scriptclass |=> GetEntityTypeDataFromTypeName $this.schema.ReturnType
            }
        }

        if ( ! $typeData ) {
            $typeName = switch ($this.type) {
                'Singleton' {
                    $this.schema.type
                }
                'EntityType' {
                    $::.Entity |=> QualifyName $this.namespace $this.schema.name
                }
                'EntitySet' {
                    $this.schema.entitytype
                }
                'Action' {
                    if ( $this.schema | gm ReturnType ) {
                        write-verbose "'$($this.name)' is an Action that should have no return type but it is specified to have a return type of $($this.schema.returntype.type)"
                        $this.schema.returntype.type
                    }
                }
                default {
                    throw "Unknown entity type $($this.type) for entity name $($this.name)"
                }
            }
            $typeData = [PSCustomObject]@{EntityTypeName=$typeName;IsCollection=$false}
        }

        $typeData
    }

    static {
        function QualifyName($namespace, $name) {
            "{0}.{1}" -f $namespace, $name
        }

        function GetEntityTypeDataFromTypeName($entityTypeName) {
            $isCollection = $false
            $scalarTypeName = if ($entityTypeName -match 'Collection\((?<typename>.+)\)') {
                $isCollection = $true
                $matches.typename
            } else {
                $entityTypeName
            }

            [PSCustomObject]@{EntityTypeName=$scalarTypeName;IsCollection=$isCollection}
        }
    }
}
