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

. (import-script ../typesystem/TypeManager)
. (import-script common/TypeHelper)
. (import-script common/TypeSearchResultDisplayType)
. (import-script common/TypeParameterCompleter)

enum TypeSearchCriterion {
    Name
    Property
    Relationship
    Method
    Member
}


<#
.SYNOPSIS
Finds types that model a particular Graph API version.

.DESCRIPTION
Use Find-GraphType to obtain detailed information about the data structure of Graph API resources and the relationships between those resources, as well as the allowed operations including method invocations on those resources. The information can help you in understanding what information is exposed by different APIs or the format of data required when constructing Graph API requests or interpreting responses using this module's commands. This is information that may also be obtained by reading documentation, though the Find-GraphType command often provides a faster, more direct route to finding this information as opposed to browsing or searching online documentation.

The command's SearchString parameter allows you to specify a partial or full name of the type to find types related to the search string. The command also provides parameters that control the type of match, including whether a partial or exact match is allowed and whether to match the SearchString parameter on additional information about the type other than its name such as the properties of the type.

By default, the command only returns types (also known as entity types in OData terminology). The TypeClass parameter can be specified to include other kinds of types including complex types and enumeration types. The 'Any' value for the TypeClass parameter means that the search will include all types, not just entity types. For more information on the different types exposed by the Graph API, see the documentation for the Measure-Graph command.

Note that the matched types are returned in order of most relevant to least relevant. A match is considered more relevant when SearchString is matched against the name of the type than when the SearchString is found in other metadata about the type such as its property names. Exact matches of the SearchString rank higher than substring matches.

.PARAMETER SearchString
Specifies the string to look for in the type information. By default, a "contains" match of the search string is performed across the type name field of all entity types. The MatchType parameter can be used to select an exact match, and the Criteria field can be used to add additional fields of the type (e.g. property names) to match against the SearchString parameter in addition to the type name.

.PARAMETER TypeClass
Specifies the kind of type to return. The default is Entity, which is synonymous with the types that the Graph API documentation refers to as "resources" such as 'user', 'group', 'message', etc. Other types including Enumeration, Complex, and Entity. See the documentation for Measure-Graph for additional detail on types. Specify the value 'Any' to return a type of any class.

.PARAMETER GraphName
Specifies the unique name of the graph on which the command should operate. This controls both the connection (e.g. identity and service endpoint) used to access the Graph API and also the API version used to interpret the Uri and TypeName parameters. When this parameter is unspecified, the current graph is used as a default.

.PARAMETER Criteria
An array of TypeSearchCriterion values specifying the criteria to use to match types. The use of an array allows multiple criteria to be specified. If any one of the criteria are satisfied as a match, then the type will certainly be returned. If multiple criteria match, this increases the relevance score of the type. Criteria include matching by Name (the default), Property name, Relationship name, or Method name. Specifying Member means any member name (Property, Relationship, or Method name) can satisfy a match.

.PARAMETER MatchType
Specifies how to match the SearchString against each criterion specified by Criteria. By default, MatchType is 'Contains" which means any criterion that contains SearchString as a substring will be considered a match. If the value is StartsWith, then the criterion must start with the value of SearchString. If ExactMatch is specified, then the criterion must match SearchString exactly.

.OUTPUTS
A collection of type match results sorted from most relevant to least relevant. Each result includes the name of the matched type and the reason it was matched, as well as its relevance score.

.EXAMPLE
Find-GraphType outlook

TypeClass TypeId                          Criteria MatchedTerms
--------- ------                          -------- ------------
Entity    microsoft.graph.outlookuser     {Name}   microsoft.graph.outlookuser
Entity    microsoft.graph.outlookitem     {Name}   microsoft.graph.outlookitem
Entity    microsoft.graph.outlookcategory {Name}   microsoft.graph.outlookcategory

This example finds entity types (resources) with "outlook" in the name of the resource. The output includes the criteria used for the match and the value of matched criterion.

.EXAMPLE
Find-GraphType ipv6 -typeclass any

TypeClass TypeId                        Criteria MatchedTerms
--------- ------                        -------- ------------
Complex   microsoft.graph.ipv6cidrrange {Name}   microsoft.graph.ipv6cidrrange
Complex   microsoft.graph.ipv6range     {Name}   microsoft.graph.ipv6range

