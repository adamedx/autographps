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

. (import-script RESTResponse)

ScriptClass RESTRequest {
    const PoshGraphUserAgent 'PoshGraph/0.1 (Windows NT; Windows NT 10.0; en-US)'

    $uri = strict-val [Uri]
    $headers = strict-val [HashTable]
    $method = strict-val [String]
    $body = $null
    $userAgent = $PoshGraphUserAgent

    function __initialize([Uri] $uri, $method = "GET", [HashTable] $headers = @{}, $body = $null, $userAgent = $null) {
        $this.headers = $headers
        $this.method = $method
        $this.uri = $uri
        $this.body = if ( $body -eq $null ) {
            $null
        } elseif ( $body -is [String] ) {
            $body | convertfrom-json | out-null
            $body
        } else {
            $body | convertto-json
        }

        $this.userAgent = if ( $userAgent -ne $null ) {
            $this.userAgent = $userAgent
        }
    }

    function Invoke {
        [cmdletbinding(SupportsShouldProcess=$true)]
        param()
        if ($pscmdlet.shouldprocess($this.uri, $this.method)) {
            # Disable progress display
            $progresspreference = 'SilentlyContinue'

            $bodyArgument = if ( $this.body -ne $null -and $this.body.length -gt 0 ) {
                @{body=$this.body}
            } else {
                @{}
            }

            $httpResponse = Invoke-WebRequest -usebasicparsing -Uri $this.uri -headers $this.headers -method $this.method -useragent $this.userAgent @bodyArgument
            new-so RESTResponse $httpResponse
        } else {
            [PSCustomObject] @{PSTypeName='RESTResponse'}
        }
    }
}
