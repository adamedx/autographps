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

enum GraphUriCompletionType {
    AnyUri
    LocationOrMethodUri
    LocationUri
}

ScriptClass GraphUriParameterCompleter {
    $uriCompletionType = $null
    $nonLocatable = $false
    $includeVirtual = $false

    function __initialize([GraphUriCompletionType] $uriCompletionType) {
        $this.uriCompletionType = $uriCompletionType

        switch ($this.uriCompletionType) {
            ([GraphUriCompletionType]::AnyUri) {
                $this.nonLocatable = $true
                $this.includeVirtual = $true
            }
            ([GraphUriCompletionType]::LocationOrMethodUri) {
                $this.nonLocatable = $true
                $this.includeVirtual = $false
            }
            ([GraphUriCompletionType]::LocationUri) {
                $this.nonLocatable = $false
                $this.includeVirtual = $false
            }
        }
    }

    function CompleteCommandParameter {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        __GetUriCompletions $wordToComplete $this.nonLocatable $this.includeVirtual
    }

    function __GetUriCompletions([uri] $targetUri, [bool] $nonLocatable=$false, [bool] $includeVirtual=$false) {
        $uriString = $targetUri.tostring()
        $lastWord = $uriString -split '/' | select -last 1

        $parentUri = $uriString.substring(0, $uriString.length - $lastword.length).trimend('/')

        $candidateUris = Get-GraphUriInfo $parentUri -children -includevirtualchildren:$includeVirtual -LocatableChildren:(!$nonLocatable) -ignoremissingmetadata

        $fullParent = $null
        $completions = if ( $candidateUris ) {
            $sample = $candidateUris[0].graphuri.originalstring
            $fullParent = $sample.substring(0, $sample.lastindexof('/'))
            $candidates = $candidateUris |
              select -expandproperty graphuri |
              select -expandproperty originalstring |
              foreach {
                  $_ -split '/' | select -last 1
              }

            $::.ParameterCompleter |=> FindMatchesStartingWith $lastword $candidates
        }

        $completions | foreach {
            $fullParent, $_ -join '/'
        }
    }
}
