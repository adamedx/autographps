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

. (import-script ../metadata/GraphManager)

function Get-GraphType {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0)]
        $Name = $null,
        $Graph = $null,
        [Switch] $ComplexType
    )

    $context = if ( $Graph ) {
        $::.Logicalgraphmanager.Get().contexts[$Graph].context
    } else {
        $::.GraphContext |=> GetCurrent
    }

    if ( ! $context ) {
        throw "Unable to find specified context '$Graph'"
    }

    $entityGraph = $::.GraphManager |=> GetGraph $context

    if ( ! $ComplexType.IsPresent ) {
        $types = if ( $Name ) {
            $qualifiedName = $::.Entity |=> QualifyName $entityGraph.namespace $Name
            $entityGraph.builder.dataModel |=> GetEntityTypeByName $qualifiedName
        } else {
            $entityGraph.builder.dataModel |=> GetEntityTypes
        }

        if ( $name -and ! $types ) {
            throw "Graph entity type '$Name' was not found in Graph '$($context.name)'"
        }
        $types
    } else {
        $result = $entityGraph.builder.dataModel |=> GetComplexTypes $name
        if ( $Name -and ! $result ) {
            throw "Graph complex type '$Name' was not found in Graph '$($context.name)'"
        }
        $result
    }
}
