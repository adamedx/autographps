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

. (import-script GraphRequest)
. (import-script GraphEndpoint)
. (import-script GraphConnection)
. (import-script Get-GraphVersion)

function Get-GraphSchema {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0,parametersetname='GetSchemaExistingConnection',mandatory=$true)]
        [parameter(position=0,parametersetname='ListSchemasExistingConnection',mandatory=$true)]
        [parameter(position=0,parametersetname='GetSchema',mandatory=$true)]
        [parameter(position=0,parametersetname='ListSchemas',mandatory=$true)]
        [String] $Namespace = $null,

        [parameter(position=1, parametersetname='GetSchemaExistingConnection', mandatory=$true)]
        [parameter(position=1, parametersetname='GetSchema', mandatory=$true)]
        [String] $SchemaVersion = $null,

        [parameter(parametersetname='GetSchemaGraphObjectExistingConnection', mandatory=$true)]
        [parameter(parametersetname='GetSchemaGraphObject', mandatory=$true)]
        [PSCustomObject] $VersionObject,

        [parameter(parametersetname='GetSchemaGraphApiVersionExistingConnection', mandatory=$true)]
        [parameter(parametersetname='GetSchemaGraphApiVersion', mandatory=$true)]
        [String] $ApiVersion = $null,

        [parameter(parametersetname='GetSchemaGraphApiVersionExistingConnection')]
        [parameter(parametersetname='GetSchemaGraphObjectExistingConnection')]
        [parameter(parametersetname='GetSchemaGraphApiVersion')]
        [parameter(parametersetname='GetSchemaGraphObject')]
        [String[]] $NamespaceList = $null,

        [parameter(parametersetname='GetSchemaGraphApiVersionExistingConnection')]
        [parameter(parametersetname='GetSchemaGraphObjectExistingConnection')]
        [parameter(parametersetname='GetSchemaGraphApiVersion')]
        [parameter(parametersetname='GetSchemaGraphObject')]
        [parameter(parametersetname='GetSchema')]
        [switch] $Xml,

        [parameter(parametersetname='ListSchemasExistingConnection', mandatory=$true)]
        [parameter(parametersetname='ListSchemas', mandatory=$true)]
        [switch] $ListSchemas,

        [parameter(parametersetname='ListSchemasExistingConnection')]
        [parameter(parametersetname='ListSchemas')]
        [switch] $Json,

        [parameter(parametersetname='GetSchemaGraphApiVersion')]
        [parameter(parametersetname='GetSchemaGraphObject')]
        [parameter(parametersetname='GetSchema')]
        [parameter(parametersetname='ListSchemas')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='GetSchemaGraphApiVersionExistingConnection',mandatory=$true)]
        [parameter(parametersetname='GetSchemaGraphObjectExistingConnection',mandatory=$true)]
        [parameter(parametersetname='GetSchema',mandatory=$true)]
        [parameter(parametersetname='ListSchemas')]
        [PSCustomObject] $Connection = $null
    )

    $graphConnection = if ( $Connection -eq $null ) {
        $::.GraphConnection |=> GetDefaultConnection ([GraphType]::MSGraph) $Cloud 'User.Read'
    } else {
        $Connection
    }

    $relativeBase = 'schemas'
    $headers = @{
        'Content-Type'='application/json'
        'Accept-Charset'='utf-8'
    }

    if ( $ListSchemas.ispresent ) {
        return ListSchemas $graphConnection $Namespace $relativeBase $headers $Json.ispresent
    }

    $headers['Accept'] = 'application/xml'

    $graphSchemaVersions = @{}

    $graphVersion = if ( $SchemaVersion -eq $null -or $SchemaVersion.length -eq 0 ) {
        if ( $VersionObject -ne $null ) {
            $VersionObject
        } elseif ( $ApiVersion -ne $null) {
            get-graphversion -Connection $graphConnection -version $ApiVersion
        }
    }

    $graphNameSpaces = if ( $graphVersion -ne $null ) {
        $graphVersion | gm -membertype noteproperty | select -expandproperty name | where { $_ -ne 'tags' } | foreach {
            $versionName = $_
            $graphSchemaVersions[$versionName] = $graphVersion | select -expandproperty $versionName
        }

        if ( $NameSpaceList -ne $null ) {
            $NamespaceList
        } else {
            $graphSchemaVersions.keys
        }
    } else {
        $graphSchemaVersions[$Namespace] = $SchemaVersion
        @($Namespace)
    }

    $results = @()
    $graphNamespaces | foreach {
        $graphSchemaVersion = $graphSchemaVersions[$_]
        $apiVersionDisplay = if ( $apiVersion -ne $null ) {
            "'$apiVersion'"
        } else {
            ''
        }

        if ($graphSchemaVersion -eq $null) {
            throw "Specified namespace '$_' does not exist in the provided version '$apiVersionDisplay'"
        }

        $relativeUri = $relativeBase, $_, $graphSchemaVersion -join '/'

        $request = new-so GraphRequest $graphConnection $relativeUri GET $headers
        $response = $request |=> Invoke

        $schema = if ( $XML.ispresent ) {
            $response |=> Content
        } else {
            $response.Entities.schema
        }

        $results += [PSCustomObject] $schema
    }

    $results
}

function ListSchemas($graphConnection, $namespace, $relativeBase, $headers, $jsonOutput) {
    $relativeUri = if ($Namespace -ne $null) {
        $relativeBase, $Namespace -join '/'
    } else {
        $relativeBase
    }

    $request = new-so GraphRequest $graphConnection $relativeUri GET $headers
    $response = $request |=> Invoke

    if ( $JSON.ispresent ) {
        $response |=> content
    } else {
        [PSCustomObject] $response.Entities
    }
}

