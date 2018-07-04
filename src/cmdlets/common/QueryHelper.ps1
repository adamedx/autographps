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

ScriptClass QueryHelper {
    static {
        function GetOrderQueryFromOrderByParameters($orderByParameters, [bool] $descendingDefault) {
            $sortColumns = switch($OrderByParameters.Gettype().name) {
                'String' { @{$orderByParameters=$false} }
                'HashTable' { $orderByParameters }
                'object[]' {
                    $normalized = @{}
                    $orderByParameters | foreach {
                        $normalized.Add($_, $descendingDefault)}
                    $normalized
                }
                default {
                    throw [ArgumentException]::new("OrderBy parameter was of invalid type '$_'. It must be of type 'String', 'String[]', or else a 'HashTable' structured like @{columname1=`$false|`$true;columname2=`$false|`$true} where `$false` indicates ascending order, `$true` descending")
                }
            }

            $columnEntries = $sortColumns.keys | foreach {
                if ( $_ -isnot [string] ) {
                    throw [ArgumentException]::new("Specified sort column '$($_.tostring())' was of type '$($_.gettype())' instead of type 'String'")
                }
                $isDescending = $sortColumns[$_]

                if ( $isDescending -isnot [bool] ) {
                    throw [ArgumentException]::new("Specified sort column '$($_.tostring())' was assigned invalid type '$($isDescending.gettype())' for direction -- it must be of type 'bool'")
                }
                $direction = if ( $isDescending ) { 'desc' } else { '' }
                '{0} {1}' -f $_, $direction
            }

            $columnEntries -join ','
        }
    }
}
