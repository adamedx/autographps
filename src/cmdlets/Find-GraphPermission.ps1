# Copyright 2021, Adam Edwards
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

. (import-script common/PermissionHelper)

<#
.SYNOPSIS
Finds Graph API permissions and their metadata.

.DESCRIPTION
Find-GraphPermission searches for Graph API permissions with names that match the specified search string, either exactly or by containing the search string as a substring in the permission name. In addition to returning the name of each matching permission, Find-GraphPermission also returns a description of the permission and its unique identifier. The unique identifier is required by certain Graph API requests that configure the Graph API permissions of Entra ID applications.

Permissions denote the authorization required to access specific APIs of the Graph. Permission names are human-readable and their semantics can often by inferred from the name. Most permissions look sometihng like 'User.Read' or 'Mail.Read'. With Find-GraphPermission, a search for 'mail' would return results that include the permisison 'Mail.Read' and 'Mail.ReadWrite' among other permissions related to mail. The command returns both delegated and app-only permissions. For a given permission name, there may be more than one permission that exactly matches the search string in the case that the same permission name is used for a delegated permission and an app-only permission.

For more details on Graph API permissions, execute the 'Show-GraphHelp -PermissionsHelp' command or visit the permissions documentation at https://docs.microsoft.com/en-us/graph/permissions-reference.

Find-GraphPermission is useful any time you're not sure what permissions are required for a certain Graph API request or even for commands in this module that access the Graph:
    * Use Find-GraphPermission to determine what permissions to request using the Connect-GraphApi command so that subsequent commands accessing specific APIs will succeed
    * The command is also useful in determining the permissions to specify for commands such as New-GraphApplication and Set-GraphApplicationConsent that configure Entra ID application permissions.

For each permission, the command returns not only the name of the permission and its unique identiier, but also its

Note that since the unique identifiers for permissions are not currently documented in the API documentation, Find-GraphPermission may be used when you know the name of the permission and need to configure or interpret the permissions an application object or consent returned from a Graph API request including one issued by this module.

Find-GraphPermission relies on a certain level of access to the Entra ID organization to obtain the full list of available permissions; the command will still function successfully with slightly degraded functionality without this access. See the NOTES section for details on mitigations and workarounds for insufficient access to permissions data.

See the documentation at

.PARAMETER SearchString
Specifies the string to match to a permission name. By default, the command returns any permission with a nameelook for in the type information. By default, a "contains" match of the search string is performed across the type name field of all entity types. The MatchType parameter can be used to select an exact match, and the Criteria field can be used to add additional fields of the type (e.g. property names) to match against the SearchString parameter in addition to the type name. Note that if SearchString is unspecified, all permissions are returned.

.PARAMETER ExactMatch
By default, the match for SearchString is evaluated by checking to see if SearchString is a substring of each permission name. Specify the ExactMatch parameter to require that each permission name must match SearchString exactly to be considered a match.

.PARAMETER PermissionType
Specifies the permission type to return, Delegated or AppOnly. By default, the parameter is $null so both delegated and app-only permissions that match SearchString are returned.

.PARAMETER SourceMode
Specifies the manner in which permissions data is obtained. By default, the SourceMode is 'Auto', which means that if the command has not previously attempted to access permission data from Entra ID, it will attempt to do so, and if it fails it will use static permissions information that may be out of date. Subsequent attempts will use whatever data was retrieved from either source on the first attempt. If the mode is set to 'Online' then it will attempt to read the data from Entra ID regardless whether it already has data cached from any source or whether the last attempt to access Entra ID was successful -- use this option to obtain the most recent data accessible. Specify Offline to indicate that Entra ID should not be contacted at all -- cached data will be used or if there is none the static data will be used -- use this to avoid unwanted network access or sign-in attempts. Note that in both the Auto and Online cases if Entra ID is accessed and the connection is not signed-in, a sign-in will occur. Also in both the Auto and Online cases failure to access Entra ID will not result in a command failure -- cached data will simply be used. The command does not provide a mechanism to expose whether the data returned by the command originated from Entra ID vs. the static source nor does it provide information about the last time the data was considered up to date.

.PARAMETER Connection
Specifies a Connection object returned by a command like New-GraphConnection or Connect-GraphApi or referenced by a Graph object. Find-GraphPermission will query the Graph at the specified connection for the list of all permissions supported by the Graph API service endpoint for the connection.

.NOTES
The command retrieves the list of permissions from the Graph API; it requires that the signed-in user or the application has permission to read this list of permissions from a service principal in the Entra ID organization. If it doesn't, the API falls back on a hard-coded list of permissions built into the module's code. In that case, some permissions recently added to the Graph API may not be found by the command. Since permissions are the same for all applications and organizations, a workaround is to sign in to a different Entra ID application identity or even a different organization where you have a higher level set of permissions consented such as Application.Read.All, Application.ReadWrite.All, or Directory.AccessAsUser.All and use the SourceMode parameter with the value 'Online' to force the command to retry accessing Entra ID (it will continue to use cached information otherwise). Certain roles may also grant access to read the required service principal.

.OUTPUTS
A collection of objects, each with information about a permission that match the SearchString parameter. The data are grouped by permission type (i.e. Delegated or AppOnly) and sorted alphabetically within each grouping.

