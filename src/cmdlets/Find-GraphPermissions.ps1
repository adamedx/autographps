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

. (import-script common/PermissionHelper)

function Find-GraphPermissions {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='allpermissions')]
    param(
        [parameter(position=0, parametersetname='searchspec')]
        $Permission,

        [parameter(parametersetname='searchspec')]
        [switch] $ExactMatch,

        [GraphAppAuthType] $Type,

        $Connection
    )

    $commandContext = new-so CommandContext $Connection $null $null $null

    if ( $ExactMatch.IsPresent ) {
        $foundPermission = if ( $Type -eq $null -or $Type -eq ([GraphAppAuthType]::Delegated) ) {
            $::.ScopeHelper |=> GetPermissionsByName $Permission Scope $commandContext.Connection
        }

        if ( ! $foundPermission -and ( $Type -eq $null -or $Type -eq ([GraphAppAuthType]::AppOnly) ) ) {
            $foundPermission = $::.ScopeHelper |=> GetPermissionsByName $Permission Role $commandContext.Connection
        }

        if ( $foundPermission ) {
            $::.PermissionHelper |=> GetPermissionEntry $foundPermission $Permission
        }
    } else {
        $normalizedSearchString = if ( $permission ) {
            $permission.tolower()
        }

        if ( $Type -eq $null -or $Type -eq ([GraphAppAuthType]::Delegated) ) {
            $sortedResult = [System.Collections.Generic.SortedList[string, object]]::new()
            $workaroundToInitializeScopeHelper = $::.ScopeHelper |=> GetKnownPermissionsSorted $commandContext.Connection ([GraphAppAuthType]::Delegated)
            $delegatedPermissions = $::.ScopeHelper.sortedGraphDelegatedPermissions
            $::.PermissionHelper |=> FindPermission $delegatedPermissions $normalizedSearchString Scope $sortedResult $commandContext
            $sortedResult.values
        }

        if ( $Type -eq $null -or $Type -eq ([GraphAppAuthType]::AppOnly) ) {
            $sortedResult = [System.Collections.Generic.SortedList[string, object]]::new()
            $appOnlyPermissions = $::.ScopeHelper |=> GetKnownPermissionsSorted $commandContext.Connection ([GraphAppAuthType]::AppOnly)
            $::.PermissionHelper |=> FindPermission $appOnlyPermissions $normalizedSearchString Role $sortedResult $commandContext
            $sortedResult.values
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Find-GraphPermissions Permission (new-so PermissionParameterCompleter ([PermissionCompletionType]::AnyPermission))
