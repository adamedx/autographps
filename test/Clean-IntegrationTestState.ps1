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

[cmdletbinding(positionalbinding=$false, supportsshouldprocess=$true)]
param(
    [parameter(mandatory=$true)]
    [Guid] $TestAppId,

    [parameter(mandatory=$true)]
    $GraphConnection,

    [string] $TestRunId,

    [switch] $EnableDelete
)

Set-StrictMode -Version 2

$ErrorActionPreference = 'Stop'

$disallowedOwners = '9825d80c-5aa0-42ef-bf13-61e12116704c', 'ac70e3e2-a821-4d19-839c-b8af4515254b'
$disallowedDeletedAppIds = $disallowedOwners + ( $GraphConnection.identity.app.appid )

if ( $TestAppId -in $disallowedOwners ) {
    write-error "This script may not be used to delete state owned by the specified TestAppId '$TestAppId'"
}

# Clean up applications created by the test app

$servicePrincipal = Get-GraphApplicationServicePrincipal -AppId $TestAppId -Connection $GraphConnection

$applications = Get-GraphResource /servicePrincipals/$($servicePrincipal.Id) -Expand ownedObjects -Connection $GraphConnection |
  select-object -expandproperty ownedObjects |
  where {
      $_.'@odata.type' -eq '#microsoft.graph.application'
  }

foreach ( $application in $applications ) {
    $appUri = "/applications/$($application.Id)"

    write-verbose "Found application with application id $($application.AppId) and object id $($application.id)"

    if ( $application.AppId -in $disallowedDeletedAppIds ) {
        write-error "Deletion of the specified object $($application.Id) with app id $($application.AppId) is not supported by this script"
    }

    if ( $TestRunId ) {
        if ( $application.Tags -contains $TestRunId ) {
            write-verbose "A TestRunId '$TestRunId' was specified, but the Tags property of owned application with object id '$($application.Id)' does not contain that TestRunId value"
            continue
        }
    }

    if ( $EnableDelete.IsPresent ) {
        Remove-GraphApplication -ObjectId $application.Id -Connection $GraphConnection
        write-verbose "Successfully deleted application id $($application.AppId) and object id $($application.Id)"
    } else {
        write-verbose 'Skipping deletion because the EnableDelete parameter was not specified'
    }

    $appUri
}


