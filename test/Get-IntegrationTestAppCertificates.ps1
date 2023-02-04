# Copyright 2022, Adam Edwards
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

[cmdletbinding()]

if ( ! $psscriptroot/IsIntegrationTestRun.ps1 ) {
    throw 'Unable to get integration test certificates because this is not an integration test run.'
}

if ( $__CI_PIPELINE ) {
    if ( ! $__CI_PIPELINE_CERT_PATH ) {
        throw 'No certificate path for the CI pipeline is defined'
    }

    $certData = Get-Content $__CI_PIPELINE_CERT_PATH -ErrorAction Stop

    $ciCredential = $psscriptroot/CI/Get-CIPipelineCredential.ps1

    if ( ! $ciCredential ) {
        throw 'The CI pipeline credential is null / empty.'
    }

    [PSCustomObject] @{
        AppCert = $ciCredential
    }
} else {
    if ( ! $__LOCAL_TEST_CERT_PATH ) {
        throw "The local development PowerShell session is configured for integration tests with __IntegrationTestRoot variable set to to the non-empty value '$__IntegrationTestRoot' but the __LOCAL_TEST_CERT_PATH variable is not defined. Set this variable to a valid file system or certificate store path and retry the operation, or clear / delete the __IntegrationTestRoot variable to skip the attempt to run integration tests altogether."
    }
    $localTestCredential = Get-Item $__LOCAL_TEST_CERT_PATH -ErrorAction Stop

    [PSCustomObject] @{
        AppCert = $localTestCredential
    }
}
