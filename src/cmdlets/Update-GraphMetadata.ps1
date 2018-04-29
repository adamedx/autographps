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

. (import-script ..\metadata\GraphContext)

function Update-GraphMetadata {
    [cmdletbinding()]
    param(
        [string] $Version = 'v1.0',

        [PSCustomObject] $Connection,
        [parameter(parametersetname='Path', mandatory=$true)]
        $Path = $null,

        [parameter(parametersetname='Data', valuefrompipeline=$true)]
        $SchemaData,

        [switch] $Force,
        [switch] $Wait
    )

    $metadata = if ( $Path ) {
        [xml] (get-content $Path | out-string)
    }

    $endpoint = if ($connection) {
        $connection.GraphEndpoint.graph
    }

    $context = $::.GraphContext |=> GetFromConnection $connection $version

    $context |=> UpdateGraph $metadata $wait.ispresent $force.ispresent
}
