# Copyright 2017, Adam Edwards
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

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Poshgraph application" {
    $manifestLocation   = Join-Path $here 'poshgraph.psd1'
    $manifest = Test-ModuleManifest -Path $manifestlocation -ErrorAction Stop -WarningAction SilentlyContinue

    Context "When loading the manifest" {
        It "should export the exact same set of functions as are in the set of expected functions" {
            $expectedFunctions = @(
                'new-graphconnection',
                'get-graphitem',
                'test-graph',
                'invoke-graphrequest',
                'get-graphversion',
                'get-graphschema',
                'connect-graph',
                'disconnect-graph',
                'get-graphtoken')

            $manifest.ExportedFunctions.count | Should BeExactly $expectedFunctions.length

            $verifiedExportsCount = 0
            $expectedFunctions | foreach {
                if ( $manifest.exportedfunctions[$_] -ne $null ) {
                    $verifiedExportsCount++
                }
            }

            $verifiedExportsCount | Should BeExactly $expectedFunctions.length
        }
    }

    Context "When invoking the PoshGraph application" {
        BeforeEach {
            remove-module -force 'poshgraph' 2>$null
            import-module $manifestlocation -force
        }

        AfterEach {
            remove-module -force 'poshgraph' 2>$null
        }

        It "Should be able to create a connection object" {
            $connection = New-GraphConnection
        }
    }
}


