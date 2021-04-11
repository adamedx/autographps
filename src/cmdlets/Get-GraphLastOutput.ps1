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

ScriptClass __GraphIndexedResult {
    $__Index = $null
}

function Get-GraphLastOutput {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='all')]
    param(
        [parameter(position=0, parametersetname='index', mandatory=$true)]
        [int]
        $Index,

        [parameter(parametersetname='last', mandatory=$true)]

        [int]
        $Last,

        [parameter(parametersetname='first', mandatory=$true)]
        [int]
        $First,

        [ArgumentCompleter({
        param ( $commandName,
                $parameterName,
                $wordToComplete,
                $commandAst,
                $fakeBoundParameters )
                               if ( get-variable LASTGRAPHITEMS -erroraction ignore ) {
                                   if ( $LASTGRAPHITEMS -and ($LASTGRAPHITEMS | measure-object).count -gt 0 ) {
                                       $target = if ( $LASTGRAPHITEMS[0].pstypenames -contains 'GraphSegmentDisplayType' -and ( $LASTGRAPHITEMS[0] | gm content -erroraction ignore ) ) {
                                           $LASTGRAPHITEMS[0].Content
                                       } else {
                                           $LASTGRAPHITEMS
                                       }
                                       $target | get-member -membertype noteproperty | where name -like "$wordToComplete*" | foreach { $_.name }
                                   }
                               }
                           })]
        [string[]] $Property
    )

    $parameterset = $pscmdlet.parametersetname

    $lastItemsVariable = get-variable LASTGRAPHITEMS -erroraction ignore

    if ( $lastItemsVariable -and ( $lastItemsVariable.value | measure-object ).count -gt 0 ) {
        $lastResults = $lastItemsVariable.Value
        $resultCount = ( $lastResults | measure-object ).count

        $startIndex = 0
        $lastIndex = $resultCount - 1

        if ( $parameterset -eq 'index' ) {
            $startIndex = $Index
            $lastIndex = $Index
        } elseif ( $parameterset -eq 'last' ) {
            $startIndex = $resultCount - $Last
        } elseif ( $parameterset -eq 'first' ) {
            $lastIndex = $First - 1
        } elseif ( $parameterset -ne 'all' ) {
            throw "Unexpected parameter set '$parameterset' encountered"
        }

        $isContent = ! $lastResults[0].pstypenames.contains('GraphSegmentDisplayType')

        $propertySelection = if ( $Property ) {
            @{Property = ( @('Index') + $Property )}
        }

        for ( $currentResult = $startIndex; $currentResult -le $lastIndex; $currentResult++ ) {
            $content = if ( $isContent -or ! ( $lastResults[0] | gm content -erroraction ignore ) -or ! ( $lastResults[0].Content ) ) {
                $lastResults[$currentResult]
            } else {
                $lastResults[$currentResult].Content
            }

            $output = $content.psobject.copy()

            if ( ! $Property ) {
                $output | Add-Member -Name __ResultIndex -MemberType ScriptMethod -Value ([ScriptBlock]::Create($currentResult.tostring()))

                $output.pstypenames.insert(0, 'GraphLastResultType')
            } else {
                $output = $output | select-object @propertySelection
                $output.Index = $currentResult
            }

            $output
        }
    }
}
