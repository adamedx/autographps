# Copyright 2017, Adam Edwards
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

. (import-script GraphEndpoint)
. (import-script GraphApplication)

enum IdentityType {
    AAD
    MSA
}

ScriptClass GraphIdentity {
    $App = strict-val [PSCustomObject]
    $IdentityType = strict-val [IdentityType]
    $Token = strict-val [PSCustomObject] $null

    function __initialize([PSCustomObject] $App, [Identitytype] $IdentityType = [IdentityType]::MSA) {
        $this.App = $app
        $this.IdentityType = $IdentityType

        switch ( $IdentityType ) {
            ([IdentityType]::MSA) {
                import-assembly ../lib/Microsoft.Identity.Client.dll
            }
            ([IdentityType]::AAD) {
                import-assembly ../lib/Microsoft.IdentityModel.Clients.ActiveDirectory.dll
            }
            default {
                throw "Unexpected identity type '$IdentityType'"
            }
        }
    }

    function Authenticate([PSCustomObject] $graphEndpoint, $scopes = @()) {
        if ($this.token -ne $null) {
            return
        }

        write-verbose ("Getting token for resource {0} for uri: {1}" -f $graphEndpoint.Authentication, $graphEndpoint.Graph)

        $this.Token = switch ($this.IdentityType) {
            ([IdentityType]::MSA) { getMSAToken $graphEndpoint $scopes }
            ([IdentityType]::AAD) { getAADToken $graphEndpoint $scopes }
            default {
                throw "Unexpected identity type '$($this.IdentityType)'"
            }
        }

        if ($this.token -eq $null) {
            throw "Failed to acquire token, no additional error information"
        }
    }

    function getMSAToken($graphEndpoint, $scopes) {
        write-verbose "Attempting to get token for MS Graph..."
        $msaAuthContext = New-Object "Microsoft.Identity.Client.PublicClientApplication" -ArgumentList $this.App.AppId, $graphEndpoint.Authentication
        $requestedScopes = new-object System.Collections.Generic.List[string]

        write-verbose ("Adding scopes to request: {0}" -f ($scopes -join ';'))

        $scopes | foreach {
            $requestedScopes.Add($_)
        }

        $authResult = $msaAuthContext.AcquireTokenAsync($requestedScopes)
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

    function getAADToken($graphEndpoint, $scopes) {
        write-verbose "Attempting to get token for AAD Graph..."
        $adalAuthContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $graphEndpoint.Authentication
        $redirectUri = "http://localhost"

        # Value of '2' comes from 'Auto' of enumeration [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]
        $promptBehaviorValueRefreshSession = ([Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto)

        $promptBehavior = new-object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList $promptBehaviorValueRefreshSession

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
