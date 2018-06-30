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

ScriptClass RESTResponse {
    $statusCode = strict-val [int]
    $statusDescription = strict-val [string]
    $content = $null
    $headers = strict-val [HashTable]
    $images = $null
    $inputFields = $null
    $links = $null
    $rawContent = $null
    $rawContentLength = strict-val [int]
    $contentTypeData = strict-val [HashTable] $null
    $RequiredContentType = $null

    function __initialize ( $webResponse, [string] $requiredContentType  = $null ) {
        $this.statusCode = $webResponse.statusCode
        $this.statusDescription = $webResponse.statusDescription
        $this.rawContent = $webResponse.rawContent
        $this.rawContentLength = $webResponse.rawContentLength
        $this.headers = $webResponse.headers
        $this.content = $webResponse.content
        $this.images = if ( $webResponse | gm images -erroraction silentlycontinue ) { $webResponse.images } else { $null }
        $this.inputFields = if ( $webResponse | gm inputfields -erroraction silentlycontinue ) { $webResponse.inputfields } else { $null }
        $this.links = if ( $webResponse | gm links -erroraction silentlycontinue ) { $webResponse.links } else { $null }
        $this.RequiredContentType = $requiredContentType

        SetContentTypeData
    }

    static {
        function GetErrorResponseDetails([System.Net.WebResponse] $response) {
            if ( $response -ne $null ) {
                $responseStream = $response.getresponsestream()
                if ( $responseStream -ne $null ) {
                    $reader = New-Object System.IO.StreamReader($responseStream)
                    $errorMessage = $reader.ReadToEnd()
                    $errorMessage
                }
            }
        }
    }

    function SetContentTypeData {
        $this.contentTypeData = @{}

        if ( $this.headers -ne $null ) {
            $contentType = $this.headers['Content-Type']
            if ( $contentType -ne $null ) {
                $elements = $contentType -split ';'
                $elements | foreach {
                    $elementValue = $_ -split '='
                    if ($elementValue -eq $null) {
                        $elementValue = $_
                    }

                    $this.contentTypeData[$_] = $elementValue
                }
            }
        }
    }

    function HasJsonContent {
        if ( $this.contentTypeData ) {
            ($this.contentTypeData['application/json'] -ne $null)
        } else {
            $false
        }
    }

    function HasXmlContent {
        if ( $this.contentTypeData ) {
            ($this.contentTypeData['application/xml'] -ne $null)
        } else {
            $false
        }
    }

    function GetDeserializedContent([boolean] $includeCorrectedInput = $false) {
        if ( $this.RequiredContentType -ne $null -and $this.RequiredContentType.length -gt 0 ) {
            if ( $this.contentTypeData[$this.RequiredContentType] -eq $null ) {
                $contentTypeHeader = $this.headers['Content-Type']
                throw "Expected content of type '$($this.RequiredContentType)' but content was not actually found in Content-Type Header '$contentTypeHeader'"
            }
        }

        if ( (HasJsonContent) ) {
            $this.content | convertfrom-json
        } elseif ( (HasXmlContent) ) {
            $deserializedContent = DeserializeXml $this.content
            $deserializedContent.deserializedContent
        } else {
            $null
        }
    }

    function DeserializeXml($xmlContent) {
        # Try to deserialize -- this may fail due to
        # the presence of a unicode byte order marker
        $deserializedXml = try {
            [Xml] $xmlContent
        } catch {
            $null
        }

        if ( $deserializedXml -ne $null ) {
            @{
                deserializedContent = $deserializedXml
                correctedXmlContent = $xmlContent
            }
        } else {
            # Remove Byte Order Mark (BOM) that breaks the
            # XML parser during deserialization.
            # We asssume the file is Unicode, i.e UTF16LE with
            # the corresponding BOM.
            $utf8NoBOMEncoding = new-object System.Text.UTF8Encoding $false
            $unicodeBytes = [System.Text.Encoding]::Unicode.GetBytes($response.content)
            $bomOffset = 6
            $utf8NoBOMBytes = [System.Text.Encoding]::Convert(
                [System.Text.Encoding]::Unicode,
                $utf8NoBOMEncoding,
                $unicodeBytes,
                $bomOffset,
                $unicodeBytes.length - $bomOffset
            )
            $utf8NoBOMContent = $utf8NoBOMEncoding.GetString($utf8NoBOMBytes)
            $deserializedCorrectedXml = [Xml] $utf8NoBOMContent
            @{
                deserializedContent = $deserializedCorrectedXml
                correctedXmlContent = $utf8NoBOMContent
            }
        }
    }
}
