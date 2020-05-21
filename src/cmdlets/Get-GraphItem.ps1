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
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, defaultparametersetname='bytypeandid')]
    param(
        [parameter(position=0, parametersetname='bytypeandid', mandatory=$true)]
        [parameter(position=0, parametersetname='typeandpropertyfilter', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeandfilter', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeandsearch', valuefrompipeline=$true, mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeandsimplematch', mandatory=$true)]
        $TypeName,

        [parameter(position=1, parametersetname='bytypeandid', valuefrompipeline=$true, mandatory=$true)]
        $Id,

        [parameter(position=2, parametersetname='bytypeandid')]
        [parameter(position=2, parametersetname='typeandpropertyfilter')]
        [parameter(position=2, parametersetname='bytypeandfilter')]
        [parameter(position=2, parametersetname='bytypeandsimplematch')]
        [parameter(position=2, parametersetname='byuri')]
        [parameter(position=2, parametersetname='byuriandfilter')]
        [parameter(position=2, parametersetname='byobjectandfilter')]
        [string[]] $Property,

        [parameter(parametersetname='byuri', mandatory=$true)]
        [parameter(parametersetname='byuriandfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandsimplematch', mandatory=$true)]
        [parameter(parametersetname='byuriandsearch', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='byuriandpropertyfilter', mandatory=$true)]
        [Uri] $Uri,

        [parameter(parametersetname='byobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='byobjectandfilter', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='byobjectandsearch', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='byobjectandpropertyfilter', valuefrompipeline=$true, mandatory=$true)]
        [PSCustomObject] $GraphItem,

        $GraphName,

        [parameter(parametersetname='typeandpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandpropertyfilter', mandatory=$true)]
        [parameter(parametersetname='byobjectandpropertyfilter', mandatory=$true)]
        $PropertyFilter,

        [parameter(parametersetname='bytypeandfilter', mandatory=$true)]
        [parameter(parametersetname='byuriandfilter', mandatory=$true)]
        [parameter(parametersetname='byobjectandfilter', mandatory=$true)]
        $Filter,

        [parameter(parametersetname='bytypeandsimplematch', mandatory=$true)]
        [parameter(parametersetname='byuriandsimplematch', mandatory=$true)]
        [parameter(parametersetname='byobjectandsimplematch', mandatory=$true)]
        [Alias('SearchString')]
        $SimpleMatch,

        [parameter(parametersetname='bytypeandsearch', mandatory=$true)]
        [parameter(parametersetname='byuriandsearch', mandatory=$true)]
        [parameter(parametersetname='byobjectandsearch', mandatory=$true)]
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

        if ( $Filter -and $SimpleMatch ) {
            throw 'Only one of Filter and SimpleMatch arguments may be specified'
        }

        $filterParameter = @{}
        $filterValue = $::.QueryTranslationHelper |=> ToFilterParameter $PropertyFilter $Filter
        if ( $filterValue ) {
            $filterParameter['Filter'] = $filterValue
        }
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

            Get-GraphResourceWithMetadata -Uri $requestInfo.Uri -GraphName $requestInfo.Context.name -erroraction 'stop' -select $Property @filterParameter -ContentOnly:$($ContentOnly.IsPresent) -ChildrenOnly:$($ChildrenOnly.IsPresent) -Expand $Expand -RawContent:$($RawContent.IsPresent) @pagingParameters -OrderBy $OrderBy -Descending:$($Descending.IsPresent) -Search $Search
        }
    }

    end {}
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem Property (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem OrderBy (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem Expand (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphItem Uri (new-so GraphUriParameterCompleter ([GraphUriCompletionType]::LocationOrMethodUri ))
