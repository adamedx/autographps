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
. (import-script ../typesystem/TypeManager)
. (import-script ../typesystem/TypeSearcher)
. (import-script common/GraphStatisticsDisplayType)


<#
.SYNOPSIS
Gets summarized information about the API exposed by a graph.

.DESCRIPTION
Measure-Graph returns summarized information about types exposed by a graph, a concept that encapsulates the API exposed by a specific service endpoint and API version supported by the endpoint. By default commands in this module connect to the service endpoint https://graph.microsoft.com with API version v1.0 unless overridden by other commands or profile settings. Measure-Graph returns information about the current graph unless the name of a different existing graph is supplied to the command.. See the documentation for the New-Graph command for more information about the concept of 'graph' and how it impacts the behavior of commands in this module.

As a summary of the API, the Measure-Graph command is not required for simply accessing the Graph, but is useful for undertanding its scale. Here are some applicable scenarios for Measure-Graph:
    * Examining how the API changes over time and characterizing changes as "small" vs. "large"
    * Undertanding performance issues with commands that consume Graph metadata
    * Validating the structur of custom Graph API schemas if you host test endpoints / schemas for validating your Graph-based tools
    * Simply learning about the mechanics of the Graph API and how to explore / correctly interpret the API metadata

The information returned by this command includes counts for the following elements of the API:
    * OData Entity types, also referred to in Graph API documentation as "resources"
    * Properties across all entity types
    * Relationships across all entity types. Relationships are known as "navigation properties" in OData documentation
    * Entity methods: the number of methods exposed across all types. Methods are known as "actions" and "functions" in OData documentation
    * Complex types: Complex types are an OData conept that models the structure of data that is not addressable as a resource in the Graph, i.e. the data cannot be retrieved via a GET on a URI dedicated to it, only by specifying a URI to a resource that also includes that structure. Also unlike resources / entity types complex types are not required to have an identifier property
    * Properties across all complex types
    * Enumeration types
    * Enumeration values: the total number of values across all enumeration types.

For performance reasons, only a subset of the statistics are obtained by default. To obtain full statistics, specify the Detailed parameter.

For more information on OData concepts used explicitly or implicitly in the Graph API such as entity types, complex types, navigation properties, and enumerations, visit http://www.odata.org.

.PARAMETER GraphName
Specifies the unique name of the graph for which the command should obtain statistics. The graph is bound to a specific API version, so specifying this parameter is sufficient to target the statistics. When this parameter is unspecified, the current graph is used as a default.

.PARAMETER Detailed
For performance reasons, method counts are not obtained by default. To obtain full statistics including the method count, specify the Detailed parameter.


.OUTPUTS
This command produces an object with fields for the count of entity types and count of properties for those types, similar counts for complex types, and the count of enumeration types and total values for those types. For entity types the count of relationships is also returned. If the Detailed parameter is specified, it also includes the count of methods.

.EXAMPLE
Measure-Graph

   Graph Name: v1.0


EntityTypeCount         : 550
EntityPropertyCount     : 3264
EntityRelationshipCount : 662
ComplexTypeCount        : 561
ComplexPropertyCount    : 1930
EnumerationTypeCount    : 355
EnumerationValueCount   : 2746

In this example the statistics are turned for the current graph using the default level of detail.

.EXAMPLE
Measure-Graph beta -Detailed

   Graph Name: beta


EntityTypeCount         : 1384
EntityPropertyCount     : 9493
EntityRelationshipCount : 1535
EntityMethodCount       : 1076
ComplexTypeCount        : 1349
ComplexPropertyCount    : 4487
EnumerationTypeCount    : 928
EnumerationValueCount   : 5887

.LINK
New-Graph
Get-Graph
#>
function Measure-Graph {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(parametersetname='byname', valuefrompipelinebypropertyname=$true, position=0)]
        [Alias('Name')]
        $GraphName = $null,

        [switch] $Detailed
    )

    Enable-ScriptClassVerbosePreference

    $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $GraphName

    if ( ! $targetContext ) {
        throw "The specified graph named '$GraphName' could not be found."
    }

    $typeSearcher = $::.TypeManager |=> Get $targetContext |=> GetTypeSearcher

    $indexClasses = 'Name', 'Property', 'NavigationProperty'

    if ( $Detailed.IsPresent ) {
        $indexClasses += 'Method'
    }

    $typeSearcher |=> GetTypeStatistics $indexClasses | foreach {
        $result = new-so GraphStatisticsDisplayType $_ $targetContext.Name

        if ( ! $Detailed.IsPresent ) {
            $result.EntityMethodCount = $null
        }

        $result
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Measure-Graph GraphName (new-so GraphParameterCompleter)
