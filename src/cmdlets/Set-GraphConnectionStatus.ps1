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


. (import-script ../GraphContext)
. (import-script ../LogicalGraphManager)

function Set-GraphConnectionStatus {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0, mandatory=$true)]
        [GraphConnectionStatus] $Status,

        [parameter(valuefrompipeline=$true)]
        $Graph
    )

    $context = if ( $Graph ) {
        if ( $Graph -is [String] ) {
            $specificContext = $::.LogicalGraphManager |=> Get |=> GetContext $Graph
            if (! $specificContext ) {
                throw "The specified Graph '$Graph' could not be found"
            }
        } elseif ( $graph | gm Details -erroraction silentlycontinue ) {
            $Graph.details
        } else {
            throw "Specified Graph argument '$Graph' is not a valid type returned by Get-Graph"
        }
    } else {
        $::.GraphContext |=> GetCurrent
    }

    $context.connection |=> SetStatus $Status
}
