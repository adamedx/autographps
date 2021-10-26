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
. (import-script common/RequestHelper)
. (import-script common/TypeUriHelper)
. (import-script common/GraphParameterCompleter)
. (import-script common/TypeParameterCompleter)
. (import-script common/TypePropertyParameterCompleter)
. (import-script common/TypeUriParameterCompleter)

function Set-GraphItem {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='byuri')]
    param(
        [parameter(parametersetname='byuri', mandatory=$true)]
        [parameter(parametersetname='byuripipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Alias('GraphUri')]
        $Uri,

        [parameter(position=0, parametersetname='bytypeandid', mandatory=$true)]
        [Alias('FullTypeName')]
        [string] $TypeName,

        [parameter(position=1, parametersetname='bytypeandid', mandatory=$true)]
        [string] $Id,

        [parameter(parametersetname='byobject')]
        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='byuripipeline')]
        [parameter(position=2, parametersetname='bytypeandid')]
        [string[]] $Property,

        [parameter(parametersetname='byobject')]
        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='byuripipeline')]
        [parameter(position=3, parametersetname='bytypeandid')]
        [object[]] $Value,

        [parameter(parametersetname='byobject', valuefrompipeline=$true, mandatory=$true)]
        [PSTypeName('GraphResponseObject')] $GraphItem,

        [parameter(parametersetname='byobject')]
        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='bytypeandid')]
        [parameter(parametersetname='byuripipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [string] $GraphName,

        [HashTable] $PropertyTable,

        [PSCustomObject] $TemplateObject,

        [string[]] $ExcludeObjectProperty,

        [parameter(parametersetname='byobject')]
        [switch] $MergeGraphItemWithPropertyTable,

        [switch] $FullyQualifiedTypeName,

        [switch] $Recurse,

        [switch] $SetDefaultValues,

        [switch] $SkipPropertyCheck
    )

    begin {
        Enable-ScriptClassVerbosePreference
    }

    process {
        $propertySpecs = 'TemplateObject', 'PropertyTable', 'Property' |
          where { $PSBoundParameters[$_] }

        if ( ( $propertySpecs | measure-object ).count -gt 1 ) {
            throw [ArgumentException]::new("Only one of the following specified parameters may be specified: {0}" -f ($propertySpecs -join ', '))
        }

        $targetId = if ( $Id ) {
            $Id
        } elseif ( $GraphItem -and ( $GraphItem | gm -membertype noteproperty id -erroraction ignore ) ) {
            $GraphItem.Id # This is needed when an object is supplied without an id parameter
        }

        $writeRequestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $targetId $GraphItem

        if ( $GraphItem -and ! $writeRequestInfo.Uri ) {
            throw "Unable to determine Uri for specified GraphItem parameter -- specify the TypeName or Uri parameter and retry the command"
        }

        if ( ! $PropertyTable -and ! $TemplateObject -and ! $writeRequestInfo.TypeName ) {
            throw "Unable to determine the type of object to create -- specify the PropertyTable or TemplateObject parameter and retry the command"
        }

        $newGraphObjectParameters = @{}

        @(
            'Property'
            'Value'
            'GraphName'
            'PropertyTable'
            'FullyQualifiedTypeName'
            'Recurse'
            'SetDefaultValues'
            'SkipPropertyCheck'
        ) | foreach {
            if ( $PSBoundParameters[$_] -ne $null ) {
                $newGraphObjectParameters[$_] = $PSBoundParameters[$_]
            }
        }

        $template = $TemplateObject

        if ( ! $TypeName -and ! $Uri -and ! $property -and ! $TemplateObject -and ( ! $PropertyTable -or $MergeGraphItemWithPropertyTable.IsPresent ) ) {
            $template = $GraphItem
        }

        $newObject = if ( $template ) {
            $::.RequestHelper |=> GraphObjectToWriteRequestObject $template $ExcludeObjectProperty $PropertyTable
        } elseif ( $PropertyTable ) {
            $PropertyTable
        } else {
            New-GraphObject -TypeName $writeRequestInfo.TypeName -TypeClass Entity @newGraphObjectParameters -erroraction 'stop'
        }

        Invoke-GraphApiRequest $writeRequestInfo.Uri -Method PATCH -Body $newObject -connection $writeRequestInfo.Context.connection -erroraction 'stop' | out-null
    }

    end {}
}

$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItem TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItem Property (new-so TypeUriParameterCompleter Property $false)
$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItem ExcludeObjectProperty (new-so TypeUriParameterCompleter Property $false Property $null $null GraphObject)
$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItem GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphItem Uri (new-so GraphUriParameterCompleter LocationUri)
