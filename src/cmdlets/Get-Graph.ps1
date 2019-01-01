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

. (import-script common/ContextHelper)
. (import-script common/GraphParameterCompleter)

function Get-Graph {
    [cmdletbinding(DefaultParameterSetName='byname')]
    param(
        [parameter(parametersetname='byname', position=0)]
        $Graph = $null,

        [parameter(parametersetname='current')]
        [Switch] $Current
    )

    $targetGraph = if ( $Current.IsPresent ) {
        ($::.GraphContext |=> GetCurrent).name
    } else {
        $Graph
    }

    $graphContexts = $::.LogicalGraphManager |=> Get |=> GetContext

    $results = $graphContexts |
      where { ! $targetGraph -or $_.name -eq $targetGraph } | foreach {
          $::.ContextHelper |=> ToPublicContext $_
      }

    if ( $targetGraph ) {
        $results | select *
    } else {
        $results
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-Graph Graph (new-so GraphParameterCompleter)
