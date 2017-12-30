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

    function __initialize([PSCustomObject] $GraphEndpoint, [PSCustomObject] $Identity) {
        $this.GraphEndpoint = $GraphEndpoint
        $this.Identity = $Identity
    }

    function Connect {
        $this.Identity |=> Authenticate $this.GraphEndpoint
    }

    static {
        function NewSimpleConnection([GraphType] $graphType, [string] $AADTenantId = $null, [GraphCloud] $cloud = 'Public') {
            $accountType = if ( $AADTenantId -ne $null ) {
                [IdentityType]::AAD
            } else {
                [IdentityType]::MSA
            }

            $endpoint = new-so GraphEndpoint $cloud $graphType
            $app = new-so GraphApplication $::.Application.AppId
            $identity = new-so GraphIdentity $app $accountType $AADTenantId
            new-so GraphConnection $endpoint $identity
        }
    }
}
