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

        [ValidateSet('Delegated', 'AppOnly')]
        [string] $Type,

        $Connection
    )

    Enable-ScriptClassVerbosePreference

    $commandContext = new-so CommandContext $Connection $null $null $null

    if ( $ExactMatch.IsPresent ) {
        $foundPermissions = @()
        if ( ! $Type -or $Type -eq 'Delegated' ) {
            $foundDelegated = $::.ScopeHelper |=> GetPermissionsByName $Permission Scope $commandContext.Connection
            if ( $foundDelegated ) {
                $foundPermissions += $foundDelegated
            }
        }

        if ( ! $Type -or $Type -eq 'AppOnly' ) {
            $foundAppOnly = $::.ScopeHelper |=> GetPermissionsByName $Permission Role $commandContext.Connection
            if ( $foundAppOnly ) {
                $foundPermissions += $foundAppOnly
            }
        }

        $foundPermissions | foreach {
            $::.PermissionHelper |=> GetPermissionEntry $_
        }
    } else {
        $normalizedSearchString = if ( $permission ) {
            $permission.tolower()
        }

        if ( ! $Type -or $Type -eq 'Delegated' ) {
            $sortedResult = [System.Collections.Generic.SortedList[string, object]]::new()
            $delegatedPermissions = $::.ScopeHelper |=> GetKnownPermissionsSorted $commandContext.Connection 'Delegated'
            $::.PermissionHelper |=> FindPermission $delegatedPermissions $normalizedSearchString Scope $sortedResult $commandContext
            $sortedResult.values
        }

        if ( ! $Type -or $Type -eq 'AppOnly' ) {
            $sortedResult = [System.Collections.Generic.SortedList[string, object]]::new()
            $appOnlyPermissions = $::.ScopeHelper |=> GetKnownPermissionsSorted $commandContext.Connection 'AppOnly'
            $::.PermissionHelper |=> FindPermission $appOnlyPermissions $normalizedSearchString Role $sortedResult $commandContext
            $sortedResult.values
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Find-GraphPermissions Permission (new-so PermissionParameterCompleter DelegatedPermission)
