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

. (import-source graphauthenticationcontext)
. (import-source graphcontext)
. (import-source graphconnection)

function New-GraphContext($graphType = 'msgraph', $authtype = 'msa', $tenantName = $null, $alternateAppId = $null, $alternateEndpoint = $null, $alternateAuthority = $null) {
    new-scriptobject GraphContext $graphType $authtype $tenantName $alternateAppId $alternateEndpoint $alternateAuthority
}

function New-GraphConnection($graphType = 'msgraph', $authtype = 'msa', $tenantName = $null, $alternateAppId = $null, $alternateEndpoint = $null, $alternateAuthority = $null) {
    new-scriptobject GraphConnection $graphType $authtype $tenantName $alternateAppId $alternateEndpoint $alternateAuthority
}

function Get-GraphItem($itemRelativeUri, $existingConnection = $null) {
    $connection = if ($existingConnection -eq $null) {
        New-GraphConnection
    } else {
        $existingConnection
    }

    $connection |=> Connect

    $connection.Context |=> GetGraphAPIResponse $itemRelativeUri $null
}

