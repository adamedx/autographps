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

. (import-script common/ContextHelper)

function New-Graph {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='Simple')]
    param(
        [parameter(position=0)]
        $Version = 'v1.0',

        [parameter(position=1)]
        $Name = $null,

        [parameter(position=2, parametersetname='Cloud')]
        [parameter(position=2, parametersetname='Authenticated')]
        [parameter(position=2, parametersetname='Connection')]
        [parameter(position=2, parametersetname='Simple')]
        [String[]] $Permissions = @('User.Read'),

        [parameter(parametersetname='Cloud', mandatory=$true)]
        [parameter(parametersetname='Authenticated')]
        [parameter(parametersetname='Simple')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='Cloud')]
        [Switch] $Anonymous,

        [parameter(parametersetname='Connection', mandatory=$true)]
        $Connection = $null
    )

    $graphConnection = if ( $Connection ) {
        $Connection
    } else {
        $::.GraphConnection |=> NewSimpleConnection ([GraphType]::MSGraph) $Cloud $Permissions $Anonymous.IsPresent
    }

    $context = $::.LogicalGraphManager |=> Get |=> NewContext $null $graphConnection $Version $Name

    $::.GraphManager |=> UpdateGraph $context

    $::.ContextHelper |=> ToPublicContext $context
}
