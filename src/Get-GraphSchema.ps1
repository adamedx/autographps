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
. (import-script GraphContext)
. (import-script Get-GraphVersion)

function Get-GraphSchema {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0, parametersetname='GetSingleNamespace', mandatory=$true)]
        [parameter(position=0, parametersetname='ListSchemas')]
        [String] $Namespace = $null,

        [parameter(position=1, parametersetname='GetSingleNamespace')]
        [String] $SchemaVersion = $null,

        [parameter(parametersetname='SchemasForVersionObject', mandatory=$true)]
        [PSCustomObject] $VersionObject,

        [parameter(parametersetname='SchemasForApiVersion', mandatory=$true)]
        [String] $ApiVersion = $null,

        [parameter(parametersetname='SchemasForApiVersion')]
        [parameter(parametersetname='SchemasForSchemaVersion')]
        [parameter(parametersetname='ListSchemas')]
        [String[]] $NamespaceList = $null,


        [parameter(parametersetname='SchemasForApiVersion')]
        [parameter(parametersetname='SchemasForVersionObject')]
        [parameter(parametersetname='GetSingleNamespace')]
        [switch] $Xml,

        [parameter(parametersetname='ListSchemas', mandatory=$true)]
        [switch] $ListSchemas,

        [parameter(parametersetname='ListSchemas')]
        [switch] $Json,

        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [PSCustomObject] $Connection = $null
    )

    $graphConnection = $::.GraphContext |=> GetConnection $connection $null ([GraphType]::MSGraph) $Cloud 'User.Read'

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
        } else {
            $sourceApiVersion = if ( $ApiVersion -ne $null -and $ApiVersion -ne '' ) {
                $apiVersion
            } else {
                $::.GraphContext |=> GetVersion
            }
            get-graphversion -Connection $graphConnection -version $sourceApiVersion
        }
    }

    $graphNameSpaces = if ( $graphVersion -ne $null ) {
        $graphVersion | gm -membertype noteproperty | select -expandproperty name | where { $_ -ne 'tags' } | foreach {
            $versionName = $_
            $graphSchemaVersions[$versionName] = $graphVersion | select -expandproperty $versionName
        }

        if ( $NameSpaceList -ne $null ) {
            $NamespaceList
        } elseif ( $Namespace -ne $null -and $namespace -ne '' ) {
            @($Namespace)
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
            'v1.0'
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

