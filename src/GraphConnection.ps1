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

. (import-script Application)
. (import-script GraphEndpoint)
. (import-script GraphIdentity)

ScriptClass GraphConnection {
    $Identity = strict-val [PSCustomObject]
    $GraphEndpoint = strict-val [PSCustomObject]
    $Scopes = strict-val [Object[]]

    function __initialize([PSCustomObject] $GraphEndpoint, [PSCustomObject] $Identity, [Object[]]$Scopes) {
        $this.GraphEndpoint = $GraphEndpoint
        $this.Identity = $Identity

        if ( $this.GraphEndpoint.Type -eq ([GraphType]::MSGraph) ) {
            $this.Scopes = $Scopes
        }
    }

    function Connect {
        $this.Identity |=> Authenticate $this.GraphEndpoint $this.Scopes
    }

    static {
        function NewSimpleConnection([GraphType] $graphType, [GraphCloud] $cloud = 'Public', [String[]] $ScopeNames) {
            $accountType = switch ($graphType) {
                ([GraphType]::AADGraph) { [IdentityType]::AAD }
                ([GraphType]::MSGraph) { [IdentityType]::MSA }
            }

            $endpoint = new-so GraphEndpoint $cloud $graphType
            $app = new-so GraphApplication $::.Application.AppId
            $identity = new-so GraphIdentity $app $accountType
            new-so GraphConnection $endpoint $identity $ScopeNames
        }
    }
}
