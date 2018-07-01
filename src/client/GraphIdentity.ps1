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

. (import-script ../GraphService/GraphEndpoint)
. (import-script GraphApplication)

ScriptClass GraphIdentity {
    $App = strict-val [PSCustomObject]
    $Token = strict-val [PSCustomObject] $null

    static {
        $__AuthLibraryLoaded = $null
        $__TokenCache = $null

        function __InitializeTokenCache {
            if ( ! $this.__TokenCache ) {
                # TODO: Understand why this doesn't seem to cache anything,
                # or at least the cache is not used in token acquisition :(
                $this.__TokenCache = New-Object "Microsoft.Identity.Client.TokenCache"
            }
        }
    }

    function __initialize([PSCustomObject] $App) {
        $this.App = $app
    }

    function Authenticate($graphEndpoint, $scopes = $null) {
        if ( $this.token -ne $null) {
            if ( $graphEndpoint.Type -eq [GraphType]::MSGraph ) {
                $tokenTimeLeft = $this.token.expireson - [DateTime]::UtcNow
                write-verbose ("Found existing token with {0} minutes left before expiration" -f $tokenTimeLeft.TotalMinutes)

                if ( $tokenTimeLeft.TotalMinutes -ge 2 ) {
                    return
                } else {
                    write-verbose 'Requesting new token since existing token is expired or near expiration'
                }
            } else {
                return
            }
        }

        if ( $graphEndpoint.Type -ne [GraphType]::AADGraph -and ( $scopes -eq $null -or $scopes.length -eq 0 ) ) {
            throw [ArgumentException]::new('No scopes specified, at least one scope is required')
        }

        $this.scriptclass |=> __LoadAuthLibrary $graphEndpoint.Type

        write-verbose ("Getting token for resource {0} for uri: {1}" -f $graphEndpoint.Authentication, $graphEndpoint.Graph)

        # Cast it in case this is a deserialized object --
        # workaround for a defect in ScriptClass
        $this.Token = switch ([GraphType] $graphEndpoint.Type) {
            ([GraphType]::MSGraph) { getMSGraphToken $graphEndpoint $scopes }
            ([GraphType]::AADGraph) { getAADGraphToken $graphEndpoint $scopes }
            default {
                throw "Unexpected Graph type '$($graphEndpoint.GraphType)'"
            }
        }

        if ($this.token -eq $null) {
            throw "Failed to acquire token, no additional error information"
        }
    }

    function ClearAuthentication {
        $this.token = $null
    }

    static {
        function __LoadAuthLibrary([GraphType] $graphType) {
            if ( $this.__AuthLibraryLoaded -eq $null ) {
                $this.__AuthLibraryLoaded = @{}
            }

            if ( ! $this.__AuthLibraryLoaded[$graphType] ) {
                # Cast it in case this is a deserialized object --
                # workaround for a defect in ScriptClass
                switch ( [GraphType] $graphType ) {
                    ([GraphType]::MSGraph) {
                        import-assembly ../../lib/Microsoft.Identity.Client.dll
                    }
                    ([GraphType]::AADGraph) {
                        import-assembly ../../lib/Microsoft.IdentityModel.Clients.ActiveDirectory.dll
                    }
                    default {
                        throw "Unexpected graph type '$graphType'"
                    }
                }

                $this.__AuthLibraryLoaded[$graphType] = $true
            } else {
                write-verbose "Library already loaded for graph type '$graphType'"
            }
        }
    }

    function getMSGraphToken($graphEndpoint, $scopes) {
        write-verbose "Attempting to get token for MS Graph..."

        $this.scriptclass |=> __InitializeTokenCache
        $msalAuthContext = New-Object "Microsoft.Identity.Client.PublicClientApplication" -ArgumentList $this.App.AppId, $graphEndpoint.Authentication, $this.scriptclass.__TokenCache

        $requestedScopes = new-object System.Collections.Generic.List[string]

        write-verbose ("Adding scopes to request: {0}" -f ($scopes -join ';'))

        $scopes | foreach {
            $requestedScopes.Add($_)
        }

        # TODO: Understand how to make this use a cached refresh token
        # to avoid user interaction. We can pass in an extra parameter
        # IUsee from $this.Token.User, but that makes no difference
        $authResult = $msalAuthContext.AcquireTokenAsync($requestedScopes)
        write-verbose ("`nToken request status: {0}" -f $authResult.Status)

        if ( $authResult.Status -eq 'Faulted' ) {
            throw "Failed to acquire token for uri '$($graphEndpoint.Graph)' for AppID '$($this.App.AppId)'`n" + $authResult.exception, $authResult.exception
        }

        $result = $authResult.Result

        if ( $authResult.IsFaulted ) {
            throw $authResult.Exception
        }
        $result
    }

    function getAADGraphToken($graphEndpoint, $scopes) {
        write-verbose "Attempting to get token for AAD Graph..."
        $adalAuthContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $graphEndpoint.Authentication
        $redirectUri = "http://localhost"

        $promptBehaviorValue = ([Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto)

        $promptBehavior = new-object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList $promptBehaviorValue

        $authResult = $adalAuthContext.AcquireTokenAsync(
            $graphEndpoint.Graph,
            $this.App.AppId,
            $redirectUri,
            $promptBehavior)

        if ( $authResult.Status -eq 'Faulted' ) {
            throw "Failed to acquire token for uri '$($graphEndpoint.Graph)' for AppID '$($this.AppId)'`n" + $authResult.exception, $authResult.exception
        }
        $authResult.Result
    }
}

