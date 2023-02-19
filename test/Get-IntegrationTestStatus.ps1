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
param([string] $TestConfigDirectoryPath)

Set-StrictMode -Version 2

$isIntegrationRun = & "$psscriptRoot/IsIntegrationTestRun.ps1"

$targetTestConfigDirectory = if ( $TestConfigDirectoryPath ) {
    $testConfigDirectoryPath
} else {
    $configParent = ( Get-Item "$psscriptroot/.." ).FullName
    join-path $configParent .testconfig
}

$testRunIdPathName = join-path $targetTestConfigDirectory 'TestRunId.txt'
$targetTestConfigPath = join-path $targetTestConfigDirectory 'TestConfig.json'

$testRunId = if ( test-path $testRunIdPathName ) {
    Get-Content $testRunIdPathName | out-string
} else {
    '__GLOBAL_AUTOGRAPH_INTEGRATION_TEST_RUN'
}

$testAppId = $null
$testAppTenant = $null
$testAppCertPath = $null
$graphConnection = ( Get-Variable -Scope Global __IntegrationTestGraphConnection -Value -ErrorAction Ignore )

if ( test-path $targetTestConfigPath ) {
    write-verbose "Reading test config at path '$targetTestConfigPath'"
    $config = get-content $targetTestConfigPath | out-string | ConvertFrom-json
    $testAppId = $config | select-object -expandproperty TestAppId -ErrorAction Ignore
    $testAppTenant = $config | select-object -expandproperty TestAppTenant -ErrorAction Ignore
    $testAppCertPath = $config | select-object -expandproperty TestAppCertificatePath -ErrorAction Ignore

    $certArg = if ( $testAppCertPath ) {
        @{CertificatePath = $testAppCertPath}
    }

    $newConnection = New-GraphConnection -AppId $testAppId -TenantId $testAppTenant @certArg -NoninteractiveAppOnlyAuth

    # Only alter the environment to synchronize it with the file contents -- if it isn't already set.
    if ( $graphConnection ) {
        write-verbose "Existing connection specified for __IntegrationTestGraphConnection, overriding with file contents for consistency"
        Set-Variable -Scope Global __IntegrationTestGraphConnection -Value $graphConnection
    }

    $graphConnection = $newConnection
} else {
    write-verbose "Skipping read of test config at path '$targetTestConfigPath' because it doesn't exist. Getting info from __IntegrationTestGraphConnection instead."

    if ( $graphConnection ) {
        Connect-GraphApi -Connection $graphConnection -NoSetCurrentConnection | out-null
        $testAppId = $graphConnection.Identity.App.AppId
        $testAppTenant = $graphConnection.Identity.TenantDisplayId
    }
}

[PSCustomObject] @{
    IsIntegrationRun = $isIntegrationRun
    ConfigurationPath = $targetTestConfigPath
    TestRunId = $testRunId
    TestRunIdPathName = $testRunIdPathName
    TestAppId = $testAppId
    TestAppTenant = $testAppTenant
    TestAppCertPath = $testAppCertPath
    GraphConnection = $graphConnection
}
