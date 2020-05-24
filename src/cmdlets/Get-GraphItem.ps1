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
. (import-script common/QueryTranslationHelper)
. (import-script common/GraphParameterCompleter)
. (import-script common/TypeParameterCompleter)
. (import-script common/TypePropertyParameterCompleter)
. (import-script common/TypeUriParameterCompleter)

function Get-GraphItem {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, defaultparametersetname='byobject')]
    param(
        [parameter(parametersetname='bytypeandidpipe', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeandid', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(position=0, parametersetname='typeandpropertyfilter', mandatory=$true)]
        [Alias('FullTypeName')]
        $TypeName,

        [parameter(parametersetname='bytypeandidpipe', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(position=1, parametersetname='bytypeandid', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        $Id,

        [parameter(position=2, parametersetname='bytypeandid')]
        [parameter(position=2, parametersetname='bytypeandidpipe')]
        [parameter(position=2, parametersetname='typeandpropertyfilter')]
        [parameter(position=2, parametersetname='byuri')]
        [string[]] $Property,

        [parameter(parametersetname='byuri', mandatory=$true)]
        [parameter(parametersetname='byuriandpropertyfilter', mandatory=$true)]
        [Uri] $Uri,

        [parameter(parametersetname='byobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='byobjectandpropertyfilter', valuefrompipeline=$true, mandatory=$true)]
        [PSCustomObject] $GraphItem,

        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='byuriandpropertyfilter')]
        [parameter(parametersetname='bytypeandid')]
        [parameter(parametersetname='bytypeandidpipe', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(parametersetname='byobject')]
        [parameter(parametersetname='byobjectandpropertyfilter')]
        [parameter(parametersetname='typeandpropertyfilter')]
        $GraphName,

        [parameter(parametersetname='typeandpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='byobjectandpropertyfilter', mandatory=$true)]
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

        if ( $Filter -and $SimpleMatch ) {
            throw 'Only one of Filter and SimpleMatch arguments may be specified'
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
