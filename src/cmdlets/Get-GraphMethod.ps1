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
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='forobject')]
    [OutputType('MethodDisplayType')]
    param(
        [parameter(position=0)]
        [Alias('MethodName')]
        [string] $Name,

        [parameter(parametersetname='fortypename', mandatory=$true)]
        $TypeName,

        [parameter(parametersetname='uri', mandatory=$true)]
        [parameter(parametersetname='uripipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Alias('GraphUri')]
        $Uri,

        [parameter(parametersetname='uripipeline', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        $GraphName,

        [parameter(parametersetname='forobject', valuefrompipeline=$true, mandatory=$true)]
        $GraphItem,

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

        $methods = Get-GraphMember @forwardedParameters

        foreach ( $method in $methods ) {
            if ( ! $Parameters.IsPresent ) {
                new-so MethodDisplayType $method
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
