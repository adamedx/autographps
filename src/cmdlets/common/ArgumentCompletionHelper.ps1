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

enum ArgumentCompletionType {
    AnyUri
    LocationOrMethodUri
    LocationUri
}

ScriptClass ArgumentCompletionHelper {
    static {
        $LocationUriArgumentCompleter = {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            $::.ArgumentCompletionHelper |=> __UriArgumentCompleter $commandName $parameterName $wordToComplete $commandAst $fakeBoundParameter $false $false
        }

        $LocationOrMethodUriArgumentCompleter = {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            $::.ArgumentCompletionHelper |=> __UriArgumentCompleter $commandName $parameterName $wordToComplete $commandAst $fakeBoundParameter $true $false
        }

        $AnyUriArgumentCompleter = {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            $::.ArgumentCompletionHelper |=> __UriArgumentCompleter $commandName $parameterName $wordToComplete $commandAst $fakeBoundParameter $true $true
        }

        function __UriArgumentCompleter($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter, $nonlocatable, $includeVirtual) {
            $graphUri =  $::.GraphUtilities |=> ToGraphRelativeUri $wordToComplete

            $::.ArgumentCompletionHelper |=> __GetUriCompletions $graphUri $nonLocatable $includeVirtual
        }

        function RegisterArgumentCompleter([string] $command, [string[]] $parameterNames, [ArgumentCompletionType] $completionType) {
            $completerBlock = switch ( $completionType ) {
                ([ArgumentCompletionType]::AnyUri) { $::.ArgumentCompletionHelper.AnyUriArgumentCompleter }
                ([ArgumentCompletionType]::LocationOrMethodUri) { $::.ArgumentCompletionHelper.LocationOrMethodUriArgumentCompleter }
                ([ArgumentCompletionType]::LocationUri) { $::.ArgumentCompletionHelper.LocationUriArgumentCompleter }
                default {
                    throw [ArgumentException]::new("Unknown ArgumentCompletionType '{0}'" -f $completionType)
                }
            }

            $parameterNames | foreach {
                Register-ArgumentCompleter -commandname $command -ParameterName $_ -ScriptBlock $completerBlock
            }
        }

        function __GetUriCompletions([uri] $targetUri, [bool] $nonLocatable=$false, [bool] $includeVirtual=$false) {
            $uriString = $targetUri.tostring()
            $lastWord = $uriString -split '/' | select -last 1

            $parentUri = '/' + $uriString.substring(0, $uriString.length - $lastword.length).trimend('/').trimstart('/')
            $candidates = Get-GraphUri $parentUri -children -includevirtualchildren:$includeVirtual -LocatableChildren:(!$nonLocatable) -ignoremissingmetadata |
              select -expandproperty graphuri |
              select -expandproperty originalstring |
              foreach {
                $_ -split '/' | select -last 1
              }

            $completions = if ( $candidates ) {
                FindMatchesStartingWith $lastword $candidates
            }

            $prefixableParentUri = $parentUri.trimend('/')
            $completions | foreach {
                $prefixableParentUri, $_ -join '/'
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

            $interval = [int] ( $sortedItemsCollection.Count / 2 )
            $current = $interval
            $previous = -1

            if ( $target.length -ne 0 ) {
                while ( $previous -ne $current ) {
                    $interval = [int] ($interval / 2)
                    $previous = $current
                    $item = $sortedItemsCollection[$current]

                    $comparison = $target.CompareTo($item)
                    if ( $comparison -gt 0 ) {
                        $current += $interval
                    } else {
                        if ( $item.StartsWith($target) ) {
                            $lastMatch = $current
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
