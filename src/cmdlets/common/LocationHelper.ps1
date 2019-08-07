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

. (import-script SegmentHelper)

ScriptClass LocationHelper {
    static {
        const LocationDisplayTypeName 'GraphLocationDisplayType'

        function __initialize {
            __RegisterLocationDisplayType
        }

        function ToPublicLocation( $parser, $segment ) {
            $publicSegment = $::.SegmentHelper |=> ToPublicSegment $parser $segment

            # The ToString() below is actually required for the PSTypeName member to fulfill its
            # function of type conversion
            [PSCustomObject]@{
                PSTypeName = $this.LocationDisplayTypeName.tostring()
                Path = $publicSegment.Path
                Details = $publicSegment
            }
        }

        function ToLocationUriPath( $context, $relativeUri ) {
            $graphRelativeUri = $this.ToGraphRelativeUriPathQualified($relativeUri, $context)
            "/{0}:{1}" -f $context.name, $graphRelativeUri
        }

        function ToGraphRelativeUriPathQualified( $relativeUri, $context = $null ) {
            $unqualifiedPath = $::.GraphUtilities |=> __ToGraphRelativeUriPath $relativeUri $context
            __ToQualifiedUri $unqualifiedPath $context
        }

        function __ToQualifiedUri($graphRelativeUriString, $context) {
            $graph = $::.GraphManager |=> GetGraph $context
            $relativeVersionedUriString = $::.GraphUtilities |=> JoinRelativeUri $graph.ApiVersion $graphRelativeUriString
            $::.GraphUtilities |=> JoinAbsoluteUri $graph.Endpoint $relativeVersionedUriString
        }

        function __RegisterLocationDisplayType {
            remove-typedata -typename $this.LocationDisplayTypeName -erroraction ignore

            $coreProperties = @('Path')

            $locationDisplayTypeArguments = @{
                TypeName    = $this.LocationDisplayTypeName
                MemberType  = 'NoteProperty'
                MemberName  = 'PSTypeName'
                Value       = $this.LocationDisplayTypeName.tostring()
                DefaultDisplayPropertySet = $coreProperties
            }

            Update-TypeData -force @locationDisplayTypeArguments
        }

    }
}

$::.LocationHelper |=> __initialize
