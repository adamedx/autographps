# Copyright (c) Adam Edwards
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


Describe 'The New-Graph cmdlet' {
    BeforeEach {
        Get-Graph | Remove-Graph -warningaction silentlycontinue 3>&1 | out-null
    }

    AfterEach {
        Get-Graph | Remove-Graph -warningaction silentlycontinue 3>&1 | out-null
    }

    Context 'When invoking the New-Graph command' {
        $referenceMetadataPath = "$psscriptroot/../../test/assets/betametadata-ns-alias-2020-01-23.xml"
        $differenceMetadataPath = "$psscriptroot/../../test/assets/betametadata-ns-alias-multi-namespace-2020-03-25.xml"

        $expectedTypeDiff = @'
[
  {
    "InputObject": "microsoft.graph.appscope",
    "SideIndicator": "<="
  },
  {
    "InputObject": "microsoft.graph.grouppolicyobjectfile",
    "SideIndicator": "<="
  },
  {
    "InputObject": "microsoft.graph.rbacapplicationmultiple",
    "SideIndicator": "<="
  },
  {
    "InputObject": "microsoft.graph.unifiedroleassignmentmultiple",
    "SideIndicator": "<="
  }
]
'@ | ConvertFrom-Json

        $incorrectTypeDiff = @'
[
  {
    "InputObject": "microsoft.graph.appscope",
    "SideIndicator": "<="
  },
  {
    "InputObject": "microsoft.graph.grouppolicyobjectfile",
    "SideIndicator": "<="
  },
  {
    "InputObject": "microsoft.graph.unifiedroleassignmentmultiple",
    "SideIndicator": "<="
  }
]
'@ | ConvertFrom-Json

        It "Should throw an exception if a new graph is created with the same name as an existing graph" {

            $originalGraph = new-graph originalGraph

            { $duplicatedNameGraph = new-graph $originalGraph.Name } | Should Throw
        }

        It "Should return the correct difference between two graphs mounted from local metadata" {

            write-host 'starting difference test'
            $referenceGraph = new-graph -SchemaUri $ReferenceMetadataPath
            write-host 'created reference graph'
            $differenceGraph = new-graph -SchemaUri $DifferenceMetadataPath
            write-host 'created difference graph'

            $referenceTypes = Get-GraphType -list -GraphName $referenceGraph.Name
            write-host 'got reference types'
            $differenceTypes = Get-GraphType -list -Graphname $differenceGraph.Name
            write-host 'got difference types'

            ( $referenceTypes | measure-object ).Count | Should Be 1036
            ( $differenceTypes | measure-object ).Count | Should Be 1032
            write-host 'obtained correct counts'

            $actualTypeDiff = Compare-Object $referenceTypes $differenceTypes
            write-host 'created actual diff'

            Compare-Object $actualTypeDiff $incorrectTypeDiff | Should Not Be $null
            write-host 'compared against incorrect diff'
            Compare-Object $actualTypeDiff $expectedTypeDiff | Should Be $null
            write-host 'compared against actual diff'
        }
    }
}
