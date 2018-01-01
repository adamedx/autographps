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

. (import-script RESTRequest)
. (import-script GraphEndpoint)
. (import-script GraphConnection)

function Get-GraphSchema {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0,parametersetname='GetSchema', mandatory=$true)][parameter(parametersetname='ListSchemas')][String] $Namespace = $null,
        [parameter(position=0,parametersetname='GetNamespacesSchema',mandatory=$true)][PSCustomObject] $GraphVersion,
        [parameter(position=1,parametersetname='GetSchema',mandatory=$true)][String] $SchemaVersion,
        [parameter(position=1,parametersetname='GetNamespacesSchema')][String[]] $NamespaceList = $null,
        [parameter(parametersetname='GetSchema')][switch] $Xml,
        [parameter(parametersetname='ListSchemas',mandatory=$true)][switch] $ListSchemas,
        [parameter(parametersetname='ListSchemas')][switch] $Json,
        [parameter(parametersetname='GetSchema')][parameter(parametersetname='ListSchemas')][parameter(parametersetname='NewConnection')][GraphCloud] $Cloud = [GraphCloud]::Public,
        [parameter(parametersetname='GetSchema')][parameter(parametersetname='ListSchemas')][parameter(parametersetname='ExistingConnection', mandatory=$true)][PSCustomObject] $Connection = $null
    )

    $graphConnection = if ( $Connection -eq $null ) {
        $::.GraphConnection |=> NewSimpleConnection ([GraphType]::MSGraph) $Cloud 'User.Read'
    } else {
        $Connection
    }

    $graphConnection |=> Connect

    $relativeBase = 'schemas'
    $headers = @{
        'Content-Type'='application/json'
        'Authorization'=$graphConnection.Identity.token.CreateAuthorizationHeader()
    }

    if ( $ListSchemas.ispresent ) {
        return ListSchemas $graphConnection $Namespace $relativeBase $headers $Json.ispresent
    }

    $graphSchemaVersions = @{}
    $graphNameSpaces = if ( $NamespaceList -ne $null ) {
        $graphNamespaces = $NamespaceList
    } else {
        @($Namespace)
        $graphSchemaVersions[$Namespace] = $SchemaVersion
    }

    $results = @()
    $graphNamespaces | foreach {
        $graphSchemaVersion = $graphSchemaVersions[$_]

        if ( $graphSchemaVersion -eq $null ) {
            throw 'Not yet implemented'
        }

        $relativeUri = $relativeBase, $_, $graphSchemaVersion -join '/'

        $queryUri = [Uri]::new($graphConnection.GraphEndpoint.Graph, $relativeUri)

        $request = new-so RESTRequest $queryUri GET $headers
        $response = $request |=> Invoke

        $deserializableSchema = DeserializeXmlSchema($response.content)

        $schema = if ( $XML.ispresent ) {
            # Return the corrected schema in case it included a
            # UTF16LE BOM, which will be removed so the caller
            # can use the standard XML parser to parse it successfully
            $deserializableSchema.correctedXmlContent
        } else {
            $deserializableSchema.deserializedContent.schema
        }

        $results += $schema
    }

    $results
}

function ListSchemas($graphConnection, $namespace, $relativeBase, $headers, $jsonOutput) {
    $relativeUri = if ($Namespace -ne $null) {
        $relativeBase, $Namespace -join '/'
    } else {
        $relativeBase
    }

    $graphConnection |=> Connect

    $queryUri = [Uri]::new($graphConnection.GraphEndpoint.Graph, $relativeUri)

    $request = new-so RESTRequest $queryUri GET $headers
    $response = $request |=> Invoke

    if ( $JSON.ispresent ) {
        $response.content
    } else {
        $response.content | convertfrom-json
    }
}

function DeserializeXmlSchema($xmlContent) {
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
