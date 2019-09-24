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
        $PermissionDisplayTypeName = '__ScriptClassPermissionDisplayType'

        $typeMap = @{
            Scope='Delegated'
            Role='AppOnly'
        }

        function __RegisterSegmentDisplayType($typeName) {
            remove-typedata -typename $typeName -erroraction ignore

            $coreProperties = @('Type', 'ConsentType', 'Name', 'Description')

            $segmentDisplayTypeArguments = @{
                TypeName    = $typeName
                MemberType  = 'NoteProperty'
                MemberName  = 'PSTypeName'
                Value       = $typeName
                DefaultDisplayPropertySet = $coreProperties
            }

            Update-TypeData -force @segmentDisplayTypeArguments
        }

        __RegisterSegmentDisplayType $PermissionDisplayTypeName

        function FindPermission($source, $searchString, $permissionType, $destination, $commandContext) {
            $source | foreach {
                if ( ! $searchString -or ( $_.tolower().contains($searchString) ) ) {
                    $permissionData = $::.ScopeHelper |=> GetPermissionsByName $_ $permissionType $commandContext.Connection
                    $entry = GetPermissionEntry $permissionData
                    $destination.Add($_, $entry)
                }
            }
        }

        function GetPermissionEntry($permissionData) {
            [PSCustomObject] @{
                PSTypeName = $this.PermissionDisplayTypeName
                Id = $permissionData.Id
                Type = $this.typeMap[$permissionData.Type]
                ConsentType = $permissionData.consentType
                Name = $permissionData.Name
                Description = $permissionData.description
            }
        }
    }
}
