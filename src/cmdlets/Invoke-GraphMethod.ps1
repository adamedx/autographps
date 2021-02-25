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
. (import-script common/FunctionParameterHelper)

function Invoke-GraphMethod {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='byuri', supportspaging=$true)]
    param(
        [parameter(parametersetname='byuripipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(position=0, parametersetname='byuri', mandatory=$true)]
        [Alias('GraphUri')]
        [Uri] $Uri = $null,

        [parameter(position=1, parametersetname='bytypeandid')]
        [parameter(position=1, parametersetname='byobject')]
        [parameter(position=1, parametersetname='byuripipeline')]
        [parameter(position=1, parametersetname='byuri')]
        [string[]] $Parameter,

        [parameter(position=2, parametersetname='bytypeandid')]
        [parameter(position=2, parametersetname='byobject')]
        [parameter(position=2, parametersetname='byuripipeline')]
        [parameter(position=2, parametersetname='byuri')]
        [object[]] $Value,

        [parameter(parametersetname='bytypeandid', mandatory=$true)]
        [parameter(parametersetname='byobject', mandatory=$true)]
        [parameter(parametersetname='byuripipeline', mandatory=$true)]
        [parameter(parametersetname='byuri')]
        [string] $MethodName,

        [parameter(parametersetname='bytypeandid', mandatory=$true)]
        [Alias('FullTypeName')]
        [String] $TypeName,

        [parameter(parametersetname='bytypeandid', mandatory=$true)]
        [String] $Id,

        [string[]] $Property,

        [HashTable] $ParameterTable,

        [Alias('Body')]
        [PSCustomObject] $ParameterObject,

        [parameter(parametersetname='byobject', mandatory=$true)]
        [PSCustomObject] $GraphItem,

        [parameter(parametersetname='byuripipeline', valuefrompipelinebypropertyname=$true)]
        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='bytypeandid')]
        [parameter(parametersetname='byobject')]
        $GraphName = $null,

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

        [switch] $NoMetadata,

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

        $parameterSpecs = 'ParameterObject', 'ParameterTable', 'Parameter' |
          where { $PSBoundParameters[$_] }

        if ( ( $parameterSpecs | measure-object ).count -gt 1 ) {
            throw [ArgumentException]::new("Only one of the following specified parameters may be specified: {0}" -f ($parameterSpecs -join ', '))
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
        $targetUri = if ( $Uri ) {
            $Uri
        } elseif ( ! $TypeName ) {
            '.'
        }

        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $targetUri $Id $GraphItem $true

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
        $targetTypeName = if ( $requestInfo | gm FullTypeName -erroraction ignore ) {
            $requestInfo.FullTypeName
        } else {
            $requestInfo.TypeInfo.FullTypeName
        }

        if ( $targetUri ) {
            $typeUriInfo = Get-GraphUriInfo $targetUri -GraphName $requestInfo.Context.Name -erroraction stop
            if ( ! $MethodName -and $typeUriInfo.Class -notin 'Action', 'Function' ) {
                throw [ArgumentException]::new("The URI '$targetUri' is not a method URI but the MethodName parameter was not specified -- please specify a method URI or include the MethodName parameter and retry the command")
            }
        }

        $methodUri = if ( $MethodName ) {
            $requestInfo.Uri.tostring().trimend('/'), $MethodName -join '/'
        } elseif ( $requestInfo.TypeInfo.UriInfo.Class -in 'Action', 'Function' ) {
            $targetMethodName = $typeUriInfo.Name
            $typeUriInfo = Get-GraphUriInfo $typeUriInfo.ParentPath -GraphName $requestInfo.Context.Name -erroraction stop
            $targetTypeName = $typeUriInfo.FullTypeName
            $targetUri.tostring()
        } else {
            $requestInfo.Uri.tostring()
        }

        if ( ! $methodUri ) {
            throw 'Unable to determine the method Uri from the parameters specified.'
        }

        $owningType = Get-GraphType $targetTypeName -GraphName $requestInfo.Context.Name -erroraction stop

        $method = $owningType.Methods | where Name -eq $targetMethodName

        if ( ! $method ) {
            if ( $targetUri -or $GraphItem ) {
                throw [ArgumentException]::new("The specified method URI '$methodUri' could not be found in the graph '$($requestInfo.Context.Name)'")
            } else {
                throw [ArgumentException]::new("The specified method '$MethodName' could not be found for the '$TypeName' in the graph '$($requestInfo.Context.Name)'")
            }
        }

        $methodUriInfo = Get-GraphUriInfo $methodUri -GraphName $requestInfo.Context.Name -erroraction stop
        $methodClass = $methodUriInfo.Class

        if ( $methodClass -notin 'Action', 'Function' ) {
            throw "Invalid method class '$methodClass' -- only 'Action' and 'Function' methods are supported"
        }

        $parameterNames = @()

        $methodBody = if ( $methodClass ) {
            if ( $ParameterObject ) {
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

                $parameterNames = $parameters.keys | foreach { $_ }
                $parameters
            }
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
"@  -f ($method.parameters.name | measure-object).count, $missingParameterMessage, $invalidParameterMessage, ( $method.parameters.name -join ', ' )
                throw [ArgumentException]::new($errorMessage)
            }
        }

        $bodyParam = if ( $methodBody ) {
            @{Body=$methodBody}
        } else {
            @{}
        }

        $methodUriWithParameters = if ( $methodClass -eq 'Function' ) {
            $parameterString = $::.FunctionParameterHelper |=> ToUriParameterString $methodBody
            $methodUri.tostring().trimend('/') + $parameterString
        } else {
            $methodUri
        }

        Invoke-GraphApiRequest -Uri $methodUriWithParameters -Method POST @bodyParam -Connection $requestInfo.Context.Connection @coreParameters @filterParameter @pagingParameters -erroraction stop | foreach {
            # Note that there is not relation between the structure of the URI used to make an action or function
            # request and the types returned in the response -- they could be literally anything. The method below
            # addresses this by creating a public segment that reflects the type returned in the response metadata,
            # which is the only way to know the returned type. This can also be true in conventional GET requests
            # for entity types or their structural properties, but only due to polymorphism, and of course in those
            # cases rather than not having a type at all, the worst case is that we are forced to assume the least-derived
            # type, which is a situation of information loss but not of incorrectness.
            if ( ! $NoMetadata.IsPresent ) {
                $::.SegmentHelper |=> ToPublicSegmentFromGraphResponseObject $requestInfo.Context $_
            } else {
                $_
            }
        }
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

