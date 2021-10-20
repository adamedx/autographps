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

. (import-script ../metadata/GraphManager)

function Update-GraphMetadata {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='GraphTarget')]
    param(
        [parameter(position=0, parametersetname='Path', mandatory=$true)]
        $Path = $null,

        [parameter(valuefrompipelinebypropertyname=$true, parametersetname='GraphTarget')]
        [Alias('Name')]
        [String]
        $GraphName,

        [parameter(parametersetname='Data', valuefrompipeline=$true)]
        [String] $SchemaData,

        [switch] $Force,

        [switch] $Wait
    )

    Enable-ScriptClassVerbosePreference

    $metadata = if ( $Path ) {
        [xml] (get-content $Path | out-string)
    } elseif ( $SchemaData ) {
        [xml] $SchemaData
    }

    $context = if ( $GraphName ) {
        $::.LogicalGraphManager |=> Get |=> GetContext $GraphName
    } else {
        $::.GraphContext |=> GetCurrent
    }

    $::.GraphManager |=> UpdateGraph $context $metadata $wait.ispresent $force.ispresent $Path
}
