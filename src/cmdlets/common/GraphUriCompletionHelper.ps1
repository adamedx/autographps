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

. (import-script ArgumentCompletionHelper)

enum GraphUriCompletionType {
    AnyUri
    LocationOrMethodUri
    LocationUri
}

ScriptClass GraphUriCompletionHelper {
    static {
        $base = $::.ArgumentCompletionHelper

        function __initialize() {
            $this.base |=> __RegisterArgumentCompleterScriptBlock $this.AnyUriArgumentCompleter ([GraphUriCompletionType]::AnyUri)
            $this.base |=> __RegisterArgumentCompleterScriptBlock $this.LocationOrMethodUriArgumentCompleter ([GraphUriCompletionType]::LocationOrMethodUri)
            $this.base |=> __RegisterArgumentCompleterScriptBlock $this.LocationUriArgumentCompleter ([GraphUriCompletionType]::LocationUri)
        }

        $LocationUriArgumentCompleter = {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            $::.GraphUriCompletionHelper |=> __UriArgumentCompleter $commandName $parameterName $wordToComplete $commandAst $fakeBoundParameter $false $false
        }

        $LocationOrMethodUriArgumentCompleter = {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            $::.GraphUriCompletionHelper |=> __UriArgumentCompleter $commandName $parameterName $wordToComplete $commandAst $fakeBoundParameter $true $false
        }

        $AnyUriArgumentCompleter = {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            $::.GraphUriCompletionHelper |=> __UriArgumentCompleter $commandName $parameterName $wordToComplete $commandAst $fakeBoundParameter $true $true
        }

        function __UriArgumentCompleter($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter, $nonlocatable, $includeVirtual) {
            $graphUri =  $::.GraphUtilities |=> ToGraphRelativeUri $wordToComplete

            __GetUriCompletions $graphUri $nonLocatable $includeVirtual
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
                $this.base |=> FindMatchesStartingWith $lastword $candidates
            }

            $prefixableParentUri = $parentUri.trimend('/')
            $completions | foreach {
                $prefixableParentUri, $_ -join '/'
            }
        }
    }
}

$::.GraphUriCompletionHelper |=> __initialize
