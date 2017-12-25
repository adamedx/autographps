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

ScriptClass GraphAuthenticationContext {
    $AppId = $null
    $Authority = $null
    $AuthType = $null
    $ResourceAppIdUri = $null
    $TenantName = $null
    $Token = $null

    function __initialize($authType = 'msa', $appId, $tenantName = $null, $resourceAppIdUri = $null, $altAuthority = $null) {

        if ($appId -eq $null) {
            throw "A mandatory appId was not specified"
        }

        $validAuthTypes = @('msa', 'aad')
        if (-not $authType -in $validAuthTypes) {
            throw "Invalid auth type '$authType' was specified -- must be one of '$(validAuthTypes -join ',')'"
        }

        if ($authType -eq 'msa' -and $tenantName -ne $null) {
            throw "Tenant '$tenantName' was specified when authentication type 'msa' requires tenant to be unspecified."
        }

        $authorityValue = $altAuthority

        if ($authType -eq 'aad') {
            if ($tenantName -eq $null) {
                throw "A tenant name must be specified for authentication type 'aad'"
            }

            if ($resourceAppIdUri -eq $null) {
                throw "A resource AppId URI must be specified for authentication type 'aad'"
            }

            if ($authorityValue -eq $null) {
                $authorityValue = "https://login.windows.net/$tenantName"
            }

            import-assembly ../lib/Microsoft.IdentityModel.Clients.ActiveDirectory.dll
        } else {
            if ($altAuthority -eq $null) {
                $authorityValue ='https://login.microsoftonline.com/common'
            }
            $scriptDirectory = split-path -parent $pscommandpath

            import-assembly ../lib/Microsoft.Identity.Client.dll
        }

        $this.AppId = $appId
        $this.Authority = $authorityValue
        $this.AuthType = $authType
        $this.ResourceAppIdUri = $resourceAppIdUri
        $this.tenantName = $tenantName
        $this.Token = $null
    }

    function AcquireToken {
        if ($this.Token -eq $null) {
            if ($this.AuthType -eq 'aad') {
                $adalAuthContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $this.Authority
                $redirectUri = "http://localhost"

                # Value of '2' comes from 'Auto' of enumeration [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]
                $promptBehaviorValueRefreshSession = 0

                $promptBehavior = new-object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList $promptBehaviorValueRefreshSession
                $authResult = $adalAuthContext.AcquireTokenAsync($this.ResourceAppIdURI, $this.AppId, $redirectUri,  $promptBehavior)
                $this.Token = $authResult.Result
                if ( $authResult.Status -eq 'Faulted' ) {
                    throw [Exception]::new("Failed to acquire token for uri '$($this.ResourceAppIdURI)' for AppID '$($this.AppId)'`n" + $authResult.exception, $authResult.exception)
                }
            } else {
                $msaAuthContext = New-Object "Microsoft.Identity.Client.PublicClientApplication" -ArgumentList $this.AppId, $this.Authority
                $scopes = new-object System.Collections.Generic.List[string]
                $scopes.Add("User.Read")
                $authResult = $msaAuthContext.AcquireTokenAsync($scopes)
                $this.Token = $authResult.Result
                if ( $authResult.Status -eq 'Faulted' ) {
                    throw [Exception]::new("Failed to acquire token for uri '$($this.ResourceAppIdURI)' for AppID '$($this.AppId)'`n" + $authResult.exception, $authResult.exception)
                }
            }
        }
        $this.Token
    }
}

