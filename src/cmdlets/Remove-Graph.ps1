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

. (import-script common/GraphParameterCompleter)

<#
.SYNOPSIS
Removes a mounted graph so it is no longer accessible.

.DESCRIPTION
A graph object describes how commands in this module should interact with a specific Graph API version. Such objects are "mounted" which makes them available for use with commands. The Remove-Graph command removes mounted graph objects making them unavailable for use with commands.

For more details on graph objects, including how they can be created and ways in which they are used, see the documentation for the New-Graph command.

.PARAMETER Name
Every graph has a unique name -- specify the name of the graph through the Name parameter. If a graph with name specifiec by this parameter exists it will be removed, otherwise the command results in an error.

.OUTPUTS
None.

.EXAMPLE

Remove-Graph beta

In this example, the beta graph is removed.name parameter is specified by position with the value "v1.0". The command returns the object corresponding to the graph with the supplied name.

.EXAMPLE
Get-Graph beta | Remove-Graph

This example is similar to the previous example, but in this case the graph to remove is piped in from the result of a previous invocation to Get-Graph.

.LINK
Get-Graph
New-Graph
#>
function Remove-Graph {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0, valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [string] $Name
    )

    begin {
        Enable-ScriptClassVerbosePreference
    }

    process {
        # Seems that if you accept pipeline input you can't rely on a mandatory parameter being non-null / non-empty
        # This likely preserves the output to accept empty results as inputs without throwing an exception.
        if ( $Name ) {
            $::.LogicalGraphManager |=> Get |=> RemoveContext $Name
        }
    }

    end {
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Remove-Graph Name (new-so GraphParameterCompleter)
