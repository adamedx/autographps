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

. (import-script common/TypeMemberFinder)
. (import-script common/TypeUriParameterCompleter)
. (import-script common/MemberParameterCompleter)

function Get-GraphMember {
    [cmdletbinding(positionalbinding=$false)]
    [OutputType('GraphTypeDisplayType')]
    param(
        [parameter(position=1)]
        [Alias('MemberName')]
        [string[]] $Name,

        [parameter(position=0, parametersetname='fortypename', mandatory=$true)]
        [parameter(parametersetname='fortypenamepipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(parametersetname='foritempipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Alias('TypeId')]
        [Alias('FullTypeName')]
        $TypeName,

        [parameter(parametersetname='fortypename')]
        [parameter(parametersetname='fortypenamepipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [ValidateSet('Any', 'Primitive', 'Enumeration', 'Complex', 'Entity')]
        $TypeClass = 'Any',

        [parameter(parametersetname='uri', mandatory=$true)]
        [Alias('GraphUri')]
        $Uri,

        [parameter(parametersetname='uri')]
        [parameter(parametersetname='forobject')]
        [parameter(parametersetname='foritempipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(parametersetname='fortypenamepipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        $GraphName,

        [parameter(parametersetname='forobject', valuefrompipeline=$true, mandatory=$true)]
        [PSTypeName('GraphResponseObject')] $GraphItem,

        [switch] $FullyQualifiedTypeName,

        [parameter(parametersetname='uri')]
        [switch] $StrictUri,

        [string] $MemberFilter,

        [ValidateSet('Property', 'Relationship', 'Method')]
        [string] $MemberType
    )

    begin {
        Enable-ScriptClassVerbosePreference
    }

    process {
        $remappedTypeClass = if ( $TypeClass -ne 'Any' ) {
            $TypeClass
        } else {
            'Unknown'
        }

        $isFullyQualified = $FullyQualifiedTypeName.IsPresent -or ( $TypeName -and ( $TypeClass -ne 'Primitive' -and $TypeName.Contains('.') ) )

        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $isFullyQualified $Uri $null $GraphItem $false $true

        $isMethod = $Uri -and $requestInfo.TypeInfo.UriInfo.Class -in 'Action', 'Function'

        if ( $StrictUri.IsPresent -and ( $isMethod -or $requestInfo.TypeInfo.UriInfo.Collection ) ) {
            throw [ArgumentException]::new('The StrictUri parameter was specified and the Graph location URI is not a valid target for member enumeration because it does not resolve not an instance of a Graph resource (entity)')
        }

        $targetContext = $requestInfo.Context

        $badTypeMessage = if ( $TypeName ) {
            "The specified type '$TypeName' of type class '$TypeClass' was not found in graph '$($targetContext.name)'"
        } else {
            "Unexpected error: the specified URI '$Uri' could not be resolved to any type in graph '$($targetContext.name)'"
        }

        # TODO: Remove the 'scalar' concept altogether
        if ( $requestInfo.TypeName -ne 'scalar' ) {
            $::.TypeMemberFinder |=> FindMembersByTypeName $targetContext $requestInfo.TypeName $MemberType $Name $MemberFilter $badTypeMessage
        }
    }

    end {
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphMember TypeName (new-so TypeParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphMember GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphMember Uri (new-so GraphUriParameterCompleter LocationOrMethodUri)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphMember Name (new-so MemberParameterCompleter TypeName MemberType)
