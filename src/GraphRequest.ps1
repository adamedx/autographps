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

ScriptClass GraphRequest {
    $Uri = strict-val [Uri]
    $Verb = strict-val [String]
    $Body = strict-val [String]
    $Query = $null
    $Headers = $null
    $DefaultPageSize = strict-val [int32] 10

    function __initialize([Uri] $uri, $verb = 'GET', $headers = $null, $query = $null) {
        $uriString = $uri.tostring()
        $uriNoQuery = new-object Uri ($uriString.substring(0, $uriString.length - $uri.Query.length))
        $this.Uri = $uriNoQuery
        $this.Verb = $verb
        $this.Query = __AddQueryParameters $uri.query $query
        $this.Headers = if ( $headers -ne $null ) {
            $headers
        } else {
            $this.Headers = @{'Content-Type'='application/json'}
        }
    }

    function Invoke($pageStartIndex = $null, $pageSize = $null) {
        $queryParameters = @($this.Query)

        if ($pageStartIndex -ne $null) {
            $queryParameters += (__NewODataParameter 'skip' $pageStartIndex)
        }

        if ($pageSize -ne $null) {
            $queryParameters += (__NewODataParameter 'top' $pageSize)
        }

        $query = __AddQueryParameters $queryParameters

        __InvokeRequest $this.verb $this.uri $query $this.headers
    }

    function GetCount {
        $countQuery = __NewODataParameter 'count'
        __InvokeRequest 'GET' $this.uri $countQuery
    }

    function __InvokeRequest($verb, $uri, $query, $headers) {
        $uriPath = __UriWithQuery $uri $query
        $uri = new-object Uri $uriPath
        $restRequest = new-so RestRequest $uri $verb $headers
        $restRequest |=> Invoke
    }

    function __AddQueryParameters([String[]] $parameters) {
        $components = @()

        $parameters | foreach {
            $normalizedParameter = if ( $_.startswith('?') ) {
                $_.substring(1, $_.length -1)
            } else {
                $_
            }

            if ( $normalizedParameter -ne $null -and $normalizedParameter.length -gt 0 ) {
                $components += $normalizedParameter
            }
        }

        $components -join '&'
    }

    function __UriWithQuery($uri, $query) {
        if ( $query -ne $null -and $query.length -gt 0 ) {
            new-object Uri ($Uri.tostring() + '?' + $query)
        } else {
            new-object Uri $uri.tostring()
        }
    }

    function __NewODataParameter($parameterName, $value) {
        if ( $value -ne $null ) {
            '${0}={1}' -f $parameterName, $value
        } else {
            '${0}' -f $parameterName
        }
    }
}
