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
A graph object describes how commands in this module should interact with a specific Graph API version. The Get-Graph command retrieves graph objects and emits them as output.

For more details on graph objects, including how they can be created and ways in which they are used, see the documentation for the New-Graph command.

.PARAMETER Name
Every graph has a unique name -- specify the name of the graph through the Name parameter. If a graph with that name exists, it will be returned, otherwise there is no output.

.OUTPUTS
A graph object encapsulating the API schema, REST request preferences, service endpoints, and authentication / authorization behaviors for accessing a specific Graph API version. If the Name parameter is specified and no graph exists with that name, then there is no output.

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
