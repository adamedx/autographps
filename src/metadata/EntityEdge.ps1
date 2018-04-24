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

. (import-script Entity)

ScriptClass EntityEdge {
    $sink = $null
    $source = $null
    $transition = $null
    $oneToMany = $null
    $name = $null

    function __initialize($source, $sink, $transition) {
        if ( $source |=> IsNull ) {
            throw "An edge with a null source is not valid"
        }

        $this.sink = $sink
        $this.source = $source
        $this.transition = $transition

        $typeData = $transition |=> GetEntityTypeData
        $this.oneToMany = $typeData.isCollection

        $this.name = if ( $transition.type -eq 'NavigationPropertyBinding' ) {
            $transition.Path
        } elseif ( $transition.type -eq 'NavigationProperty' -or $transition.type -eq 'Action' -or $transition.type -eq 'Function' ) {
            $transition.name
        } else {
            throw "Unknown entity element $($transition.localname)"
        }

        $this.scriptclass.count = $this.scriptclass.count + 1
    }

    static {
        $count = 0
    }
}
