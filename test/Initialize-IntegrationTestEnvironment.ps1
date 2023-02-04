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

[cmdletbinding(positionalbinding=$false, defaultparametersetname='configfile')]
param(
    [string] $TestRoot,

    [parameter(parametersetname='configfile')]
    [string] $TestConfigPath,

    [parameter(parametersetname='explicit', mandatory=$true)]
    [string] $TestAppId,

    [parameter(parametersetname='explicit', mandatory=$true)]
    [string] $TestAppTenant,

    [parameter(parametersetname='explicit', mandatory=$true)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2] $TestAppCertificate,

    $GraphConnectionOverride
)

Set-StrictMode -Version 2

$global:__IntegrationTestInfo = $null

if ( ! ( Get-Command New-GraphConnection -erroraction ignore ) ) {
    throw "The 'New-GraphConnection' command could not be found. Please ensure that the module that contains the 'New-GraphConnection' command has been loaded into the session and retry the operation."
}

$global:__IntegrationTestRoot = if ( $TestRoot ) {
    $TestRoot
} else {
    $psscriptroot
}

$config = & $psscriptroot/Get-IntegrationTestStatus.ps1

$targetTestAppId = if ( $TestAppId ) {
    $TestAppId
} else {
    $config.TestAppId
}

$targetTestAppTenant = if ( $TestAppTenant ) {
    $TestAppTenant
} else {
    $config.TestAppTenant
}

$targetConnection = if ( $GraphConnectionOverride ) {
    $GraphConnectionOverride
} elseif ( $targetTestAppId -and $targetTestAppTenant ) {
    $certArgument = @{}
    if ( $TestAppCertificate ) {
        $certArgument.Add('Certificate', $TestAppCertificate)
    } elseif ( $config.TestAppCertPath ) {
        $certArgument.Add('CertificatePath', $config.TestAppCertPath)
    }

    New-GraphConnection -AppId $targetTestAppId -TenantId $targetTestAppTenant -NoninteractiveAppOnlyAuth  @certArgument
}

if ( ! $targetConnection ) {
    throw "No Graph connection information was specified. Please specify the 'TestAppId', 'TestAppTenant', and if required the 'TestAppCertificatePath' properties in the test configuration file '$($config.ConfigurationPath)' or specify a Graph Connection object created by the 'New-GraphConnection' command to the GraphConnectionOverride parameter of this command and retry the operation"
}

$global:__IntegrationTestGraphConnection = $TargetConnection

$global:__IntegrationTestInfo = & $psscriptroot/Get-IntegrationTestStatus.ps1

