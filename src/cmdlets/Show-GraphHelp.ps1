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


<#
.SYNOPSIS
Provides Graph documentation for the specified Graph API resource or help topic.

.DESCRIPTION
Show-GraphHelp provides documentation about the Graph either by launching a process to display online documentation for a specified topic or by providing the URI to reach that documentation. The documentation is useful in understanding details of the semantics of different resources, their authorization requirements, request construction, and also in obtaining example scenarios and usage.

Graph API documentation is oriented around the concept of a "resource" such as 'user', 'group', 'application', 'message', etc. that corresponds directly to the OData protocol concept of 'entity' used to model the Graph API. The Graph API consists of thousands of these resources.

Given the name of a resource, you can specify it to Show-GraphHelp to launch the API documentation for that resource in a web browser or other configured viewer.

The command allows the API version to be specified in addition to the topic, and can also take a graph type object returned by Find-GraphType or Get-GraphType as an input since such objects directly represent Graph resource types. And actual instances of resources returned as responses to graph requests issued by the module's commands may also be specified as input; their resource type is determined and then the documentation for that resource type is targeted by the command.

.PARAMETER ResourceName
The type of the resource for which to obtain documentation, e.g. 'user', 'group', 'message', etc.

.PARAMETER Version
The API version of the documentation to obtain. The default value is "Default", which then uses the API version of the current graph. Other valid values are 'v1.0' and 'beta' to obtain documentation for those versions respectively.

.PARAMETER Uri
The graph URI of the resource for which to obtain documentation. The Uri parameter follows the same rules as in other commands -- see the Get-GraphResourceWithMetadata command's documentation for Uri for details.

.PARAMETER GraphItem
An object returned by Get-GraphResourceWithMetadata or Get-GraphResource commands, or any command that outputs a deserialized object returned from a Graph API response. When GraphItem is specified, instead of the ResourceNameparameter being used to identify the resource for which to obtain help, the graph type of the object is used.

.PARAMETER GraphName
Specifies the unique name of the graph on which the command should operate. This controls both the connection (e.g. identity and service endpoint) used to access the Graph API and also the API version used to interpret the Uri and TypeName parameters. When this parameter is unspecified, the current graph is used as a default.

.PARAMETER ShowHelpUri
Specifies that rather than launch the documentation, the command should simply return the URI to the documentation.

.PARAMETER PermissionsHelp
Specifies that instead of obtaining documentation for a specified resource, the command should provide general information on the topic of Graph API permissions and how to specify the permissions required for accessing an API. This is useful for supplying permission parameters to commands such as Connect-GraphApi, New-GraphConnection, New-GraphApplication, and Set-GraphApplicationConsent which include parameters that require the specification of permissions.

.PARAMETER OverviewHelp
Specifies that instead of obtaining documentation for a specified resource, the command should provide general information on the Graph API as a whole. This can be useful for anyone who is new to the Graph API and its uses and requirements or for anyone who needs to browse for specific topic subareas.

.PARAMETER PassThru
When PassThrue is specified, information about the viewer process in which the documentation was launched is provided -- typically this will be a web browser process. This is useful for situations where you may want to control the lifetime of the process or change its user interace properties in some way.

.OUTPUTS
This command only produces output in the following situations:
    * If the ShowHelpUri parameter is specified, then the output is the URI of the documentation as a [string] data type
    * If PassThru is specified, the output is a process object such as that output by Get-Process

.EXAMPLE
Show-GraphHelp user

This launches the documentation for the user resource using the API version of the current graph.

.EXAMPLE
Show-GraphHelp group -Version beta -ShowHelpUri

https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/group

In this example, the Version parameter specifies that help for the 'beta' API version should be obtained, and the ShowHelpUri parameter outputs the URI instead of launching the documentation viewer.

.EXAMPLE
Find-GraphType outlook | Show-GraphHelp -ShowHelpUri

https://developer.microsoft.com/en-us/graph/docs/api-reference/v1.0/resources/outlookuser
https://developer.microsoft.com/en-us/graph/docs/api-reference/v1.0/resources/outlookitem
https://developer.microsoft.com/en-us/graph/docs/api-reference/v1.0/resources/outlookcategory

In this example, the Find-GraphType command is used to look for types that match a given search string, and the results are piped to Show-GraphHelp. Since the ShowHelpUri is specified here, the topics are not launched, only their URIs are output. But if ShowHelpUri is omitted then those three URIs would indeed be opened in the web browser.

.EXAMPLE
Show-GraphHelp -PermissionsHelp

This example shows how to launch the permissions help

.EXAMPLE
Show-GraphHelp -OverviewHelp

This example launches the root of Graph documentation.

.LINK
Find-GraphType
Get-GraphType
Find-GraphPermission
Get-GraphResourceWithMetadata
Get-GraphResource
#>
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
