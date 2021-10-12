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
. (import-script common/GraphParameterCompleter)

<#
.SYNOPSIS
Enumerates the list of mounted graphs as objects. A graph object encapsulates the API scheme and connection (including service endpoints) for accessing a Graph API version.

.DESCRIPTION
A graph object describes how commands in this module should interact with a specific Graph API version. Commands that use the graph object in this way will utilize distinct graph objects when accessing different Graph API versions for instance. But even when command invocations access the same API version, the credentials used to access the API or other aspects of the interaction may differ, and so those commands will utilize distinct graph objects that differ in just those ways. The Get-Graph command retrieves all such objects and emits them as output.

When the module is loaded a single graph object is created with properties based on profile settings and the PowerShell session's current location set to the path '<graphname>:/'. The <graphname> token in this case will mirror the initial API version as defined in settings, by default then it would be 'v1.0' for a current location of '/v1.0:/'. If the profile doesn't configure that graph object's API version, it defaults to 'v1.0'. This illustrates that the first component of the module's current location is always the name of a graph.

Additional graphs beyond the initial graph are created in the following ways:
    * Explictly: The New-Graph command can be invoked to create a graph with specific properties such as a user-specified friendly name, API version, alternate schema location, and credentials.
    * Implicitly: Implicit graphs are created in the following circumstances:
        * Whenever the current connection is changed to a new connection that did not previously exist. The graph's name property is generated automatically based on the name of the current graph and an additional string (such as an integer) that makes the graph name unique among any existing graph names. Everything else about the graph is the same as the graph that was the current graph before the connection creation.
        * When the Set-GraphLocation command is invoked with a path that starts with the segment '/<api-version>:'. In this case, the graph's name is also auto-generated based on the existing API version with an additional disambiguating string. The graph's other properties are all the same as that of the graph for the current location prior to the location of Set-GraphLocation.

.PARAMETER Name
Every graph has a unique name -- specify the name of the graph through the Name parameter -- if a graph with that name exists, it will be returned, otherwise there is no output.

.OUTPUTS
A graph object encapsulating the API schema, REST request preferences, service endpoints, and authentication / authorization behaviors for accessing a specific Graph API version.

.EXAMPLE
Get-Graph v1.0

Id                     : 2bef950e-237e-4273-8094-af8526e8dec3
Endpoint               : https://graph.microsoft.com/
Version                : v1.0
CurrentLocation        : /
AuthEndpoint           : https://login.microsoftonline.com/
Metadata               : Ready
CreationTime           : 10/11/2021 6:22:07 PM
LastUpdateTime         : 10/11/2021 6:22:07 PM
LastTypeMetadataSource : https://graph.microsoft.com/v1.0/$metadata

In this example, the name parameter is specified by position with the value "v1.0". The command returns the object corresponding to the graph with the supplied name.

.EXAMPLE
Get-Graph | Select-Object Name

Name
----
beta
beta_fordev
v1.0
v1_forwork

When the command is executed without parameters, it returns all named graphs

.LINK
New-Graph
Remove-Graph
Update-GraphMetadata
#>
function Get-Graph {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(parametersetname='byname', position=0)]
        $Name = $null,

        [parameter(parametersetname='current', mandatory=$true)]
        [Switch] $Current
    )

    Enable-ScriptClassVerbosePreference

    $targetGraph = if ( $Current.IsPresent ) {
        ($::.GraphContext |=> GetCurrent).name
    } else {
        $Name
    }

    $graphContexts = $::.LogicalGraphManager |=> Get |=> GetContext

    $results = $graphContexts |
      where { ! $targetGraph -or $_.name -eq $targetGraph } | foreach {
          $::.ContextHelper |=> ToPublicContext $_
      }

    if ( $targetGraph ) {
        $results | select *
    } else {
        $results
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-Graph Name (new-so GraphParameterCompleter)
