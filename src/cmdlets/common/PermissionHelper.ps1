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

ScriptClass PermissionHelper {
    static {
        $typeMap = @{
            Scope=([GraphAppAuthType]::Delegated)
            Role=([GraphAppAuthType]::AppOnly)
        }

        $descriptionFieldMap = @{
            Scope = 'adminConsentDescription'
            Role = 'description'
        }

        function FindPermission($source, $searchString, $permissionType, $destination, $commandContext) {
            $source | foreach {
                if ( ! $searchString -or ( $_.tolower().contains($searchString) ) ) {
                    $permissionData = $::.ScopeHelper |=> GetPermissionsByName $_ $permissionType $commandContext.Connection
                    $entry = GetPermissionEntry $permissionData
                    $destination.permissions.Add($_, $entry)
                }
            }
        }

        function GetPermissionEntry($permissionData) {
            $description = $::.ScopeHelper.permissionsByIds[$permissionData.id] |
              select -expandproperty $this.descriptionFieldMap[$permissionData.Type]
            $consentType = if ( $permissionData.Type -eq 'Role' ) {
                'Admin'
            } else {
                $::.ScopeHelper.permissionsByIds[$permissionData.id].type
            }

            [PSCustomObject] @{
                Id = $permissionData.Id
                Type = $this.typeMap[$permissionData.Type]
                Name = $_
                Description = $description
                ConsentType = $consentType
            }
        }
    }
}
