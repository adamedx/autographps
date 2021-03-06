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

function Get-GraphUri {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='bytypeoptionallyqualified')]
    [OutputType('System.Uri')]
    param(
        [parameter(position=0, parametersetname='bytypeoptionallyqualified', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypefullyqualified', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypeoptionallyqualifiedfromobject', mandatory=$true)]
        [parameter(position=0, parametersetname='bytypefullyqualifiedfromobject', mandatory=$true)]
        $TypeName,

        [parameter(position=1, parametersetname='bytypeoptionallyqualified', mandatory=$true)]
        [parameter(position=1, parametersetname='bytypefullyqualified', mandatory=$true)]
        [parameter(position=1, parametersetname='bytypeoptionallyqualifiedfromobject', mandatory=$true)]
        [parameter(position=1, parametersetname='bytypefullyqualifiedfromobject', mandatory=$true)]
        $Id,

        [parameter(position=2)]
        [Alias('WithRelationship')]
        [string] $Relationship,

        [parameter(parametersetname='byuri', mandatory=$true)]
        [parameter(parametersetname='byurifromobject', mandatory=$true)]
        [parameter(parametersetname='addtoexistingurifromobject', mandatory=$true)]
        [Uri] $Uri,

        [parameter(parametersetname='GraphUri', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Uri] $GraphUri,

        [parameter(parametersetname='bytypeoptionallyqualifiedfromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedfromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='byurifromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='addtoexistingurifromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='addtoexistingobjectfromobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='GraphUri', valuefrompipelinebypropertyname=$true)]
        [PSCustomObject] $GraphItem,

        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='byurifromobject')]
        [parameter(parametersetname='bytypeoptionallyqualifiedfromobject')]
        [parameter(parametersetname='bytypefullyqualifiedfromobject')]
        [parameter(parametersetname='addtoexistingurifromobject')]
        [parameter(parametersetname='addtoexistingobjectfromobject')]
        [parameter(parametersetname='GraphUri', valuefrompipelinebypropertyname=$true)]
        [string] $GraphName,

        [switch] $AbsoluteUri,

        [switch] $UnqualifiedUri,

        [switch] $AsString,

        [parameter(parametersetname='bytypefullyqualified', mandatory=$true)]
        [parameter(parametersetname='bytypefullyqualifiedfromobject', mandatory=$true)]
        [parameter(parametersetname='addtoexistingidfullyqualified', mandatory=$true)]
        [switch] $FullyQualifiedTypeName,

        [switch] $SkipPropertyCheck
    )
    begin {
        Enable-ScriptClassVerbosePreference

        if ( $AbsoluteUri.IsPresent -and $UnqualifiedUri.IsPresent ) {
            throw "Only one of the AbsoluteUri or UnqualifiedUri parameters may be specified -- omit these parameters or specify exactly one of them and retry the command"
        }
    }

    process {

        $sourceInfo = $::.TypeUriHelper |=> GetReferenceSourceInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Id $Uri $GraphItem $Relationship
        $resultUri = if ( ! $AbsoluteUri.IsPresent ) {
            if ( $UnqualifiedUri.IsPresent ) {
                $sourceInfo.Uri
            } else {
                $::.GraphUtilities |=> ToLocationUriPath $sourceInfo.requestInfo.context $sourceInfo.Uri
            }
        } else {
            $::.TypeUriHelper |=> ToGraphAbsoluteUri $sourceInfo.RequestInfo.Context $sourceInfo.Uri
        }

        if ( $AsString.IsPresent ) {
            $resultUri.tostring()
        } else {
            [Uri] $resultUri
        }
    }

    end {
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphUri TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphUri Relationship (new-so TypeUriParameterCompleter Property $false NavigationProperty)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphUri GraphName (new-so GraphParameterCompleter)

