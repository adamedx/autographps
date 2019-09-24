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

function New-Graph {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='Simple')]
    param(
        [parameter(position=0)]
        $Version = 'v1.0',

        [parameter(position=1)]
        $Name = $null,

        [parameter(parametersetname='Connection', mandatory=$true)]
        $Connection = $null
    )

    Enable-ScriptClassVerbosePreference

    $graphConnection = if ( $Connection ) {
        $Connection
    } else {
        ($::.GraphContext |=> GetCurrent).connection
    }

    $context = $::.LogicalGraphManager |=> Get |=> NewContext $null $graphConnection $Version $Name

    $::.GraphManager |=> UpdateGraph $context

    $::.ContextHelper |=> ToPublicContext $context
}
