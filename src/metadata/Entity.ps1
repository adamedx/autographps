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
    $namespace = $null
    $name = $null
    $type = $null
    $typeData = $null
    $navigations = $null

    function __initialize($schema, $namespace) {
        $this.namespace = $namespace

        $schemaElement = $schema | select -first 1
        $this.type = $schemaElement | select -expandproperty localname
        $this.name = $schemaElement | select -first 1 | select -expandproperty name
        $this.typeData = GetEntityTypeData $schema
        $this.navigations = if ( ($schema | gm navigationproperty) -ne $null ) {
            $schema.navigationproperty | foreach {
                [PSCustomObject]@{LocalName=$_.localname;Name=$_.name;Type=$_.type}
            }
        }
    }

    function GetEntityId {
        '{0}:{1}:{2}' -f $this.type, $this.namespace, $this.name
    }

    function GetEntityTypeData($schema) {
        $typeData = switch ($this.type) {
            'NavigationProperty' {
                $this.scriptclass |=> GetEntityTypeDataFromTypeName $schema.type
            }
            'NavigationPropertyBinding' {
                $this.scriptclass |=> GetEntityTypeDataFromTypeName $schema.parameter.bindingparameter.type
            }
            'Function' {
                $this.scriptclass |=> GetEntityTypeDataFromTypeName $schema.ReturnType
            }
        }

        if ( ! $typeData ) {
            $typeName = switch ($this.type) {
                'Singleton' {
                    $schema.type
                }
                'EntityType' {
                    $::.Entity |=> QualifyName $this.namespace $schema.name
                }
                'EntitySet' {
                    $schema.entitytype
                }
                'Action' {
                    if ( $schema | gm ReturnType ) {
                        write-verbose "'$($this.name)' is an Action that should have no return type but it is specified to have a return type of $($schema.returntype.type)"
                        $schema.returntype.type
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
