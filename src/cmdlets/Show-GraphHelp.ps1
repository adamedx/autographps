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

function Show-GraphHelp {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0, parametersetname='bytypenamepipe', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Alias('FullTypeName')]
        [Alias('TypeId')]
        [String] $ResourceName = $null,

        [ValidateSet('Default', 'v1.0', 'beta')]
        [String] $Version = 'Default',

        [parameter(parametersetname='byuri', mandatory=$true)]
        [Uri] $Uri,

        [parameter(parametersetname='bygraphobject', valuefrompipeline=$true)]
        [PSTypeName('GraphResponseObject')] $GraphItem,

        $GraphName,

        [switch] $ShowHelpUri,

        [parameter(parametersetname='permissionshelp')]
        [switch] $PermissionsHelp,

        [parameter(parametersetname='overviewhelp')]
        [switch] $OverviewHelp,

        [switch] $PassThru
    )

    begin {
        Enable-ScriptClassVerbosePreference

        $graphNameParameter = @{}

        $targetVersion = if ( $GraphName ) {
            $graphNameParameter = @{GraphName=$GraphName}
            $graphVersion = ($::.LogicalGraphManager |=> Get |=> GetContext $GraphName).version
            if ( ! $graphVersion ) {
                throw "No Graph with the specified name '$GraphName' for the GraphName parameter could be found"
            }
            $graphVersion
        } elseif ( $Version -eq 'Default' ) {
            $currentVersion = ($::.GraphContext |=> GetCurrent).version
            if ( $currentVersion -in 'v1.0', 'beta' ) {
                $currentVersion
            } else {
                write-warning "Unable to locate help for current graph's version '$currentVersion', defaulting to help for 'v1.0'"
                'v1.0'
            }
        } else {
            $Version
        }
    }

    process {
        $targetTypeName = if ( $ResourceName ) {
            $ResourceName
        } elseif ( $Uri -or $GraphItem ) {
            $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $null $false $Uri $null $GraphItem

            $uriInfo = $requestInfo.TypeInfo.UriInfo

            if ( $uriInfo.Class -in 'Action', 'Function' ) {
                $uriInfo = Get-GraphUriInfo $uriInfo.ParentPath @graphNameParameter -erroraction stop
            }

            $uriInfo.FullTypeName
        }

        $uriTemplate = 'https://developer.microsoft.com/en-us/graph/docs/api-reference/{0}/resources/{1}'

        $docUri = if ( $PermissionsHelp.IsPresent ) {
            [Uri] 'https://docs.microsoft.com/en-us/graph/permissions-reference'
        } elseif ( $OverviewHelp.IsPresent ) {
            [Uri] 'https://docs.microsoft.com/en-us/graph'
        } elseif ( $targetTypeName ) {
            $unqualifiedName = $targetTypeName -split '\.' | select -last 1
            $uriTemplate -f $targetVersion, $unqualifiedName
        } else {
            'https://docs.microsoft.com/en-us/graph/overview'
        }

        if ( ! $ShowHelpUri.IsPresent ) {
            write-verbose "Accessing documentation with URI '$docUri'"
            start-process $docUri -passthru:($PassThru.IsPresent)
        } else {
            ([Uri] $docUri).tostring()
        }
    }

    end {
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Show-GraphHelp ResourceName (new-so TypeParameterCompleter Entity, Complex $true)
$::.ParameterCompleter |=> RegisterParameterCompleter Show-GraphHelp GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Show-GraphHelp Uri (new-so GraphUriParameterCompleter LocationOrMethodUri)
