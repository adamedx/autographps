# Copyright 2021, Adam Edwards
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

ScriptClass GraphStatisticsDisplayType {
    # Note that the display format for this type is managed
    # by a format xml file elsewhere in this module rather
    # than directly by this class

    $EntityTypeCount = $null
    $EntityPropertyCount = $null
    $EntityRelationshipCount = $null
    $EntityMethodCount = $null
    $EnumerationTypeCount = $null
    $EnumerationValueCount = $null
    $ComplexTypeCount = $null
    $ComplexPropertyCount = $null
    $EnumerationTypeCount = $null
    $EnumerationValueCount = $null
    $GraphName = $null

    function __initialize($statistics, $graphName) {
        $this.EntityTypeCount = $statistics.EntityCount
        $this.EntityPropertyCount = $statistics.EntityPropertyCount
        $this.ComplexTypeCount = $statistics.ComplexCount
        $this.ComplexPropertyCount = $statistics.ComplexPropertyCount
        $this.EnumerationTypeCount = $statistics.EnumerationCount
        $this.EnumerationValueCount = $statistics.EnumerationValueCount
        $this.EntityRelationshipCount = $statistics.EntityNavigationPropertyCount
        $this.EntityMethodCount = $statistics.MethodCount
        $this.GraphName = $graphName
    }
}

