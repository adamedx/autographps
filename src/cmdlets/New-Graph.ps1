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

. (import-script common/ContextHelper)


<#
.SYNOPSIS
Creates a new graph object. A graph object encapsulates the API scheme and connection (including service endpoints) for accessing a Graph API version.

.DESCRIPTION
A graph object describes how commands in this module should interact with a specific Graph API version. Commands that use the graph object in this way will utilize distinct graph objects when accessing different Graph API versions for instance. But even when command invocations access the same API version, the credentials used to access the API or other aspects of the interaction may differ, and so those commands will utilize distinct graph objects that differ in just those ways. The New-Graph provides an explicit mechanism for creating graphs.

When the module is loaded a single graph object is created with properties based on profile settings and the PowerShell session's current location set to the path '<graphname>:/'. The <graphname> token in this case will mirror the initial API version as defined in settings, by default then it would be 'v1.0' for a current location of '/v1.0:/'. If the profile doesn't configure that graph object's API version, it defaults to 'v1.0'. This illustrates that the first component of the module's current location is always the name of a graph.

Additional graphs beyond the initial graph are created in the following ways:
    * Explictly: The New-Graph command can be invoked to create a graph with specific properties such as a user-specified friendly name, API version, alternate schema location, and credentials.
    * Implicitly: Implicit graphs are created in the following circumstances:
        * Whenever the current connection is changed to a new connection that did not previously exist. The graph's name property is generated automatically based on the name of the current graph and an additional string (such as an integer) that makes the graph name unique among any existing graph names. Everything else about the graph is the same as the graph that was the current graph before the connection creation.
        * When the Set-GraphLocation command is invoked with a path that starts with the segment '/<api-version>:'. In this case, the graph's name is also auto-generated based on the existing API version with an additional disambiguating string. The graph's other properties are all the same as that of the graph for the current location prior to the location of Set-GraphLocation.

.PARAMETER Version
Specify the Version parameter to set the API version of the graph. If this parameter is not specified, the API version of the created graph is v1.0.

.PARAMETER Name
Every graph must have a unique name -- specify the unique name of the graph through the Name parameter. If no name is specified, a unique name is automatically generated based on properties of the graph such as its API version.

.PARAMETER Connection
Specifies graph connection object to associate with this graph. The connection object contains information about the service endpoints for the Graph API and parameters related to the authentication and authorization for the identity used to access the Graph API. Commands that interact with the Graph API will access the Graph API according to the properties of the graph's associated connection. If the Connection parameter is not specified, the current connection is associated with the Graph.

.OUTPUTS
A graph object encapsulating the API schema, REST request preferences, service endpoints, and authentication / authorization behaviors for accessing a specific Graph API version.

.EXAMPLE
New-Graph beta

   Graph Name: beta

Id                     : 607d4b8a-05bd-4b24-805d-4ff10bf02576
Endpoint               : https://graph.microsoft.com/
Version                : beta
CurrentLocation        : /
AuthEndpoint           : https://login.microsoftonline.com/
Metadata               : Ready
CreationTime           : 10/11/2021 9:07:50 PM
LastUpdateTime         : 10/11/2021 9:07:50 PM
LastTypeMetadataSource : https://graph.microsoft.com/beta/$metadata

This example creates a new graph for the beta API version. Since no name parameter was specified and there was no existing graph with the name "beta," New-Graph uses the API version to name the graph 'beta'.

.EXAMPLE
New-Graph | Select-Object Name, Version, Endpoint

Name   Version Endpoint
----   ------- --------
v1.0_1 v1.0    https://graph.microsoft.com/

If no parameters are specified, then the graph's API version defaults to v1.0, and therefore the unspecified name is set to a variation of that API version. Since there was already a graph named 'v1.0', the unique name 'v1.0_1' is generated from the API version.

.LINK
New-Graph
Remove-Graph
Update-GraphMetadata
#>
function New-Graph {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='Simple')]
    param(
        [parameter(position=0)]
        $Version = 'v1.0',

        [parameter(position=1)]
        $Name = $null,

        [parameter(parametersetname='Connection', mandatory=$true)]
        $Connection = $null
    )

    Enable-ScriptClassVerbosePreference

    $graphConnection = if ( $Connection ) {
        $Connection
    } else {
        ($::.GraphContext |=> GetCurrent).connection
    }

    $context = $::.LogicalGraphManager |=> Get |=> NewContext $null $graphConnection $Version $Name

    $::.GraphManager |=> UpdateGraph $context

    $::.ContextHelper |=> ToPublicContext $context
}
