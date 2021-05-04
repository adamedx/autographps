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


. (import-script common/ContextHelper)
. (import-script ../typesystem/TypeManager)
. (import-script ../typesystem/TypeSearcher)
. (import-script common/GraphStatisticsDisplayType)

function Measure-Graph {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(parametersetname='byname', valuefrompipelinebypropertyname=$true, position=0)]
        [Alias('Name')]
        $GraphName = $null,

        [switch] $Detailed
    )

    Enable-ScriptClassVerbosePreference

    $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $GraphName

    $typeSearcher = $::.TypeManager |=> Get $targetContext |=> GetTypeSearcher

    $indexClasses = 'Name', 'Property', 'NavigationProperty'

    if ( $Detailed.IsPresent ) {
        $indexClasses += 'Method'
    }

    $typeSearcher |=> GetTypeStatistics $indexClasses | foreach {
        $result = new-so GraphStatisticsDisplayType $_ $targetContext.Name

        if ( ! $Detailed.IsPresent ) {
            $result.EntityMethodCount = $null
        }

        $result
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Measure-Graph Name (new-so GraphParameterCompleter)
