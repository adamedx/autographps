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

function Add-GraphRelatedItem {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='bytypeoptionallyqualified')]
    param(
        [parameter(position=0, parametersetname='byuri', mandatory=$true)]
        [parameter(position=0, parametersetname='byuripropmap', mandatory=$true)]
        [parameter(position=0, parametersetname='byurifromobject', mandatory=$true)]
        [parameter(position=0, parametersetname='addtoexistingurifromobject', mandatory=$true)]
        [parameter(position=0, parametersetname='addtoexistinguripropmap', mandatory=$true)]
        [Uri] $Uri,

        [parameter(position=1, mandatory=$true)]
        [Alias('WithRelationship')]
        [string] $Relationship,

        [parameter(position=2, parametersetname='bytypeoptionallyqualified')]
        [parameter(position=2, parametersetname='bytypefullyqualified')]
        [parameter(position=2, parametersetname='byuri', mandatory=$true)]
        [parameter(position=2, parametersetname='addtoexistingobject')]
        [string[]] $Property,

        [parameter(position=3, parametersetname='bytypeoptionallyqualified')]
        [parameter(position=3, parametersetname='bytypefullyqualified')]
        [parameter(position=3, parametersetname='byuri')]
        [parameter(position=3, parametersetname='addtoexistingobject')]
        [parameter(position=3, parametersetname='addtoexistinguri')]
        [object[]] $Value,

        [parameter(parametersetname='bytypeoptionallyqualified', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualified', mandatory=$true)]
        [parameter(parametersetname='bytypeoptionallyqualifiedpropmap', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedpropmap', mandatory=$true)]
        [parameter(parametersetname='bytypeoptionallyqualifiedfromobject', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedfromobject', mandatory=$true)]
        $TypeName,

        [parameter(parametersetname='bytypeoptionallyqualified', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualified', mandatory=$true)]
        [parameter(parametersetname='bytypeoptionallyqualifiedpropmap', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedpropmap', mandatory=$true)]
        [parameter(parametersetname='bytypeoptionallyqualifiedfromobject', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedfromobject', mandatory=$true)]
        $Id,

        [parameter(parametersetname='addtoexistingobjectfromobject', mandatory=$true)]
        [parameter(parametersetname='addtoexistingobjectpropmap', mandatory=$true)]
        [parameter(parametersetname='addtoexistingobject', mandatory=$true)]
        [PSCustomObject] $FromObject,

        [parameter(parametersetname='bytypeoptionallyqualifiedfromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedfromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='byurifromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='addtoexistingurifromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='addtoexistingobjectfromobject', valuefrompipeline=$true, mandatory=$true)]
        [object] $GraphItem,

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

        $sourceInfo = $::.TypeUriHelper |=> GetReferenceSourceInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Id $Uri $GraphItem $Relationship

        $remappedParameters = @{}
        foreach ( $parameterName in $PSBoundParameters.Keys ) {
            if ( $parameterName -ne 'TypeName' -and $parameterName -ne 'Uri' -and $parameterName -ne 'Relationship' -and $parameterName -ne 'Id' -and $parameterName ) {
                $remappedParameters.Add($parameterName, $PSBoundParameters[$parameterName])
            }
        }

        $newObjects = @()
    }

    process {

        if ( $GraphItem ) {
            $newObjects += $GraphItem
        }
    }

    end {

        if ( $newObjects ) {
            $newObjects | New-GraphResourceItem -Uri $sourceInfo.Uri @remappedParameters
        } else {
            New-GraphResourceItem -Uri $sourceInfo.Uri @remappedParameters
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Add-GraphRelatedItem TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Add-GraphRelatedItem Property (new-so TypeUriParameterCompleter Property $false Property TypeName Relationship)
$::.ParameterCompleter |=> RegisterParameterCompleter Add-GraphRelatedItem Relationship (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Add-GraphRelatedItem GraphName (new-so GraphParameterCompleter)



