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

            $optionalArguments = if ( $this.body -ne $null -and $this.body.length -gt 0 ) {
                @{body=$this.body}
            } else {
                @{}
            }

            if ( $this.headers -ne $null ) {
                write-verbose "Request Headers:"
                $this.headers.keys | foreach {
                    $outputValue = if ( $_ -ne 'Authorization' ) {
                        $this.headers[$_]
                    } else {
                        '<authtoken>'
                    }
                }
                _write-headersverbose $this.headers (@{Authorization='<redacted authtoken>'})
            }

            write-verbose "Request Body: `n`n$($this.body)`n`n"

            $httpResponse = try {
                Invoke-WebRequest -Uri $this.uri -headers $this.headers -method $this.method -useragent $this.userAgent @optionalArguments
            } catch [System.Net.WebException] {
                $response = $_.exception.response
                $responseStream = ($::.RestResponse |=> GetErrorResponseDetails $response)
                $responseOutput = if ( $responseStream -ne $null -and $responseStream.length -gt 0 ) {
                    $responseStream
                } else {
                    # Sometimes the response stream has already been read and the value
                    # can be obtained from the error record's ToString()
                    $_.ToString()
                }

                _write-responseverbose $response $responseOutput
                write-error -message $responseStream -targetobject ([PSCustomObject] @{CustomTypeName='RESTException';PSErrorRecord=$_;ResponseStream=$responseStream}) -erroraction silentlycontinue
                throw
            }

            _write-responseverbose $httpResponse $httpResponse.rawContent

            new-so RESTResponse $httpResponse
        } else {
            [PSCustomObject] @{PSTypeName='RESTResponse'}
        }
    }

    function _write-headersverbose( $headers, $substitutions = @{} ) {
        if ( $headers -ne $null ) {
            $headerOutput = @{}
            $headers.keys | foreach {
                $headerOutput[$_] = if ( ! $substitutions.containskey($_) ) {
                    $headers[$_]
                } else {
                    $substitutions[$_]
                }
            }

            ([PSCustomObject] $headerOutput) | fl | out-string | write-verbose
        }
    }

    function _write-responseverbose( $response, $content ) {
        write-verbose ' '
        write-verbose 'Response:'
        write-verbose '********'
        if ( $response -ne $null ) {
            $response | out-string | write-verbose
        } else {
            write-verbose 'No response.'
        }

        write-verbose ' '
        write-verbose 'Response Detail:'
        write-verbose "***************"

        $bodyLines = @("`n`n")
        $bodyLines += ($content | out-string)
        $bodyLines += @("`n`n")
        (-join $bodyLines) | write-verbose

        write-verbose ' '
        write-verbose "Response Headers:"
        write-verbose "****************`n"

        if ( $response -ne $null ) {
            _write-headersverbose $response.headers
        }
    }
}
