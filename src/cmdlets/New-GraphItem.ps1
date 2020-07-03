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

function New-GraphItem {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='bytypeoptionallyqualified')]
    param(
        [parameter(position=0, parametersetname='bytypeoptionallyqualified', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypefullyqualified', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeoptionallyqualifiedpropmap', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypefullyqualifiedpropmap', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeoptionallyqualifiedfromobject', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypefullyqualifiedfromobject', mandatory=$true)]
        $TypeName,

        [parameter(position=1, parametersetname='bytypeoptionallyqualified')]
        [parameter(position=1, parametersetname='bytypefullyqualified')]
        [parameter(position=1, parametersetname='byuri')]
        [parameter(position=1, parametersetname='addtoexistingobject')]
        [parameter(position=1, parametersetname='addtoexistinguri')]
        [string[]] $Property,

        [parameter(position=2, parametersetname='bytypeoptionallyqualified')]
        [parameter(position=2, parametersetname='bytypefullyqualified')]
        [parameter(position=2, parametersetname='byuri')]
        [parameter(position=2, parametersetname='addtoexistingobject')]
        [parameter(position=2, parametersetname='addtoexistinguri')]
        [object[]] $Value,

        [parameter(parametersetname='addtoexistingobjectfromobject', mandatory=$true)]
        [parameter(parametersetname='addtoexistingobjectpropmap', mandatory=$true)]
        [parameter(parametersetname='addtoexistingobject', mandatory=$true)]
        [PSCustomObject] $FromItem,

        [parameter(parametersetname='addtoexistinguri', mandatory=$true)]
        [parameter(parametersetname='addtoexistinguripropmap', mandatory=$true)]
        [parameter(parametersetname='addtoexistingurifromobject', mandatory=$true)]
        [parameter(parametersetname='addtoexistingobjectpropmap', mandatory=$true)]
        [parameter(parametersetname='addtoexistingobjectfromobject', mandatory=$true)]
        [parameter(parametersetname='addtoexistingobject', mandatory=$true)]
        [Alias('WithRelationship')]
        [string] $Relationship,

        [parameter(parametersetname='byuri', mandatory=$true)]
        [parameter(parametersetname='byuripropmap', mandatory=$true)]
        [parameter(parametersetname='byurifromobject', mandatory=$true)]
        [parameter(parametersetname='addtoexistinguri', mandatory=$true)]
        [parameter(parametersetname='addtoexistingurifromobject', mandatory=$true)]
        [parameter(parametersetname='addtoexistinguripropmap', mandatory=$true)]
        [Uri] $Uri,

        [parameter(parametersetname='bytypeoptionallyqualifiedfromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedfromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='byurifromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='addtoexistingurifromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='addtoexistingobjectfromobject', valuefrompipeline=$true, mandatory=$true)]
        [object] $TemplateObject,

        [ValidateSet('POST', 'PUT')]
        [String] $Method = $null,

        $GraphName,

        [parameter(parametersetname='bytypeoptionallyqualifiedpropmap', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedpropmap', mandatory=$true)]
        [parameter(parametersetname='byuripropmap', mandatory=$true)]
        [parameter(parametersetname='addtoexistingidpropmap', mandatory=$true)]
        [parameter(parametersetname='addtoexistingidfullyqualifiedpropmap', mandatory=$true)]
        $PropertyTable,

        [parameter(parametersetname='bytypefullyqualified', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedpropmap', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedfromobject', mandatory=$true)]
        [parameter(parametersetname='addtoexistingidfullyqualified', mandatory=$true)]
        [parameter(parametersetname='addtoexistingidfullyqualifiedpropmap', mandatory=$true)]
        [switch] $FullyQualifiedTypeName,

        [switch] $Recurse,

        [switch] $SetDefaultValues,

        [switch] $SkipPropertyCheck
    )

    begin {
        Enable-ScriptClassVerbosePreference

        $existingSourceInfo = $null

        if ( $Relationship ) {
            $existingSourceInfo = $::.TypeUriHelper |=> GetReferenceSourceInfo $GraphName $null $false $null $Uri $FromItem $Relationship $false

            if ( ! $existingSourceInfo ) {
                throw "Unable to determine Uri for specified type '$TypeName' parameter -- specify an existing item with the Uri parameter and retry the command"
            }
        }
    }

    process {
        $graphContext = $null
        $targetTypeName = $null
        $sourceUri = $null

        if ( $existingSourceInfo ) {
            $graphContext = $existingSourceInfo.RequestInfo.Context
            $sourceUri = $existingSourceInfo.Uri
            $targetType = $::.TypeUriHelper |=> TypeFromUri $sourceUri $graphContext
            $targetTypeName = $targetType.FullTypeName
        } else {
            $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $null $TemplateObject
            $graphContext = $requestInfo.context
            $sourceUri = $requestInfo.Uri
            $targetTypeName = $requestInfo.TypeName
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

        $newObject = if ( $TemplateObject ) {
            $TemplateObject
        } else {
            New-GraphObject -TypeName $targetTypeName -TypeClass Entity @newGraphObjectParameters -erroraction 'stop'
        }

        $createMethod = if ( $Method ) {
            $Method
        } else {
            if ( ( $newObject | gm Id -erroraction ignore ) -and $newObject.Id ) {
                'PUT'
            } else {
                'POST'
            }
        }

        Invoke-GraphRequest $sourceUri -Method $createMethod -Body $newObject -connection $graphContext.connection -erroraction 'stop'
    }

    end {}
}

$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItem TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItem Property (new-so TypeUriParameterCompleter Property $false Property TypeName Relationship)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItem Relationship (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter New-GraphItem GraphName (new-so GraphParameterCompleter)

