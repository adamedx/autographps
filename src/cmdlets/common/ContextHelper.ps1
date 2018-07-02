# Copyright 2018, Adam Edwards
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

ScriptClass ContextHelper {
    static {
        const ContextDisplayTypeName 'GraphContextDisplayType'

        function __initialize {
            __RegisterContextDisplayType
        }

        function ToPublicContext( $context ) {
            $tokenData = $context.connection.identity.token

            $userId = $null
            $scopes = $null

            if ( $tokenData ) {
                $userId = $tokenData.User.DisplayableId
                $scopes = $tokenData.scopes
            }

            [PSCustomObject]@{
                PSTypeName = $this.ContextDisplayTypeName
                Name = $context.name
                Version = $context.version
                Endpoint = ($context |=> GetEndpoint)
                AuthEndpoint = $context.connection.GraphEndpoint.Authentication
                CurrentLocation = $context.location
                Authenticated = $context.connection.Connected
                Metadata = $::.GraphContext |=> GetMetadataStatus $context
                ConnectionStatus = $context.connection.status
                ApplicationId = $context.connection.identity.app.appid
                AuthType = $context.connection.identity.app.authtype
                UserId = $userId
                Scopes = $scopes
                Details = $context
            }
        }

        function ParseGraphRelativeLocation($locationUri) {
            $components = $locationUri -split ':'

            if ( $components.length -gt 2) {
                throw "'$locationUri' is not a valid graph location uri"
            }

            $relativeUri = $locationUri
            $context = if ( $components.length -eq 1 ) {
                $::.GraphContext |=> GetCurrent
            } else {
                $relativeUri = $components[1]
                $::.logicalgraphmanager.Get().contexts[$components[0]].context
            }

            @{
                Context = $context
                GraphRelativeUri = $::.GraphUtilities |=> ToGraphRelativeUri $relativeUri $context
            }
        }

        function __RegisterContextDisplayType {
            remove-typedata -typename $this.ContextDisplayTypeName -erroraction silentlycontinue

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
