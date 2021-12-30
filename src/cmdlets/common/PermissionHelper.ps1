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

ScriptClass PermissionHelper {
    static {
        $PermissionDisplayTypeName = '__ScriptClassPermissionDisplayType'
        $onlineAttempted = $false

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

        function FindPermission($source, $searchString, $permissionType, $destination, $connection) {
            $targetConnection = __GetConnection $connection

            $source | foreach {
                if ( ! $searchString -or ( $_.tolower().contains($searchString) ) ) {
                    $permissionData = $::.ScopeHelper |=> GetPermissionsByName $_ $permissionType $targetConnection $true
                    $entry = GetPermissionEntry $permissionData
                    $destination.Add($_, $entry)
                }
            }
        }

        function GetPermissionsByName( [string[]] $scopeNames, $permissionType, $connection, $ignoreNotFound ) {
            $targetConnection = __GetConnection $connection

            $::.ScopeHelper |=> GetPermissionsByName $scopeNames $permissionType $targetConnection $ignoreNotFound
        }

        function GetKnownPermissionsSorted($connection, $graphAppAuthType) {
            $targetConnection = __GetConnection $connection

            $::.ScopeHelper |=> GetKnownPermissionsSorted $targetConnection $graphAppAuthType
        }

        function GetPermissionEntry($permissionData) {
            [PSCustomObject] @{
                PSTypeName = $this.PermissionDisplayTypeName
                Id = $permissionData.Id
                PermissionType = $this.typeMap[$permissionData.Type]
                ConsentType = $permissionData.consentType
                Name = $permissionData.Name
                Description = $permissionData.description
            }
        }

        function ResetOnlineAttempted {
            $this.onlineAttempted = $false
        }

        function __GetConnection($connection) {
            if ( $connection -and ! $this.onlineAttempted ) {
                $this.onlineAttempted = $true
                # TODO: Implement a method for accessing ScopeHelper state this way and / or a non-static solution
                $::.ScopeHelper.retrievedScopesFromGraphService = $false
                $connection
            }
        }
    }
}
