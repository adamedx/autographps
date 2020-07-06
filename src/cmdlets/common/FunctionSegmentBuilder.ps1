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

ScriptClass FunctionSegmentBuilder {
    $functionName = $null

    function __initialize($functionName) {
        if ( ! $this.functionName ) {
            throw [ArgumentException]::new('A method name was not specified')
        }
        $this.functionName = $functionName
    }

    static {
        function ToUriParameterString($parameterObject) {
            $parameterNames = $null
            $values = $null

            if ( $parameterObject -is [HashTable] ) {
                $parameterNames = $parameterObject.keys
                $values = $parameterObject.Values
            } else {
                $parameterNames = $parameterObject | gm -membertype -noteproperty | select -expandproperty name
                $values = $parameterNames | foreach { $parameterObject.$_ }
            }

            $parameters = if ( $parameterNames ) {
                $valueIndex = 0
                foreach ( $parameterName in $parameterNames ) {
                    $parameterJson = $values[$valueIndex++] | convertto-json -depth 1
                    $parameterValue = $parameterJson -replace '"', "'"
                    "$parameterName = $parameterValue"
                }
            }

            '({0})' -f $parameters -join ', '
        }
    }
}
