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

. (import-script common/MethodDisplayType)
. (import-script common/TypeMemberFinder)
. (import-script common/TypeUriParameterCompleter)
. (import-script common/MemberParameterCompleter)

function Get-GraphMethod {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='uri')]
    [OutputType('MethodDisplayType')]
    param(
        [parameter(position=0, parametersetname='fortypename', mandatory=$true)]
        [parameter(parametersetname='fortypenamepipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Alias('TypeId')]
        $TypeName,

        [parameter(position=1)]
        [Alias('MethodName')]
        [string] $Name,

        [parameter(parametersetname='uri', mandatory=$true)]
        [Alias('GraphUri')]
        $Uri,

        [parameter(parametersetname='fortypenamepipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(parametersetname='forobject')]
        [parameter(parametersetname='uri')]
        $GraphName,

        [parameter(parametersetname='forobject', valuefrompipeline=$true, mandatory=$true)]
        [PSTypeName('GraphResponseObject')] $GraphItem,

        [switch] $FullyQualifiedTypeName,

        [switch] $Parameters,

        [string] $MethodFilter
    )

    begin {
        Enable-ScriptClassVerbosePreference
    }

    process {
        $forwardedParameters = @{MemberType='Method'}

        'Name', 'TypeName', 'Uri', 'GraphName', 'GraphItem', 'FullyQualifiedTypeName' | foreach {
            if ( $PSBoundParameters.ContainsKey($_) ) {
                $forwardedParameters.Add($_, $PSBoundParameters[$_])
            }
        }

        $targetType = $TypeName

        $isMethodUri = $false

        if ( $Uri ) {
            $uriInfo = Get-GraphUriInfo -Uri $Uri
            $isMethodUri = $uriInfo.Class -in 'Action', 'Function'
            if ( $isMethodUri ) {
                if ( $Name ) {
                    throw [ArgumentException]::new('The Graph location URI parameter specified a method, so the method Name parameter may not also be specified')
                }
                $forwardedParameters['Uri'] = $uriInfo.ParentPath
                $forwardedParameters['Name'] = $uriInfo.Name
                $forwardedParameters.Add('StrictUri', [System.Management.Automation.SwitchParameter]::new($true))
            }
        }

        if ( $GraphItem ) {
            $objectUriInfo = Get-GraphUriInfo -GraphItem $GraphItem
            $targetType = $objectUriInfo.__ItemMetadata().TypeId
        }

        $methods = Get-GraphMember @forwardedParameters

        if ( $isMethodUri ) {
            $targetType = $methods.DefiningTypeId
        }

        foreach ( $method in $methods ) {
            if ( ! $Parameters.IsPresent ) {
                new-so MethodDisplayType $method $targetType
            } else {
                $::.MethodDisplayType |=> ToPublicParameterList $method
            }
        }
    }

    end {
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphMethod TypeName (new-so TypeParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphMethod GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphMethod Uri (new-so GraphUriParameterCompleter LocationOrMethodUri)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphMethod Name (new-so MemberParameterCompleter TypeName $null Method)
