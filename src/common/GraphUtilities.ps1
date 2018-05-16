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

ScriptClass GraphUtilities {
    static {
        function ToGraphRelativeUriPath( $relativeUri, $context = $null ) {
            $result = if ( $relativeUri.tostring()[0] -eq '/' ) {
                $relativeUri
            } else {
                $graphContext = if ( $context ) {
                    $context
                } else {
                    'GraphContext' |::> GetCurrent
                }

                $graph = $graphContext |=> GetGraph
                $location = $graphContext.location |=> ToGraphUri $graph
                $location.tostring().TrimEnd('/'), $relativeUri.tostring().trimstart('/') -join '/'
            }

            $result
        }

        function ToGraphRelativeUri( $relativeUri, $context = $null ) {
            $normalizedUri = ($relativeUri -split '/' | where { $_ -ne '.' }) -join '/'
            $result = if ( $relativeUri.tostring()[0] -eq '/' ) {
                $normalizedUri
            } else {

                $graphContext = if ( $context ) {
                    $context
                } else {
                    'GraphContext' |::> GetCurrent
                }

                $location = $graphContext.location |=> ToGraphUri
                $location.tostring().TrimEnd('/'), $normalizedUri.tostring().trimstart('/') -join '/'
            }

            $result
        }

        function ToLocationUriPath( $context, $relativeUri ) {
            $graphRelativeUri = ToGraphRelativeUriPath $relativeUri $context
            "{0}:{1}" -f $context.name, $graphRelativeUri
        }

        function ParseLocationUriPath($UriPath) {
            $context = $null
            $isAbsolute = $false
            $graphRelativeUri = $null
            if ( $UriPath ) {
                $contextEnd = $UriPath.IndexOf(':')
                $graphRelativeUri = if ( $contextEnd -eq -1 ) {
                    $isAbsolute = $UriPath[0] -eq '/'
                    $UriPath
                } else {
                    $isAbsolute = $true
                    $context = $UriPath.substring(0, $contextEnd)
                    $UriPath.substring($contextEnd + 1, $UriPath.length - $contextEnd - 1)
                }
            }

            [PSCustomObject]@{
                Context=$context
                GraphRelativeUri=$graphRelativeUri
                IsAbsoluteUri=$isAbsolute
            }
        }

        function ParseGraphUri([Uri] $uri, $context) {
            $endpoint = $null
            $version = $null
            $sameEndpoint = $true
            $sameVersion = $true
            $isAbsolute = $uri.IsAbsoluteUri

            $relativeUri = if ( $isAbsolute ) {
                $endpoint = [Uri] ('https://{0}' -f $uri.host)
                $graphRelativeUri = ''
                $version = if ( $uri.segments.length -gt 0 ) {
                    for ( $uriIndex = 2; $uriIndex -lt $uri.segments.length; $uriIndex++ ) {
                        $graphRelativeUri += $uri.segments[$uriIndex]
                    }
                    $uri.segments[1].trim('/')
                }

                if ( $context ) {
                    $sameEndpoint = $graphRelativeUri -eq $context.connection.GraphEndpoint.Graph
                    $sameVersion = $version -eq $context.version
                }

                $graphRelativeUri
            } else {
                $uri
            }

            if ( $relativeUri -eq $null ) {
                throw "Invalid graph uri '$uri'"
            }

            [PSCustomObject]@{
                GraphRelativeUri = $relativeUri
                GraphVersion = $version
                EndpointMatchesContext = $sameEndpoint
                VersionMatchesContext = $sameVersion
                IsContextCompatible = $sameEndpoint -and $sameVersion
                IsAbsolute = $isAbsolute
            }
        }
    }
}