In this class, a search is performed across all types to find a type that has 'ipv6' in the name. The only results in this case are complex types.

Find-GraphType ipaddress -Criteria Name, Member

TypeClass TypeId                                        Criteria   MatchedTerms
--------- ------                                        --------   ------------
Entity    microsoft.graph.signin                        {Property} ipAddress
Entity    microsoft.graph.windows10generalconfiguration {Property} webRtcBlockLocalhostIpAddress

In this example, we search for any entity type that has the substring 'ipaddress' in the name or any of its members. The command returns two such entity types (resources) that happen to have the 'ipaddress' search string in property names.

.EXAMPLE
Find-GraphType application -MatchType StartsWith | Show-GraphHelp

This example shows how the output of Find-GraphType may be piped to Show-GraphHelp to launch documentation about the types identified in the search results.

.EXAMPLE
Find-GraphType windows -TypeClass Enumeration -Criteria Property -MatchType Exact

TypeClass   TypeId                                          Criteria   MatchedTerms
---------   ------                                          --------   ------------
Enumeration microsoft.graph.timezonestandard                {Property} windows
Enumeration microsoft.graph.callrecords.clientplatform      {Property} windows
Enumeration microsoft.graph.conditionalaccessdeviceplatform {Property} windows

In this example, we find all of the enumeration types with an enumeration value value that matches the substring 'windows' exactly. Note that for the purposes of Find-GraphType, the use of enumeration values as a criterion requires specifying a Critera element of 'Property'.

.EXAMPLE
Find-GraphType -Criteria Relationship memberOf -MatchType Exact |
    Get-GraphMember -MemberType Relationship |
    Where-Object Name -eq members

This example shows how to find all of the entity types in the Graph API that have a relationship called 'members' and returns details of the relationship that correspond to a source (the type from the search result) and the sink (the type of the relationship itself).

.LINK
Get-GraphType
Show-GraphHelp
Find-GraphPermission
Get-GraphResourceWithMetadata
Get-GraphResource
#>
function Find-GraphType {
    [cmdletbinding(positionalbinding=$false)]
    [OutputType('GraphTypeDisplayType')]
    param(
        [parameter(position=0, mandatory=$true)]
        $SearchString,

        [ValidateSet('Any', 'Primitive', 'Enumeration', 'Complex', 'Entity')]
        $TypeClass = 'Entity',

        $GraphName,

        [TypeSearchCriterion[]] $Criteria = @('Name'),

        [parameter(position=1)]
        [ValidateSet('Exact', 'StartsWith', 'Contains')]
        $MatchType = 'Contains'
    )
    Enable-ScriptClassVerbosePreference

    if ( $TypeClass -contains 'Primitive' ) {
        throw [ArgumentException]::new("The type class 'Primitive' is not supported for this command")
    }

    $targetContext = $::.ContextHelper |=> GetContextByNameOrDefault $GraphName

    # For each typeclass
    #    match the name
    #    match properties
    #    match navigations
    # For each method type
    #    match the name
    #    match the return type -- TODO
    #    match the parameters -- TODO

    $classes = if ( $TypeClass -notcontains 'Any' ) {
        $TypeClass
    } else {
        'Entity', 'Complex', 'Enumeration'
    }

    $typeManager = $::.TypeManager |=> Get $targetContext

    $targetCriteria = [ordered] @{}

    foreach ( $criterion in $Criteria ) {
        if ( $criterion -eq 'Member' ) {
            'Property', 'NavigationProperty', 'Method' | foreach {
                $targetCriteria[$_] = $true
            }
        } elseif ( $criterion -eq 'Relationship' ) {
            $targetCriteria['NavigationProperty'] = $true
        } else {
            $targetCriteria[$criterion] = $true
        }
    }

    $searchResults = $typeManager |=> SearchTypes $SearchString $targetCriteria.Keys $classes $MatchType |
      sort-object Score -descending

    if ( $searchResults ) {
        foreach ( $result in $searchResults ) {
            new-so TypeSearchResultDisplayType $result $targetContext.Name
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Find-GraphType GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Find-GraphType Uri (new-so GraphUriParameterCompleter LocationOrMethodUri)
