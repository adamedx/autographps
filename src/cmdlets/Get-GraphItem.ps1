# Copyright 2021, Adam Edwards
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
. (import-script common/QueryTranslationHelper)
. (import-script common/GraphParameterCompleter)
. (import-script common/TypeParameterCompleter)
. (import-script common/TypePropertyParameterCompleter)
. (import-script common/TypeUriParameterCompleter)

function Get-GraphItem {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, defaultparametersetname='byuri')]
    param(
        [parameter(parametersetname='byuri', mandatory=$true)]
        [parameter(parametersetname='byuripipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Alias('GraphUri')]
        [Uri] $Uri,

        [parameter(position=0, parametersetname='bytypeandid', mandatory=$true)]
        [Alias('FullTypeName')]
        $TypeName,

        [parameter(position=1, parametersetname='bytypeandid')]
        $Id,

        [Alias('Select')]
        [string[]] $Property,

        [parameter(parametersetname='byobject', valuefrompipeline=$true, mandatory=$true)]
        [PSTypeName('GraphResponseObject')] $GraphItem,

        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='bytypeandid')]
        [parameter(parametersetname='byobject')]
        [parameter(parametersetname='byuripipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        $GraphName,

        $PropertyFilter,

        $Filter,

        [Alias('SearchString')]
        $SimpleMatch,

        [String] $Search,

        [string[]] $Expand,

        [Alias('Sort')]
        [object[]] $OrderBy = $null,

        [Switch] $Descending,

        [switch] $ContentOnly,

        [switch] $RawContent,

        [switch] $ChildrenOnly,

        [switch] $FullyQualifiedTypeName,

        [switch] $SkipPropertyCheck
    )

    begin {
        Enable-ScriptClassVerbosePreference

        $coreParameters = $null

        $filterSpecs = 'PropertyFilter', 'Filter', 'SimpleMatch' |
          where { $PSBoundParameters[$_] }

        if ( ( $filterSpecs | measure-object ).count -gt 1 ) {
            throw [ArgumentException]::new("Only one of the following specified parameters may be specified: {0}" -f ($filterSpecs -join ', '))
        }

        $filterParameter = @{}
        $filterValue = $::.QueryTranslationHelper |=> ToFilterParameter $PropertyFilter $Filter
        if ( $filterValue ) {
            $filterParameter['Filter'] = $filterValue
        }

        $accumulatedItems = @()
    }

    process {
        $targetId = if ( $Id ) {
            $Id
        } elseif ( $GraphItem -and ( $GraphItem | get-member id -erroraction ignore ) ) {
            $GraphItem.Id
        }

        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $targetId $GraphItem

        if ( ! $SkipPropertyCheck.IsPresent ) {
            $::.QueryTranslationHelper |=> ValidatePropertyProjection $requestInfo.Context $requestInfo.TypeInfo $Property
        }

        if ( $requestInfo.IsCollection -and ! $ChildrenOnly.IsPresent -and ( $requestInfo.TypeInfo | gm UriInfo -erroraction ignore ) ) {
            $requestInfo.TypeInfo.UriInfo
        } else {
            $expandArgument = @{}
            if ( $Expand ) {
                $expandArgument['Expand'] = $Expand
            }

            if ( $SimpleMatch ) {
                $filterParameter['Filter'] = $::.QueryTranslationHelper |=> GetSimpleMatchFilter $requestInfo.Context $requestInfo.TypeName $SimpleMatch
            }

            $pagingParameters = @{}

            if ( $pscmdlet.pagingparameters.First -ne $null ) { $pagingParameters['First'] = $pscmdlet.pagingparameters.First }
            if ( $pscmdlet.pagingparameters.Skip -ne $null ) { $pagingParameters['Skip'] = $pscmdlet.pagingparameters.Skip }
            if ( $pscmdlet.pagingparameters.IncludeTotalCount -ne $null ) { $pagingParameters['IncludeTotalCount'] = $pscmdlet.pagingparameters.IncludeTotalCount }

            $coreParameters = @{
                Select = $Property
                ContentOnly = $ContentOnly
                ChildrenOnly = $ChildrenOnly
                Expand = $Expand
                RawContent = $RawContent
                OrderBy = $OrderBy
                Descending = $Descending
                Search = $Search
            }

            if ( ! $GraphItem ) {
                Get-GraphResourceWithMetadata -Uri $requestInfo.Uri -GraphName $requestInfo.Context.name @coreParameters @filterParameter @pagingParameters -DataOnly -StrictOutput:$($ChildrenOnly.IsPresent) -erroraction stop
            } else {
                $accumulatedItems += $GraphItem
            }
        }
    }

    end {
        if ( $accumulatedItems ) {
            $accumulatedItems | Get-GraphResourceWithMetadata @coreParameters @filterParameter @pagingParameters -DataOnly -StrictOutput:$($ChildrenOnly.IsPresent) -erroraction stop
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem Property (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem OrderBy (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem Expand (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem Uri (new-so GraphUriParameterCompleter ([GraphUriCompletionType]::LocationOrMethodUri ))

