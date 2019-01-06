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

    $source = $::.ScopeHelper |=> GetKnownPermissionsSorted $commandContext.Connection $Type

    $typeMap = @{
        Scope=([GraphAppAuthType]::Delegated)
        Role=([GraphAppAuthType]::AppOnly)
    }

    $descriptionFieldMap = @{
        Scope = 'adminConsentDescription'
        Role = 'description'
    }

    if ( $ExactMatch.IsPresent ) {
        $foundPermission = if ( $Type -eq $null -or $Type -eq ([GraphAppAuthType]::Delegated) ) {
            $::.ScopeHelper |=> GetPermissionsByName $Permission Scope $commandContext.Connection
        }

        if ( ! $foundPermission -and ( $Type -eq $null -or $Type -eq ([GraphAppAuthType]::AppOnly) ) ) {
            $foundPermission = $::.ScopeHelper |=> GetPermissionsByName $Permission Role $commandContext.Connection
        }

        if ( $foundPermission ) {
            $description = $::.ScopeHelper.permissionsByIds[$foundPermission.id] |
              select -expandproperty $descriptionFieldMap[$foundPermission.Type]
            [PSCustomObject] @{
                Id = $foundPermission.Id
                Type = $typeMap[$foundPermission.Type]
                Name = $Permission
                Description = $description
            }
        }
    } else {
        $permissionFinder = {
            param($source, $searchString, $permissionType, $destination)
            $source | foreach {
                if ( ! $searchString -or ( $_.tolower().contains($searchString ) ) ) {
                    $permissionData = $::.ScopeHelper |=> GetPermissionsByName $_ $permissionType $commandContext.Connection
                    $description = $::.ScopeHelper.permissionsByIds[$permissionData.id] |
                      select -expandproperty $descriptionFieldMap[$permissionData.Type]

                    $destination.permissions.Add(
                        $_,
                        [PSCustomObject] @{
                            Id = $permissionData.Id
                            Type = $typeMap[$permissionData.Type]
                            Name = $_
                            Description = $description
                        }
                    )
                }
            }
        }

        $normalizedSearchString = if ( $permission ) {
            $permission.tolower()
        }

        if ( $Type -eq $null -or $Type -eq ([GraphAppAuthType]::Delegated) ) {
            $blockResult = @{permissions=[System.Collections.Generic.SortedList[string, object]]::new()}
            $delegatedPermissions = $::.ScopeHelper.sortedGraphDelegatedPermissions
            . $permissionFinder $delegatedPermissions $normalizedSearchString Scope $blockResult
            $blockResult.Permissions.values
        }

        if ( $Type -eq $null -or $Type -eq ([GraphAppAuthType]::AppOnly) ) {
            $blockResult = @{permissions=[System.Collections.Generic.SortedList[string, object]]::new()}
            $appOnlyPermissions = $::.ScopeHelper |=> GetKnownPermissionsSorted $commandContext.Connection ([GraphAppAuthType]::AppOnly)
            . $permissionFinder $appOnlyPermissions $normalizedSearchString Role $blockResult
            $blockResult.Permissions.values
        }


    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Find-GraphPermissions Permission (new-so PermissionParameterCompleter ([PermissionCompletionType]::AnyPermission))
