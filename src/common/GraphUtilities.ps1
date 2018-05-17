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
            __ToGraphRelativeUriPath $relativeUri $context $true
        }

        function __NormalizeBacktrack( $uriAbsoluteString ) {
            if ( $uriAbsoluteString[0] -ne '/' ) {
                throw "'$uriAbsoluteString' is not an absolute path"
            }

            $segments = $uriAbsoluteString -split '/'

            $newSegments = new-object System.Collections.Generic.List[string]

            $segments | foreach {
                if ( $_ -eq '..' ) {
                    if ( $newSegments.count -gt 0 ) {
                        $newSegments.RemoveAt($newSegments.count - 1)
                     }
                } else {
                    $newSegments.Add($_)
                }
            }

            $result = $newSegments -join '/'

            if ( $result[0] -ne '/' ) {
                $result = '/' + $result
            }
            write-verbose "Backtrack '$uriAbsoluteString' converted to '$result'"
            $result
        }

        function ToGraphRelativeUri( $relativeUri, $context = $null ) {
             __ToGraphRelativeUriPath $relativeUri $context
        }

        function __ToGraphRelativeUriPath( $relativeUri, $context = $null, $QualifyPath = $false ) {
            $normalizedUri = ($relativeUri -split '/' | where { $_ -ne '.' }) -join '/'
            $result = if ( $relativeUri.tostring()[0] -eq '/' ) {
                [Uri] (__NormalizeBacktrack $normalizedUri)
            } else {
                $graphContext = if ( $context ) {
                    $context
                } else {
                    'GraphContext' |::> GetCurrent
                }

                $locationUri = $graphContext.location |=> ToGraphUri
                $graphUri = $locationUri.tostring().trimend('/'), $normalizedUri.tostring().trim('/') -join '/'
                $canonicalGraphUri = __NormalizeBacktrack $graphUri.tostring()

                if ( $QualifyPath ) {
                    ToQualifiedUri $canonicalGraphUri $graphContext
                } else {
                    $canonicalGraphUri
                }
            }

            $result
        }

        function ToQualifiedUri($graphRelativeUriString, $context) {
            $graph = $context |=> GetGraph

            $relativeVersionedUriString = $graph.ApiVersion, $graphRelativeUriString.trimstart('/') -join '/'
            new-object Uri $graph.Endpoint, $relativeVersionedUriString
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
