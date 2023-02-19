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

[cmdletbinding(positionalbinding=$false)]
param(
    [parameter(position=0)]
    [string] $TestRoot = 'test',

    [string] $TestAppId,

    [string] $TestAppTenant,

    [string] $CIBase64TestAppCert,

    [HashTable] $TestParamsPassThru
)

Set-StrictMode -Version 2

. "$psscriptroot/../../build/common-build-functions.ps1"

$baseDirectory = Get-SourceRootDirectory

$targetRoot = if ( $TestRoot ) {
    join-path $baseDirectory $TestRoot
} else {
    $baseDirectory
}

if ( ! ( Test-Path $targetRoot ) ) {
    throw "Specified subdirectory '$targetRoot' could not be found under '$baseDirectory' -- the path '$targetRoot' is not valid."
}

# Use -Force since dot directories like .test are "hidden" on *nix without it.
$targetRootPath = (get-item -Force $targetRoot).FullName

write-verbose "Preparing to execute integration tests under directory '$targetRootPath'..."

& $psscriptroot/../../build/Init-DirectTestRun.ps1

$appCert = if ( $CIBase64TestAppCert ) {
    write-verbose "CI pipeline test application credential was specified"
    & $psscriptroot/Get-CIPipelineCredential.ps1 $CIBase64TestAppCert
} else {
    write-verbose "No CI pipeline credential was specified, local configuration will be used for test app credential"
}

$testParams = @{}

if ( $TestAppId ) {
    $testParams['TestAppId'] = $TestAppId
}

if ( $TestAppTenant ) {
    $testParams['TestAppTenant'] = $TestAppTenant
}

if ( $appCert ) {
    $testParams['TestAppCertificate'] = $appCert
}

& $psscriptroot/../Initialize-IntegrationTestEnvironment.ps1 @testParams

Invoke-Pester -Script $targetRootPath @TestParamsPassThru

