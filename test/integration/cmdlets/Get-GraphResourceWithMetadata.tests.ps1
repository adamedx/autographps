# Copyright 2023, Adam Edwards
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

if ( ! ( & $psscriptroot/../../IsIntegrationTestRun.ps1 ) ) {
    return
}

Describe "The Get-GraphResourceWithMetadata command executing unmocked" {

    Set-StrictMode -Version 2
    $erroractionpreference = 'stop'
    
    Context "when invoked for simple use cases" {
        BeforeAll {
            Connect-GraphApi -Connection $global:__IntegrationTestGraphConnection | out-null
            $organizationId = (get-graphconnection -current).identity.tenantdisplayid
        }

        It "should succeed when issuing a request for the organization object" {
            $actualOrganization = Get-GraphResourceWithMetadata /organization
            $actualOrganization.Id | Should Be $organizationId
            $actualOrganization.displayName.Length | Should BeGreaterThan 0
        }

        It "should have metadata for the output of a request for the organization object" {
            $graphName = Get-Graph -current | select-object -ExpandProperty Name
            $actualOrganization = Get-GraphResourceWithMetadata /organization
            $uriMetadata = $actualOrganization | Get-GraphUri
            $urIMetadata.OriginalString | Should Be "/$($graphName):/organization/$organizationid"
        }

    }
}
