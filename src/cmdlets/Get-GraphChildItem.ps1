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
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, defaultparametersetname='byuri')]
    param(
        [parameter(position=0, parametersetname='byuri',  mandatory=$true)]
        [parameter(parametersetname='byuripipeline', valuefrompipeline=$true, mandatory=$true)]
        [Alias('OfUri')]
        [Alias('GraphUri')]
        $Uri,

        [parameter(position=0, parametersetname='bytypeandid', mandatory=$true)]
        [parameter(parametersetname='bytypecollection', mandatory=$true)]
        [Alias('OfTypeName')]
        [Alias('FullTypeName')]
        [string] $TypeName,

        [parameter(position=1, parametersetname='bytypeandid', mandatory=$true)]
        [Alias('OfId')]
        [string] $Id,

        [string[]] $Property,

        [parameter(parametersetname='byobject', valuefrompipeline=$true, mandatory=$true)]
        [Alias('OfObject')]
        [PSCustomObject] $GraphItem,

        [Alias('WithRelationship')]
        [string[]] $Relationship,

        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='byuripipeline', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='bytypeandid')]
        [parameter(parametersetname='bytypecollection')]
        [parameter(parametersetname='byobject')]
        [string] $GraphName,

        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='byuripipeline')]
        [parameter(parametersetname='bytypecollection')]
        [HashTable] $PropertyFilter,

        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='byuripipeline')]
        [string] $Filter,

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

        $accumulatedItems = @()

        $filterSpecs = 'PropertyFilter', 'Filter', 'SimpleMatch' |
          where { $PSBoundParameters[$_] }

        if ( ( $filterSpecs | measure-object ).count -gt 1 ) {
            throw [ArgumentException]::new("Only one of the following specified parameters may be specified: {0}" -f ($filterSpecs -join ', '))
        }

        $remappedParameters = @{}
        foreach ( $parameterName in $PSBoundParameters.Keys ) {
            if ( $parameterName -notin 'TypeName', 'Uri', 'Relationship', 'Id', 'SkipPropertyCheck', 'GraphItem' ) {
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
            if ( $GraphItem ) {
                $accumulatedItems += $GraphItem
            } else {
                $remappedUris += $baseUri
            }
        } else {
            foreach ( $relationshipProperty in $RelationShip ) {
                $remappedUris += ( $baseUri.tostring().trimend('/'), $relationshipProperty -join '/' )
            }
        }
    }

    end {
        $ignoreProperty = $SkipPropertyCheck.IsPresent -or ( $Relationship -ne $null )

        if ( $accumulatedItems ) {
            $accumulatedItems | Get-GraphItem @remappedParameters -SkipPropertyCheck:$ignoreProperty -ChildrenOnly:$true
        } else {
            foreach ( $remappedUri in $remappedUris ) {
                Get-GraphItem -Uri $remappedUri @remappedParameters -ChildrenOnly:$true -SkipPropertyCheck:$ignoreProperty
            }
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



