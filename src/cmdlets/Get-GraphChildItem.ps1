# Copyright 2020, Adam Edwards
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

. (import-script ../typesystem/TypeManager)
. (import-script common/TypeUriHelper)
. (import-script common/GraphParameterCompleter)
. (import-script common/TypeParameterCompleter)
. (import-script common/TypePropertyParameterCompleter)
. (import-script common/TypeUriParameterCompleter)

function Get-GraphChildItem {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, defaultparametersetname='bytypecollection')]
    param(
        [parameter(parametersetname='byuri',  mandatory=$true)]
        [parameter(parametersetname='byuriandpropertyfilter', mandatory=$true)]
        [Alias('OfUri')]
        [Uri] $Uri,

        [parameter(parametersetname='byobject', mandatory=$true)]
        [parameter(parametersetname='byobjectandpropertyfilter', mandatory=$true)]
        [Alias('OfObject')]
        [PSCustomObject] $GraphItem,

        [parameter(position=0, parametersetname='bytypecollection', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypecollectionpropertyfilter', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeandid', mandatory=$true)]
        [parameter(position=0, parametersetname='typeandpropertyfilter', mandatory=$true)]
        [Alias('OfTypeName')]
        [string] $TypeName,

        [parameter(position=1, parametersetname='bytypeandid', valuefrompipeline=$true, mandatory=$true)]
        [Alias('OfId')]
        [string] $Id,

        [parameter(position=2, parametersetname='byuri')]
        [parameter(position=2, parametersetname='bytypeandid')]
        [parameter(position=2, parametersetname='bytypecollection')]
        [parameter(position=2, parametersetname='typeandpropertyfilter')]
        [string[]] $Property,

        [Alias('WithRelationship')]
        [string[]] $Relationship,

        [string] $GraphName,

        [parameter(parametersetname='bytypecollectionpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='typeandpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='byobjectandpropertyfilter', mandatory=$true)]
        [string] $PropertyFilter,

        [string]$Filter,

        [Alias('SearchString')]
        $SimpleMatch,

        [String] $Search,

        [string[]] $Expand,

        [Alias('Sort')]
        [object[]] $OrderBy = $null,

        [Switch] $Descending,

        [switch] $ContentOnly,

        [switch] $RawContent,

        [switch] $FullyQualifiedTypeName,

        [switch] $SkipPropertyCheck
    )
    begin {
        Enable-ScriptClassVerbosePreference

        if ( $SimpleMatch -and $Filter ) {
            throw "The SimpleMatch and Filter parameters may not both be specified -- specify only one of these parameters and retry the command."
        }

        $remappedParameters = @{}
        foreach ( $parameterName in $PSBoundParameters.Keys ) {
            if ( $parameterName -ne 'TypeName' -and $parameterName -ne 'Uri' -and $parameterName -ne 'Relationship' -and $parameterName -ne 'Id' -and $parameterName -ne 'SkipPropertyCheck' ) {
                $remappedParameters.Add($parameterName, $PSBoundParameters[$parameterName])
            }
        }

        $remappedUris = @()
    }

    process {
        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $Id $GraphItem

        $baseUri = if ( $Uri ) {
            $Uri # RequestInfo may generate a base URI unsuited for our purposes, so don't use it if we have an explicit URI
        } else {
            $requestInfo.Uri
        }

        if ( ! $Relationship ) {
            $remappedUris += $baseUri
        } else {
            foreach ( $relationshipProperty in $RelationShip ) {
                $remappedUris += ( $baseUri.tostring().trimend('/'), $relationshipProperty -join '/' )
            }
        }
    }

    end {
        $ignoreProperty = $SkipPropertyCheck.IsPresent -or ( $Relationship -ne $null )
        foreach ( $remappedUri in $remappedUris ) {
            Get-GraphItem -Uri $remappedUri @remappedParameters -ChildrenOnly:$true -SkipPropertyCheck:$ignoreProperty
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem Uri (new-so GraphUriParameterCompleter LocationOrMethodUri)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem TypeName (new-so TypeUriParameterCompleter TypeName $false)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem Property (new-so TypeUriParameterCompleter Property $false)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem Relationship (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem OrderBy (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem Expand (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphChildItem GraphName (new-so GraphParameterCompleter)

