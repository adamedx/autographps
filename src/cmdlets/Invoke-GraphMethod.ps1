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
. (import-script common/MethodNameParameterCompleter)
. (import-script common/MethodUriParameterCompleter)

function Invoke-GraphMethod {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, defaultparametersetname='bytypeandid')]
    param(
        [parameter(parametersetname='bytypeandidpipe', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeandid', mandatory=$true)]
        [parameter(position=0, parametersetname='typeandpropertyfilter', mandatory=$true)]
        [Alias('FullTypeName')]
        $TypeName,

        [parameter(parametersetname='bytypeandidpipe', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(position=1, parametersetname='bytypeandid', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(position=1, parametersetname='typeandpropertyfilter', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        $Id,

        [parameter(position=2, parametersetname='bytypeandid', mandatory=$true)]
        [parameter(position=2, parametersetname='bytypeandidpipe', mandatory=$true)]
        [parameter(position=2, parametersetname='typeandpropertyfilter', mandatory=$true)]
        [parameter(position=2, parametersetname='byuri')]
        [parameter(position=2, parametersetname='byuriandpropertyfilter')]
        [string] $MethodName,

        [parameter(position=3, parametersetname='bytypeandid')]
        [parameter(position=3, parametersetname='bytypeandidpipe')]
        [parameter(position=3, parametersetname='typeandpropertyfilter')]
        [parameter(position=3, parametersetname='byuri')]
        [parameter(position=3, parametersetname='byuriandpropertyfilter')]
        [string[]] $Parameter,

        [parameter(position=4, parametersetname='bytypeandid')]
        [parameter(position=4, parametersetname='bytypeandidpipe')]
        [parameter(position=4, parametersetname='typeandpropertyfilter')]
        [parameter(position=4, parametersetname='byuri')]
        [parameter(position=4, parametersetname='byuriandpropertyfilter')]
        [object[]] $Value,

        [parameter(parametersetname='bytypeandid')]
        [parameter(parametersetname='bytypeandidpipe')]
        [parameter(parametersetname='typeandpropertyfilter')]
        [parameter(parametersetname='byuri')]
        [string[]] $Property,

        [HashTable] $ParameterTable,

        [Alias('Body')]
        [PSCustomObject] $ParameterObject,

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

        [switch] $RawContent,

        [switch] $ChildrenOnly,

        [switch] $FullyQualifiedTypeName,

        [switch] $SkipPropertyCheck,

        [switch] $SkipParameterCheck
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

        $valueLength = 0

        if ( $Value ) {
            $valueLength = $Value.length
        }

        if ( $Parameter -and $Parameter.length -ne $valueLength ) {
            throw [ArgumentException]::new("$($Parameter.length) parameters were specified by the Parameter argument, but an unequal number of values, $valueLength, was specified through the Value argument.")
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
            Expand = $Expand
            RawContent = $RawContent
            OrderBy = $OrderBy
            Descending = $Descending
            Search = $Search
        }

        $targetMethodName = $MethodName
        $targetTypeName = $TypeName
        $typeInfo = $null

        if ( $Uri ) {
            $typeInfo = Get-GraphUriInfo $Uri -GraphScope $requestInfo.Context.Name -erroraction stop
            if ( ! $MethodName -and $typeInfo.Class -notin 'Action', 'Function' ) {
                throw [ArgumentException]::new("The URI '$Uri' is not a method but the MethodName parameter was not specified -- please specify a method URI or include the MethodName parameter and retry the command")
            }
            $targetTypeName = $typeInfo.FullTypeName
        }

        $methodUri = if ( $MethodName ) {
            $requestInfo.Uri.tostring().trimend('/'), $MethodName -join '/'
        } else {
            $targetMethodName = $typeInfo.Name
            $typeInfo = Get-GraphUriInfo $typeInfo.ParentPath -GraphScope $requestInfo.Context.Name -erroraction stop
            $targetTypeName = $typeInfo.FullTypeName
            $requestInfo.Uri.tostring()
        }

        $owningType = Get-GraphType $targetTypeName -GraphName $requestInfo.Context.Name -erroraction stop

        $method = $owningType.Methods | where Name -eq $targetMethodName

        if ( ! $method ) {
            if ( $Uri ) {
                throw [ArgumentException]::new("The specified method URI '$Uri' could not be found in the graph '$($requestInfo.Context.Name)'")
            } else {
                throw [ArgumentException]::new("The specified method '$MethodName' could not be found for the '$TypeName' in the graph '$($requestInfo.Context.Name)'")
            }
        }

        $parameterNames = @()

        $methodBody = if ( $ParameterObject ) {
            $parameterNames = $ParameterObject | gm -membertype noteproperty | select -expandproperty name
            $ParameterObject
        } elseif ( $ParameterTable ) {
            $parameterNames = $parameterTable.keys
            $ParameterTable
        } elseif ( $Parameter ) {
            $parameters = @{}
            $parameterIndex = 0
            foreach ( $parameterName in $Parameter ) {
                $parameters.Add($parameterName, $Value[$parameterIndex])
                $parameterIndex++
            }

            $parameterNames = $parameters.keys
            $parameters
        }

        if ( ! $SkipParameterCheck.IsPresent -and $method.parameters) {
            $difference = compare-object $parameterNames $method.parameters.name
            if ( $difference ) {
                $invalidParameters = ( $difference | where sideindicator -eq '<=' | select -expandproperty inputobject ) -join ', '
                $missingParameters = ( $difference | where sideindicator -eq '=>' | select -expandproperty inputobject ) -join ', '

                $invalidParameterMessage = if ( $invalidParameters ) {
                    "`n  - Invalid parameter names: '$invalidParameters'"
                }

                $missingParameterMessage = if ( $missingParameters ) {
                    "`n  - Missing parameters: '$missingParameters'"
                }

                $errorMessage = @"
Unable to invoke method '$targetMethodName' on type '$($owningType.TypeId)' with {0} parameters. This was due to:
 
{1}{2}
 
The complete set of valid parameters is '{3}'.
"@  -f $method.parameters.name.count, $missingParameterMessage, $invalidParameterMessage, ( $method.parameters.name -join ', ' )
                throw [ArgumentException]::new($errorMessage)
            }
        }

        $bodyParam = if ( $methodBody ) {
            @{Body=$methodBody}
        } else {
            @{}
        }

        Invoke-GraphRequest -Uri $methodUri -Method POST @bodyParam -Connection $requestInfo.Context.Connection @coreParameters @filterParameter @pagingParameters -erroraction stop
    }

    end {
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Invoke-GraphMethod TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Invoke-GraphMethod MethodName (new-so MethodUriParameterCompleter MethodName)
$::.ParameterCompleter |=> RegisterParameterCompleter Invoke-GraphMethod Parameter (new-so MethodUriParameterCompleter ParameterName)
$::.ParameterCompleter |=> RegisterParameterCompleter Invoke-GraphMethod OrderBy (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Invoke-GraphMethod Expand (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Invoke-GraphMethod GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Invoke-GraphMethod Uri (new-so GraphUriParameterCompleter ([GraphUriCompletionType]::LocationOrMethodUri ))