.EXAMPLE
Find-GraphPermission mailbox

   AuthType: Delegated

PermissionType  ConsentType Name                      Description
--------        ----------- ----                      -----------
Delegated       User        MailboxSettings.Read      Allows the app to the read user's mailbox settings. Does not include...
Delegated       User        MailboxSettings.ReadWrite Allows the app to create, read, update, and delete user's mailbox se...

   AuthType: AppOnly

PermissionType ConsentType Name                      Description
--------       ----------- ----                      -----------
AppOnly        Admin       MailboxSettings.Read      Allows the app to read user's mailbox settings without a signed-in us...
AppOnly        Admin       MailboxSettings.ReadWrite Allows the app to create, read, update, and delete user's mailbox set...

This example shows how to search for permissions related to the topic 'mailbox'. Both delegated and app-only permissions are returned as results.

.EXAMPLE
Find-GraphPermission mail.read -ExactMatch -PermissionType Delegated

In this example, ExactMatch is used to specifically find the 'Mail.Read' permission, and the PermissionType parameter is specified as 'Delegated' to ensure that only the delegated version is returned. Without the PermissionType parameter, both a delegated and app-only permission would have been returned.

.EXAMPLE
'User.Read.All', 'Group.Read.all' | Find-GraphPermission -ExactMatch -PermissionType AppOnly | Select-Object Name, Id

Name           Id
----           --
User.Read.All  df021288-bdef-4463-88db-98f22de89214
Group.Read.all 5b567255-7703-4780-807c-7be8301ae99b

This example shows how to determine the identifiers for a permission -- these identifiers are required when invoking REST requests to the Graph API for Entra ID application configuration of permissions since the friendly names like 'User.Read.All' are not accepted by the API and must be translated to id's. In this example, multiple SearchString parameter values are passed to the command via the pipeline, and ExactMatch is specified because the goal is to get exactly these permissions. Since teh requirement here is for application-only permissions, the PermissionType parameter is specified as AppOnly -- otherwise delegated permissions with the sane names specified to SearchString would also be returned. The output is piped to Select-Object in this case for concise viewing, and could have easily been assigned to a variable or added to a hash table indexed by permission name for use in setting the value of a Graph API request body for application permission cofiguration.

.LINK
Show-GraphHelp
Find-GraphType
#>
function Find-GraphPermission {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='allpermissions')]
    param(
        [parameter(position=0, parametersetname='searchspec', valuefrompipeline='true')]
        [string] $SearchString,

        [parameter(parametersetname='searchspec')]
        [switch] $ExactMatch,

        [ValidateSet('Delegated', 'AppOnly')]
        [string] $PermissionType,

        [ValidateSet('Auto', 'Offline', 'Online')]
        [string] $SourceMode = 'Auto',

        $Connection
    )

    begin {
        Enable-ScriptClassVerbosePreference

        $targetConnection = if ( $SourceMode -ne 'Offline' ) {
            $commandContext = new-so CommandContext $Connection $null $null $null
            if ( $SourceMode -eq 'Online' ) {
                $::.PermissionHelper |=> ResetOnlineAttempted
            }
            $commandContext.Connection
        }
    }

    process {
        if ( $ExactMatch.IsPresent ) {
            $foundPermissions = @()
            if ( ! $PermissionType -or $PermissionType -eq 'Delegated' ) {
                $foundDelegated = $::.PermissionHelper |=> GetPermissionsByName $SearchString Scope $targetConnection $true
                if ( $foundDelegated ) {
                    $foundPermissions += $foundDelegated
                }
            }

            if ( ! $PermissionType -or $PermissionType -eq 'AppOnly' ) {
                $foundAppOnly = $::.PermissionHelper |=> GetPermissionsByName $SearchString Role $targetConnection $true
                if ( $foundAppOnly ) {
                    $foundPermissions += $foundAppOnly
                }
            }

            $foundPermissions | foreach {
                $::.PermissionHelper |=> GetPermissionEntry $_
            }
        } else {
            $normalizedSearchString = if ( $SearchString ) {
                $SearchString.tolower()
            }

            if ( ! $PermissionType -or $PermissionType -eq 'Delegated' ) {
                $sortedResult = [System.Collections.Generic.SortedList[string, object]]::new()
                $delegatedPermissions = $::.PermissionHelper |=> GetKnownPermissionsSorted $targetConnection 'Delegated'
                $::.PermissionHelper |=> FindPermission $delegatedPermissions $normalizedSearchString Scope $sortedResult $targetConnection
                $sortedResult.values
            }

            if ( ! $PermissionType -or $PermissionType -eq 'AppOnly' ) {
                $sortedResult = [System.Collections.Generic.SortedList[string, object]]::new()
                $appOnlyPermissions = $::.PermissionHelper |=> GetKnownPermissionsSorted $targetConnection 'AppOnly'
                $::.PermissionHelper |=> FindPermission $appOnlyPermissions $normalizedSearchString Role $sortedResult $targetConnection
                $sortedResult.values
            }
        }
    }

    end {
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Find-GraphPermission Permission (new-so PermissionParameterCompleter DelegatedPermission)
