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

ScriptClass ArgumentCompletionHelper {
    static {
        $__ArgumentCompleters = @{}

        function __RegisterArgumentCompleterScriptBlock([ScriptBlock] $argumentCompleter, $completionType) {
            $this.__ArgumentCompleters.Add($completionType, $argumentCompleter)
        }

        function __GetCompleter($completionType) {
            $completerBlock = $this.__ArgumentCompleters[$completionType]

            if ( ! $completerBlock ) {
                throw [ArgumentException]::new("Unknown ArgumentCompletionType '{0}'" -f $completionType)
            }

            $completerBlock
        }

        function RegisterArgumentCompleter([string] $command, [string[]] $parameterNames, $completionType) {
            $completerBlock = __GetCompleter $completionType
            $parameterNames | foreach {
                Register-ArgumentCompleter -commandname $command -ParameterName $_ -ScriptBlock $completerBlock
            }
        }

        function FindMatchesStartingWith($target, $sortedItems) {
            $sortedItemsCollection = try {
                if ( $sortedItems.Count -eq 0 ) {
                    return $null
                }
                $sortedItems
            } catch [System.Management.Automation.PropertyNotFoundException] {
                # Don't assign an array / collection of size 1 here as PowerShell
                # converts this to a non-array / collection! Do it outside the catch
            }

            # This happens if $sortedItems is not an array, i.e. it is
            # just one string.
            if ( ! $sortedItemsCollection ) {
                $sortedItemsCollection = @($sortedItems)
            }

            $matchingItems = @()
            $lastMatch = $null

            $interval = $sortedItemsCollection.Count / 2
            $current = $interval / 2
            $previous = -1

            if ( $target.length -ne 0 ) {
                while ( [int] $previous -ne [int] $current ) {
                    $interval /= 2
                    $previous = $current
                    $item = $sortedItemsCollection[[int]$current]

                    $comparison = $target.CompareTo($item)

                    if ( $comparison -gt 0 ) {
                        $current += $interval
                    } else {
                        if ( $item.StartsWith($target) ) {
                            $lastMatch = [int] $current
                        }
                        $current -= $interval
                    }
                }
            } else {
                $lastMatch = 0
            }

            if ( $lastMatch -ne $null ) {
                for ( $startsWithCandidate = $lastMatch; $startsWithCandidate -lt $sortedItemsCollection.Count; $startsWithCandidate++ ) {
                    $candidate = $sortedItemsCollection[$startsWithCandidate]
                    if ( ! $candidate.StartsWith($target) ) {
                        break
                    }

                    $matchingItems += $candidate
                }
            }

            $matchingItems
        }
    }
}
