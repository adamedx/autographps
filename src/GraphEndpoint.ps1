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

enum GraphCloud {
    Public
    ChinaCloud
    GermanyCloud
    USGovernmentCloud
}

enum GraphType {
    MSGraph
    AADGraph
}

ScriptClass GraphEndpoint {
    static {
        $MSGraphCloudEndpoints = @{
            [GraphCloud]::Public = @{
                Authentication='https://login.microsoftonline.com/common'
                Graph='https://graph.microsoft.com'
            }
            [GraphCloud]::ChinaCloud = @{
                Authentication='https://login.chinacloudapi.cn'
                Graph='https://microsoftgraph.chinacloudapi.cn'
            }
            [GraphCloud]::GermanyCloud = @{
                Authentication='https://windows.microsoftonline.de'
                Graph='https://graph.microsoft.de'
            }
            [GraphCloud]::USGovernmentCloud = @{
                Authentication='https://login.microsoftonline.us/common'
                Graph='https://graph.microsoft.us'
            }
        }

        $AADGraphCloudEndpoints = @{
            Authentication = 'https://login.microsoftonline.com/common'
            Graph='https://graph.windows.net'
        }
    }

    $Authentication = strict-val [Uri]
    $Graph = strict-val [Uri]
    $Type = strict-val [GraphType]

    function __initialize {
        [cmdletbinding()]
        param (
            [GraphCloud] $cloud,
            [GraphType] $graphType = [GraphType]::MSGraph,
            [Uri] $GraphEndpoint,
            [Uri] $AuthenticationEndpoint
        )
        $this.Type = $GraphType
        $endpoints = if ($GraphEndpoint -eq $null) {
            if ($graphType -eq [GraphType]::MSGraph) {
                $this.scriptclass.MSGraphCloudEndpoints[$cloud]
            } else {
                $this.scriptclass.AADGraphCloudEndpoints
            }
        } else {
            @{
                Graph=$GraphEndpoint
                Authentication=$AuthenticationEndpoint
            }
        }

        $this.Authentication = new-object Uri $endpoints.Authentication
        $this.Graph = new-object Uri $endpoints.Graph
    }
}
