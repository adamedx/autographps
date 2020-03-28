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

# This test assumes the module has been imported

Describe 'The Get-GraphResourceWithMetadata cmdlet' {
    $expectedUserPrincipalName = 'searchman@megarock.org'
    $global:meResponseDataExpected = '"@odata.context":"https://graph.microsoft.com/v1.0/$metadata#users/$entity","businessPhones":[],"displayName":"Search Man","givenName":null,"jobTitle":"Administrator","mail":null,"mobilePhone":null,"officeLocation":null,"preferredLanguage":null,"surname":null,"userPrincipalName":"{0}","id":"012345567-89ab-cdef-0123-0123456789ab"' -f $expectedUserPrincipalName
    $meResponseExpected = "{$meResponseDataExpected}"

    Context 'When making REST method calls to Graph' {
        ScriptClass MockToken {
            function CreateAuthorizationHeader {}
        }

        Mock Invoke-GraphRequest { "{$($global:meResponseDataExpected)}" | convertfrom-json } -modulename autographps

        Add-MockInScriptClassScope RESTRequest Invoke-WebRequest {
            [PSCustomObject] @{
                RawContent = $MockContext
                RawContentLength = $MockContext.length
                Content = $MockContext
                StatusCode = 200
                StatusDescription = 'OK'
                Headers = @{'Content-Type'='application/json'}
            }
        } -MockContext @{
            expectedUserPrincipalName = $expectedUserPrincipalName
            meResponseDataExpected = $meResponseDataExpected
            meResponseExpected = $meResponseExpected
        }

        # Need to mock this or we end up trying to parse Uris with metadata
        Mock-ScriptClassMethod -static GraphManager GetMetadataStatus {
            0 # ([MetadataStatus]::NotStarted)
        }

        It 'Should return an object with the expected user principal when given the argument me' {
            $meResponse = Get-GraphResourceWithMetadata me 3> $null
            $meResponse[0].content.userPrincipalName | Should Be $expectedUserPrincipalName
            $meResponse.Preview | Should Be 'Search Man'
        }
    }
}
