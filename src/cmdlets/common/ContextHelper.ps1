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

. (import-script ../../metadata/GraphManager)

ScriptClass ContextHelper {
    static {
        const ContextDisplayTypeName 'GraphContextDisplayType'

        function __initialize {
            __RegisterContextDisplayType
        }

        function ToPublicContext( $context ) {
            $userInfo = $context.connection.identity |=> GetUserInformation

            $userId = $userInfo.userId
            $scopes = $userInfo.scopes

            # Seems like ScriptClass constants have a strange behavior when used as a typename here.
            # To work around this, use ToString()
            [PSCustomObject]@{
                PSTypeName = ($this.ContextDisplayTypeName.tostring())
                Name = $context.name
                Version = $context.version
                Endpoint = ($context |=> GetEndpoint)
                AuthEndpoint = $context.connection.GraphEndpoint.Authentication
                CurrentLocation = $context.location
                Authenticated = $context.connection.Connected
                Metadata = $::.GraphManager |=> GetMetadataStatus $context
                ConnectionStatus = $context.connection.status
                ApplicationId = $context.connection.identity.app.appid
                TenantId = $context.connection.identity.TenantDisplayId
                TenantName = $context.connection.identity.TenantDisplayName
                AuthType = $context.connection.identity.app.authtype
                UserId = $userId
                Scopes = $scopes
                Details = $context
            }

        }

        function GetContextByNameOrDefault($contextName) {
            if ( $contextName ) {
                $::.LogicalGraphManager |=> Get |=> GetContext $contextName
            } else {
                $::.GraphContext |=> GetCurrent
            }
        }

        function __RegisterContextDisplayType {
            remove-typedata -typename $this.ContextDisplayTypeName -erroraction ignore

            $coreProperties = @('Metadata', 'Endpoint', 'Version', 'Name')

            $contextDisplayTypeArguments = @{
                TypeName    = $this.ContextDisplayTypeName
                MemberType  = 'NoteProperty'
                MemberName  = 'PSTypeName'
                Value       = $this.ContextDisplayTypeName
                DefaultDisplayPropertySet = $coreProperties
            }

            Update-TypeData -force @contextDisplayTypeArguments
        }

    }
}

$::.ContextHelper |=> __initialize
