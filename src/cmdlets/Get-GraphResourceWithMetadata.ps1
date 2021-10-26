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

. (import-script ../metadata/GraphManager)
. (import-script Get-GraphUriInfo)
. (import-script ../common/GraphAccessDeniedException)
. (import-script common/TypeUriParameterCompleter)


<#
.SYNOPSIS
Gets API metadata and the resource from the Graph service endpoint for a given URI.

.DESCRIPTION
The Get-GraphResourceWithMetadata command issues a request to the Graph API service endpoint given a URI as input, and also returns metadata about the URI such as the Graph entity type. The data returned by this command for any Graph API service endpoint requests is the same as the data returned by the related Get-GraphResource command. Get-GraphResourceWithMetadata supports almost all of the same filtering, projection, and request modification capabilities present in Get-GraphResource. See the documentation for Get-GraphResource to learn more about querying the Graph API.

The URI parameter is interpreted relative to the current Graph location. The output in the case where a URI is specified is similar to the output of Get-GraphResource, except that the inclusion of extra metadata enables additional user experiences such as custom formatted output. If no URI is specified and the current location URI resolves to a Graph resource (i.e. OData entity), then no request is issued to the service endpoint. Instead, metadata about each relationship (i.e. OData navigation property) of the entity for the given URI is is returned by the command.

The command also supports parameters that allow the inclusion of not additional metadata beyond relationships such as methods (e.g. OData actions and functions).

Because the Graph API URI model requires any URI that resolves to a navigation property allows for the construction of a new URI that is the concatenation of the original URI followed by a URI segment corresponding to an entity identifier value or another relationship, Graph URIs can be arranged as a hierarchy in very much the same way that file system paths constitute a hierarchy. Relationships may be interpreted as "containers" of entities then in the same way that file system directories "contain" files. This means that Set-GraphLocation can be used to change the current Graph location to a relationship as if it were a container, in much the same way that the Set-Location command which is aliased as the familiar "cd" command changes the current file system directory of a command shell.

One difference between the graph URI hierarchy and the traditional file system hierarchy is that in the file system files are usually not treated as containers with their own child items or that can be treated as the current location, but for the Graph experience with this module's commands, this limitation does not hold. The module allows entity URIs to be set to the current Graph location even thoufh files in a file system typically cannot be the current location. And Graph entities can be treated as having enumerable children, their relationships and methods, essentially any component that can result in an additional valid URI segment preceded by the entity's URI -- entities do not have to be the last element of a URI. File system paths to files however always end with the file name as the last node.

Thus the experience of using Get-GraphResourceWithMetadata and Set-GraphLocation to "traverse" the Graph URI space is similar to the ubiquitous practice of using the ls (or dir) and cd commands to traverse / explore a file system from a command shell. For this reason, Get-GraphResourceWithMetadata is aliased as gls ("graph ls") and Set-GraphLocation is aliased as "gcd". And since the related Get-GraphResource command does not consistently model hierarchies, it is more like the "cat" utility used to read files, so it is aliased as "gcat."

.PARAMETER Uri
The Uri parameter is the URI valid in the current Graph or Graph specified by the GraphName parameter for the graph resource on which to invoke the GET method. If the Uri starts with '/', it is interpreted as an absolute path in the graph. If it does not, then it is relative to the current Graph location, which by default is '/'. If the value of the URI is '.' or is not specified it's default value is interpreted as the current Graph location. For example, if the goal was to issue a GET on the resource URI https://graph.microsoft.com/v1.0/users/user1@mydomain.org, assuming that the current Graph endpoint was http://graph.microsoft.com and the API version was 'v1.0', this parameter would be specified as 'users/user1@mydomain.org'. If the AbsoluteUri parameter is specified, the Uri parameter must be an absolute Uri (see the AbsoluteUri documentation below).

.PARAMETER Filter
Specifies an optional OData query filter to reduce the number of results returned to those satisfying the query's criteria. Visit https://www.odata.org/ for details on the OData query syntax.

.PARAMETER PropertyFilter
A hash table that specifies a filter by defining an arbitrary number of conjoined equality clauses. Each entry in the hash table is an equality expression, with the key of the hash entry specifying the name of a property on the left hand side of the equality and the hash entry's value corresponding to the equality constraint's right hand side. The full filter expression then is all of the equality expressions from the hash table joined together with the 'and' operator. This allows filtering where multiple equality criteria must be satisifed.

.PARAMETER GraphItem
An object returned by Get-GraphResourceWithMetadata or any command that outputs a deserialized object returned from a Graph API response. When GraphItem is specified, instead of the URI parameter being used to issue a request to the Graph API for the given command, the request is URI is based on the URI that created the object represented by GraphItem.

.PARAMETER Select
Specifies as an array the set of properties of the resource objects that the response to the request contain -- this is exactly the set of properties that will be returned as output of the command for each resource. When this parameter is not specified (default), the set of properties to return is determined by Graph. To ensure that a specific property is always returned, specify it (along with other desired properties) through the Select parameter. To select all properties, including those that are not returned by default, use the value '*'. Another use of Select is to limit the amount of data returned by the Graph to reduce network traffic; a request that by default returns 15 properties for each object in in a response when only two of those properties are needed could be specified with just those two properties. The resulting response would be far smaller, a savings particularly important if large result sets are returned.

.PARAMETER SimpleMatch
Specifies a search string that will be matched as a substring of the values of common properties of response data such as the 'displayName' or 'name' properties. The search should be considered inexact and "fuzzy" and subject to change; it's an easy way to perform casual searches without exactly knowing the structure of the objects.

.PARAMETER Search
The Search parameter allows specification of a content search string, i.e. a string to search a collection of written human language artifacts such as e-mail messages, documents, presentations, etc. By specifying the Search parameter, a request to the approprpiate could be issued to retrieve just documents or e-mail messages that contain a certain word or set of words for instance. Not all Graph URIs will support this parameter, and a particular resource may used a fix sort order and in general limit query-related parameters of the request when Search is used. See the documentation for the particular Graph resource to understand the behavior for queries with Search.

.PARAMETER Expand
The Expand parameter transforms results in a response from identifiers to the full content of the identified objects. If the goal is to retrieve the full content of the objects, the Expand parameter in this case reduces the number of rount trip calls to the Graph API -- all the objects are returned in a single call, rather than at least two calls, the first of which retrieves the identifiers, and the second of which queries for the content of the objects with those identifiers.

.PARAMETER OrderBy
The OrderBy parameter, which is also aliased as 'Sort', indicates that the results returned by the Graph API should be sorted using the key specified as the parameter value. If the Descending parameter is not specified when OrderBy is specified, the values should be sorted in ascending order.

.PARAMETER First
The First parameter specifies that Graph should only return a specific number of results in the HTTP response. If a request would normally result in 500 items, only the number specified by this parameter would be returned, i.e. the first N results according to the sort order that Graph defaults to or that is specified by this command through the OrderBy parameter. This parameter can be used in conjunction with the Skip parameter to page through results -- First is essentially the page size. By default, Get-GraphResource returns only the first 10 results.

.PARAMETER Skip
Skip specifies that Graph should not return the first N results in the HTTP response, i.e. that it should "discard" them. Graph determines the results to throw away after sorting them according to the order Graph defaults to or is specified by this command through the OrderBy parameter. This parameter can be used in conjunction with this First parameter to page through results -- if 20 results were already returned by one or more previous invocations of this command, then by specifying 20 for Skip in the next invocation, Graph will skip past the previously returned results and return the next "page" of results with a page size specified by First.

.PARAMETER Query
The Query parameter specifies the URI query parameter of the REST request made by the command to Graph. Because the URI's query parameter is affected by the Select, Filter, OrderBy, Search, and Expand options, the command's Query parameter may not be specified of any those parameters are specified. This parameter is most useful for advanced scenarios where the other command parameters are unable to express valid Graph protocol use of the URI query parameter.

.PARAMETER Count
The Count parameter specifies that the count of objects that would be returned by the given request URI should be returned as the output of the command rather than the objects themselves. Note that this will only be successful if the functionality to return a count is supported by the given given URI.

.PARAMETER Headers
Specifies optional HTTP headers to include in the request to Graph, which some parts of the Graph API may support. The headers must be specified as a HashTable, where each key in the hash table is the name of the header, and the value for that key is the value of the header.

.PARAMETER ClientRequestId
Specifies the client request in the form of a GUID id that should be passed in the 'client-request-id' request header to the Graph API. This can be used to correlate verbose output regarding the request made by this command with request logs accessible to the operator of the Graph API service. Such correlation speeds up diagnosis of errors in service support scenarios. By default, this command automatically generates a request id and sends it in the header and also logs it in the command's verbose output, so this parameter does not need to be specified unless there is a particular reason to customize the id, such as using an id generated from another tool or API as a prerequisite for issuing this command that makes it easy to correlate the request from this command with that tool output for troubleshooting and log analysis. It is possible to prevent the generation of a client request id altogether by specifying the NoClientRequestId parameter.

.PARAMETER AbsoluteUri
By default the URIs specified by the Uri parameter are relative to the current Graph endpoint and API version (or the version specified by the Version parameter). If the AbsoluteUri parameter is specified, such URIs must be given as absolute URIs starting with the schema, e.g. instead of a URI such as 'me/messages', the Uri or TargetItem parameters must be https://graph.microsoft.com/v1.0/me/messages when the current Graph endpoint is graph.microsoft.com and the version is v1.0.

.PARAMETER RawContent
This parameter specifies that the command should return results exactly in the format of the HTTP response from the Graph endpoint, rather than the default behavior where the objects are deserialized into PowerShell objects. Graph returns objects as JSON except in cases where content types such as media are being requested, so use of this parameter will generally cause the command to return JSON output.

.PARAMETER ConsistencyLevel
This parameter specifies that Graph should process the request using a specific consistency level of 'Auto', 'Default', 'Session' or 'Eventual'. Requests processed with 'Session" consistency, originally the only supported consistency level for Graph API requests, these requests will make a best effort to ensure that the response reflects any changes made by previous Graph API requests made by the current caller. This allows applications to perform Graph API change operations such as creating a new resource such as a user or group followed by a request to retrieve information about that group or other information (e.g. the count of all users or groups) that would be influenced by the success of the earlier change. All operations are therefore consistent within the boundary of the "session." The disadvantage of session semantics is that the cost of supporting advanced queries such as counts or searches is very costly for the Graph API services that process the request, and so many advanced queries are not supported with session semantics. For this reason, a subset of services including those providing Azure Active Directory objects like user and group subsequently added the eventual consistency level. With eventual semantics, the API services that support this consistency level may temporarily violate session consistency with the benefit that advanced queries too costly to process with session semantics are now available. The results of those queries may not be fully up to date with the latest changes, but after some (typically short, a few minutes or less than an hour) time period a given set of changes will be reflected in the results for the same query repeated at a later time. The results of the API are not immediately consistent with changes in the session, but will be "eventually." For a given use case, a particular consistency level that prioritizes short-term accuracy higher or lower than complex query capability may be more appropriate; this parameter allows the caller of this command to make that choice. Specifying 'Default' for this parameter means the consistency level is determined by the API itself and API documentation should be consulted to determine if the API even supports a particular consistency level and therefore whether it is necessary to use this parameter. Note that if this parameter has the default value of 'Auto', the behavior is determined by the configuration of the Graph connection used for this request.

.PARAMETER NoClientRequestId
This parameter suppresses the automatic generation and submission of the 'client-request-id' header in the request used for troubleshooting with service-side request logs. This parameter is included only to enable complete control over the protocol as there would be very few use cases for not sending the request id.

.PARAMETER NoSizeWarning
Specify NoSizeWarning to suppress the warning emitted by the command if 1000 or more items are retrieved by the command and no paging parameters, i.e. First or Skip parameters, were specified. The warning is intended to communicate that returning such a large result set may not have been intended. Use this parameter to ensure that automated scripts do not output the warning when intentionally used on large result sets to return all results.

.PARAMETER All
Specify the All parameter to retrieve all results. By default, requests to the Graph will return a limited number of results; this number varies by API. This parameter makes it easy to override that behavior and retrieve all possible results in a set with a single command as opposed to querying for the result size and then paging through results (and implementing error handling logic). The downside is that in the case of a large result set the command could be unresponsive for several minutes or even longer.

.PARAMETER IncludeAll
Specifies that when enumerating child segments that are not Graph API responses that all possible segments, not just relationships, should be returned. In practice this means returning methods in addition to relationships.

.PARAMETER Recurse
Specifies that data for child segments must be returned. By default, Get-GraphResourceWithMetadata does not return child segment data if the Uri parameter corresponds to an entity. When this parameter is specified, children are returned in all cases in addition to response data for the Uri if it resolves to an entity.

.PARAMETER ChildrenOnly
Specifies that only data for child segments of the Uri parameter should be returned; no data for the Uri parameter itself should be returned.

.PARAMETER DetailedChildren
Specifies that when the Graph API returns a response for a collection of objects, metadata for the relationships and methods for each item in the collection must be returned in addition to metadata about the collection itself.

.PARAMETER ContentOnly
Specifies that when a response is received from the Graph API, the objects in it should not be decorated with metadata. By default, such responses are augmented with metadata.

.PARAMETER DataOnly
Specifies that segment that only contain metadata should not be emitted -- only segments that are entities from a response from Graph should be emitted in this case.

.PARAMETER NoRequireMetadata
Specifies that the command should not wait for API metadata to be available before issuing Graph requests. This may result in output not having metadata.

.PARAMETER StrictOutput
Specify StrictOutput to override the default behavior of returning segments that contain only metadata only when no parameter is passed to the command to enumerate the current directory and it is an entity. With StrictOutput, both data and metadata are emitted for every value of the Uri parameter where the Uri resolves to an entity.

.PARAMETER GraphName
Specifies the unique name of the graph on which the command should operate. This controls both the connection (e.g. identity and service endpoint) used to access the Graph API and also the API version used to interpret the Uri and TypeName parameters. When this parameter is unspecified, the current graph is used as a default.

.OUTPUTS
If the command issued a request for the specified URI, it returns the content of the HTTP response along with metadata about the URI. If no request was issued because the command was only enumerating relationships and other URI segments, then only the metadata about enumerated segments is returned.

.EXAMPLE
gls /me

   Graph Location: /users

Id                                   DisplayName   Job Title UserPrincipalName
--                                   ------------  --------- -----------------
c35d71f9-7577-4edb-9151-05258e8b47fb Pauli Murray  Activist  pauli@justicetime.org

In this example, Get-GraphResourceWithMetadata is invoked with its more usable alias gls against the Graph API URI path /me. This makes the same Graph API request as Get-GraphResource /me and actually returns the exact same response, but in this case the Get-GraphResourceWithMetadata command has decorated the response object with extra metadata that includes its Graph API resource type, which in this case is 'user'. The object is emitted as a PowerShell custom object with a type name corresponding to 'user' in the PSTypeNames property. Since the module also includes custom PowerShell formatting for this popuular Graph resource type, the output of the object emitted to the console is tabular and by default, outputs the most "useful" properties of the object, and uses colored output. Contrast this output format with that of Get-GraphResource, which always uses list output formatting and does not support color.

It should be emphasized that all of the properties from the response are still available, it's only the output formatting that has changed. To switch to a view that shows all of the object's properties, pipe the output to Format-List as you would with any PowerShell command.

.EXAMPLE
gcd /users
gls

   Graph Location: /users

Id                                   DisplayName         Job Title  UserPrincipalName
--                                   ------------        ---------  -----------------
c35d71f9-7577-4edb-9151-05258e8b47fb Pauli Murray        Activist   pauli@justicetime.org
8618a75d-a209-44f3-b2f8-2423cb211eed Treemonisha Jackson Director   treejack@newnoir.org
83dd3dbb-d7f3-44d3-a4a1-b92971ba7379 Sir Nose                       devoidof@funk.org
30285b8b-70ba-42e0-9bd9-fbcee5d1ce64 PFunk 4Life         Verbalizer pfunk@funk.org

In this example, the gcd alias for the Set-GraphLocation command is invoked to change the current location to the Graph API URI path /users. Then Get-GraphResourceWithMetadata is executed with the gls alias, issuing a Graph API request of https://graph.microsoft.com/v1.0/users. In essence, we've "cd'd" to the "/users" directory of Graph, and now we're "ls-ing" the users in that directory. The resulting list of users looks very much like a directory listing from the file system "ls" or "dir" commands.

.EXAMPLE
gcd /me
gls

   Graph Location: /me

Info Type                Preview Id
---- ----                ------- --
n* > userActivity                activities
n* > agreementAcceptance         agreementAcceptances
n* > appRoleAssignment           appRoleAssignments
n  > authentication              authentication
n  > calendar                    calendar
n  > contact                     contacts
n  > directoryObject             directoryObjects
n  > directoryObject             manager
n  > messages                    messages
n  > profilePHoto                photo
...

What happens when you "gcd" into an entity and invoke gls? The result is the "relationships" aka the OData navigation properties of the resource (OData entity), in this case a user resource corresponding to 'me'. These relationships are interesting ecause Graph treats them as additional segments for building URI's, i.e. you can add the relationship "messages" to the current graph location URI '/me' to issue a request for '/me/messages' and this is a valid request to the Graph API, in this case one that retrieves the list of email and other messages for the current user 'me'. If these relationships can be treated as additional URI segments and gls treats each segment like a file system "directory," that suggests we can also "gcd" into one of the relationships emitted by gls /me. This is indeed the case, and is the basis of a paradigm for "navigating" the Graph API using gls and gcd, as well as Get-GraphResource which is aliased as "gcat" to move around the graph (with gcd) while looking at content (via gcat) and API structure (gls).

The output formatting used here is a default formatting, so here the "id" column refers not to the identifier of a Graph resource, but denotes the name of the relationship. The "type" of the relationship is the Graph resource type that defines the properties of data referenced by that relationship. There is no "Preview" since the Preview column is a heuristic applied to data from Graph, and this output was not the result of a Graph request, just output describing the relationship schema of the API. The "Info" field is interesting -- it is fashioned after the "Mode" column of "Get-GraphChildItem" in PowerShell and the first column of "ls -al" POSIX standard commands. The characters of the Info field can be interpreted as follows:

1. The first character can be n,e, or s. The n is for OData navigation property, generally referred to in Graph API documentation as a "relationship". The t is for OData "entity," i.e. a "resource" in the Graph API documentation; this value is present whenever the object corresponds to a Graph resource returned from a response -- resources always surface a unique identifier for that resource Type. The e is for OData "entity set", which refers to "tables" of entities of a given type -- the Graph URI /users resolves to an entity set. The s is for singleton, which is an OData concept that can refer to a specific entity or may simply provide a "grouping" concept for related APIs. Both entity sets and singletons may only appear as the first segment of a Graph API path.
2. The second column will be empty unless the entry represents a relationship that is also a collection, which case it will have a '*'.
3. The third column will be empty unless the item contains response content from Graph, in which case it will have a "+".
4. The fourth column will be empty unless it can be considered to have children -- this is generally always true, so this use of the column may be deprecated.

For more information about types, see the Get-GraphType, Find-GraphType, and Show-GraphHelp commands.

.EXAMPLE
gcd /me/messages
gls

   Graph Location: /v1.0:/me/messages

Received             From                          Subject                                  To Recipients
--------             ----                          -------                                  -------------
2021-10-23 06:15 Sat Solidarity For All            Ready for the big March?                 Solidarity Detroit
2021-10-20 09:07 Wed DeWanda Smith                 RE: Concurrency in fractal boundary calc Davis Jones
2021-10-20 15:23 Sat Quentin Powers                Looking forward to the party!            Davis Jones + 3
2021-10-18 09:09 Sat Cooperative Delivery Services Your package ETA 2021-10-21 11:00 AM     Davis Jones

In this example, the user "gcd's" to the /me/messages API path. The gls alias is invoked with no argument, so the current path /me/messages is used as the Graph API request URI. The gls command uses API metadata to determine that the responses corresond to mail messages, decorates the resulting objects accordingly, and then PowerShell's output formatter displays them with a convenient "inbox-like" display.

.EXAMPLE
gcd /
gls

   Graph Location: /

Info Type            Preview Id
---- ----            ------- --
s  > admin                   admin
s  > auditLogRoot            auditLogs
e* > device                  devices
e* > directoryObject         directoryObjects
e* > drive                   drives
s  > user                    me
e* > team                    teams
e* > user                    users
...

In this example, the user "gcd's" to the "root" of the Graph API by specifying "/" as the argument to gcd. Then gls is used with no parameter to enumerate the current location. The current location does not correspond to a valid Graph API URI so no request is issued, and it also does not correspond to an entity, so no relationships are retrieved. But in terms of navigating the Graph API URI segments as a hierarchy, the command returns the next possible segments in the Graph, which are the singletons an entity sets of the API. The output in this example is truncated and filtered for brevity, but includes commonly used Graph API segments such as me, users, and directoryObjects, all of which constitute valid Graph API request URIs. Using 'gcd /' with gls is an easy way to "explore" possible URIs and remind yourself of what's available in the API and how to get to it without having to consult documentation.

.EXAMPLE
gls /me/drive/root/children -SimpleMatch powershell

   Graph Location: /v1.0_1:/me/drive/root/children

CreatedBy           LastModifiedDateTime    Size Name
---------           --------------------    ---- ----
kaleah@lightdev.org 2020-01-08 17:48     7375082 PowerShell
kaleah@lightdev.org 2020-10-27 08:22      926070 PowerShellAutomationGuide.pptx
psyops@lightdev.org 2021-05-13 08:08      887497 PoerShellTips.pptx
smithlightdev.org   2019-10-17 15:01       59357 PowerShell.md

In this example, the SimpleMatch parameter is used to find documents via the /me/drive/root/children API URI that start with the word "PowerShell" or have other common properties starting with that string. The Uri parameter corresponds to the Graph apI URI for the user's personal drive. The module has formatting support for resulting driveItem resource objects, so the console output for these files is similar to that of a directory listing for files on a local system using your favorite shell utilities.

.EXAMPLE
gls /me/messages -PropertyFilter @{importance='High';subject='Test Notification';isRead=$false} -Property id |
    Set-GraphItem -Property isRead -Value $true

In this example, a user invokes gls to find unread messages matching a certain criteria and pipes the result to the Set-GraphItem to mark the messages as read. The PropertyFilter parameter of gls is used to specify a search filter for the results of the /me/messages Graph API URI that returns the signed-in users's messages (email, chat, and other messages). The filter is a hash table where the keys are properties of each message result object on which to filter. The values of the hash tables are the values that the corresponding key must satisfy to include the message in the result. Thus the PropertyFilter specified here is interpreted as "messages with isRead set to false and importance 'high' AND a subject of 'Test Notification'". This is equivalent to specifying the Filter property directly using the OData syntax "isRead eq false and importance eq 'High' and subject eq 'Test Notification'".

The result is then piped to the Set-GraphItem command which modifies Graph resources (entities). In this case, the isRead Property is set to $true, which marks the message as read.

Note that in the original gls invocation the Property parameter is specified with the value 'id' -- this limits the response returned by the Graph API to only include the id property of each returned message since when Property is utilies all properties to include in the response must be explicity specified. For an object like message which includes user content, this is useful as it significantly reduces network traffic between the system running the command and the Graph API, returning only the absolutely necessary data, the message id, required to accomplish the task of marking messages as read. It also avoid retrieving sensitive data such as customer content and avoids the need to verify its safe handling.

.LINK
Get-GraphResource
Set-GraphLocation
Get-GraphLocation
Get-GraphType
Get-GraphItem
Get-GraphChildItem
Set-GraphItem
New-GraphItem
#>
function Get-GraphResourceWithMetadata {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true, supportsshouldprocess=$true, defaultparametersetname='byuri')]
    param(
        [parameter(position=0, parametersetname='byuri', valuefrompipeline=$true)]
        [Uri] $Uri = $null,

        [parameter(position=1)]
        [Alias('Property')]
        [String[]] $Select = $null,

        [parameter(position=2)]
        [String] $SimpleMatch = $null,

        [String] $Filter = $null,

        [HashTable] $PropertyFilter = $null,

        [parameter(parametersetname='GraphItem', valuefrompipeline=$true, mandatory=$true)]
        [PSCustomObject] $GraphItem = $null,

        [parameter(parametersetname='GraphUri', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Uri] $GraphUri,

        [String] $Query = $null,

        [String] $Search = $null,

        [String[]] $Expand = $null,

        [Alias('Sort')]
        [object[]] $OrderBy = $null,

        [Switch] $Descending,

        [switch] $Count,

        [switch] $RawContent,

        [ValidateSet('Auto', 'Default', 'Session', 'Eventual')]
        [string] $ConsistencyLevel = 'Auto',

        [switch] $All,

        [switch] $AbsoluteUri,

        [switch] $IncludeAll,

        [switch] $Recurse,

        [switch] $ChildrenOnly,

        [switch] $DetailedChildren,

        [switch] $ContentOnly,

        [switch] $DataOnly,

        [Switch] $NoRequireMetadata,

        [Switch] $StrictOutput,

        [HashTable] $Headers = $null,

        [Guid] $ClientRequestId,

        [switch] $NoClientRequestId,

        [switch] $NoSizeWarning,

        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='GraphItem')]
        [parameter(parametersetname='GraphUri', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [string] $GraphName = $null
    )

    begin {
        Enable-ScriptClassVerbosePreference

        $filters = if ( $SimpleMatch ) { 1 } else { 0 }
        $filters += if ( $Filter ) { 1 } else { 0 }
        $filters += if ( $PropertyFilter ) { 1 } else { 0 }

        if ( $filters -gt 1 ) {
            throw "Only one of SimpleMatch, Filter, or PropertyFilter parameters may be specified -- specify no more than one of these paramters and retry the command."
        }

        $targetFilter = $::.QueryTranslationHelper |=> ToFilterParameter $PropertyFilter $Filter

        $context = $null

        $mustWaitForMissingMetadata = (__Preference__MustWaitForMetadata) -and ! $NoRequireMetadata.IsPresent
        $responseContentOnly = $RawContent.IsPresent -or $ContentOnly.IsPresent -or $Count.IsPresent

        $results = @()
        $intermediateResults = @()
        $contexts = @()
        $requestInfoCache = @()
    }

    process {
        $assumeRoot = $false

        $specifiedUri = if ( $uri ) {
            $Uri
        } else {
            $GraphUri
        }

        $resolvedUri = if ( $specifiedUri -and $specifiedUri -ne '.' -or $GraphItem ) {
            $GraphArgument = @{}

            if ( $GraphName ) {
                $graphContext = $::.logicalgraphmanager.Get().contexts[$GraphName]
                if ( ! $graphContext ) {
                    throw "The specified graph '$GraphName' does not exist"
                }
                $context = $graphContext.context
                $GraphArgument['GraphName'] = $GraphName
            }

            if ( $GraphItem -and ( $::.SegmentHelper |=> IsGraphSegmentType $GraphItem ) ) {
                $GraphItem
            } else {
                $targetUri = if ( $GraphItem ) {
                    if ( ! ( $GraphItem | gm id -erroraction ignore ) ) {
                        throw "The GraphItem parameter does not contain the required id property for an item returned by the Graph API or the wrong type was specified to the pipeline -- try specifing the parameter using the parameter name instead of the pipeline, or ensure the type specified to the pipeline is of type [Uri] or a valid object returned by the Graph from a command invocation."
                    }
                    $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $null $false $null $GraphItem.id $GraphItem
                    if ( ! $requestInfo.Uri ) {
                        throw "Unable to determine Uri for specified GraphItem parameter -- specify the TypeName or Uri parameter and retry the command"
                    }
                    $requestInfo.Uri
                } else {
                    if ( $specifiedUri.IsAbsoluteUri -and ! $AbsoluteUri.IsPresent ) {
                        throw "The absolute URI '$specifiedUri' was specified, but the AbsoluteUri parameter was not specified. Retry the command with the AbsoluteUri parameter or specify a URI without a hostname instead."
                    }
                    $specifiedUri
                }

                $metadataArgument = @{IgnoreMissingMetadata=(new-object System.Management.Automation.SwitchParameter (! $mustWaitForMissingMetadata))}

                Get-GraphUriInfo $targetUri @metadataArgument @GraphArgument -erroraction stop
            }
        } else {
            $context = $::.GraphContext |=> GetCurrent
            $parser = new-so SegmentParser $context $null $true

            $contextReady = ($::.GraphManager |=> GetMetadataStatus $context) -eq [MetadataStatus]::Ready

            if ( ! $contextReady -and ! $mustWaitForMissingMetadata ) {
                $assumeRoot = $true
                $::.SegmentHelper |=> ToPublicSegment $parser $::.GraphSegment.RootSegment
            } else {
                $::.SegmentHelper |=> ToPublicSegment $parser $context.location
            }
        }

        if ( ! $context ) {
            $parsedPath = $::.GraphUtilities |=> ParseLocationUriPath $resolvedUri.Path
            $context = if ( $parsedPath.ContextName ) {
                $graphContext = $::.logicalgraphmanager.Get().contexts[$parsedPath.ContextName]
                if ( $graphContext ) {
                    $graphContext.context
                }
            }
            if ( ! $context ) {
                throw "'$($resolvedUri.Path)' is not a valid graph location uri"
            }
        }

        # The filter for SimpleMatch can only be determined when the type, and thus the
        # context, is known, so it is request specific and must be computed here.
        if ( $SimpleMatch ) {
            $targetFilter = $::.QueryTranslationHelper |=> GetSimpleMatchFilter $context $resolvedUri.FullTypeName $SimpleMatch
        }

        $uriArgument = if ( $resolvedUri -and ( $resolvedUri -isnot [Uri] ) -and ( $resolvedUri.TypeId -ne 'null' ) ) {
            $resolvedUri.GraphUri
        } else {
            $specifiedUri
        }

        $selectArgument = if ( $Select ) {
            if ( $Select -notcontains 'id' -and ! $RawContent.IsPresent -and ! $Count.IsPresent ) {
                'id'
            }
            foreach ( $property in $Select ) {
                $property
            }
        }

        $requestArguments = @{
            # Handle the case of resolvedUri being incomplete because of missing data -- just
            # try to use the original URI
            Uri = $uriArgument
            Query = $Query
            Filter = $targetFilter
            Search = $Search
            Select = $SelectArgument
            Expand = $Expand
            OrderBy = $OrderBy
            Descending = $Descending
            RawContent=$RawContent
            Count=$Count
            Headers=$Headers
            First=$pscmdlet.pagingparameters.first
            Skip=$pscmdlet.pagingparameters.skip
            IncludeTotalCount=$pscmdlet.pagingparameters.includetotalcount
            Connection = $context.connection
            ConsistencyLevel = $ConsistencyLevel
            NoClientRequestId = $NoClientRequestId
            NoSizeWarning = $NoSizeWarning
            All = $All
            # Due to a defect in ScriptClass where verbose output of ScriptClass work only shows
            # for the current module and not the module we are calling into, we explicitly set
            # verbose for a command from outside this module
            Verbose=([System.Management.Automation.SwitchParameter]::new($VerbosePreference -eq 'Continue'))
        }

        if ( $ClientRequestId ) {
            $requestArguments['ClientRequestId'] = $ClientRequestId
        }

        $graphException = $false

        $ignoreMetadata = ! $mustWaitForMissingMetadata -and ( ($resolvedUri.Class -eq 'Null') -or $assumeRoot )

        $noUri = ! $GraphItem -and ( ! $specifiedUri -or $specifiedUri -eq '.' )

        $emitTarget = $null
        $emitChildren = $null
        $emitRoot = $true

        if ( $StrictOutput.IsPresent ) {
            $emitTarget = $::.SegmentHelper.IsValidLocationClass($resolvedUri.Class) -or $ignoreMetadata
            $emitChildren = ! $resolvedUri.Collection -or $Recurse.IsPresent
        } else {
            $emitTarget = ( ( ! $noUri -or $ignoreMetadata ) -and ! $ChildrenOnly.IsPresent ) -or $resolvedUri.Collection
            $emitRoot = ! $noUri -or $ignoreMetadata
            $emitChildren = ( $noUri -or ! $emitTarget -or $Recurse.IsPresent ) -or $ChildrenOnly.IsPresent
        }

        write-verbose "Uri unspecified: $noUri, Emit Root: $emitRoot, Emit target: $emitTarget, EmitChildren: $emitChildren"

        if ( $resolvedUri.Class -eq '__Root' ) {
            if ( $emitRoot ) {
                $results += $resolvedUri
            }
        } elseif ( $emitTarget ) {
            try {
                $graphResult = Invoke-GraphApiRequest @requestArguments
                $intermediateResults += $graphResult
                $requestCacheEntry = @{ResolvedRequestUri=$resolvedUri}
                # We need the context with each result, because in theory each result came from a different
                # Graph since we allow arbitrary URI's and objects to be supplied to the pipeline
                $graphResult | foreach {
                    $contexts += $context
                    $requestInfoCache += $requestCacheEntry
                }
            } catch [GraphAccessDeniedException] {
                # In some cases, we want to allow the user to make a mistake that results in an error from Graph
                # but allows the cmdlet to continue to enumerate child segments known from local metadata. For
                # example, the application may not have the scopes to perform a GET on some URI which means Graph
                # has to return a 4xx, but its still valid to enumerate children since the question of what
                # segments may follow a given segment is not affected by scope. Without this accommodation,
                # exploration of the Graph with this cmdlet would be tricky as you'd need to have every possible
                # scope to avoid hitting blocking errors. It's quite possible that you *can't* get all the scopes
                # anyway (you may need admin approval), but you should still be able to see what's possible, especially
                # since that question is one this cmdlet can answer. :)
                $graphException = $true
                $_.exception | write-verbose
                write-warning $_.exception.message
                $lastError = get-grapherror
                if ($lastError -and ($lastError | get-member ResponseStream -erroraction ignore)) {
                    $lastError.ResponseStream | write-warning
                }
            }
        }

        if ( $ignoreMetadata ) {
            write-warning "Metadata processing for Graph is in progress -- responses from Graph will be returned but no metadata will be added. You can retry this cmdlet later or retry it now with the '-NoRequireMetadata' option unspecified or set to `$false to force a wait until processing is complete in order to obtain the complete response."
        }

        if ( ! $DataOnly.ispresent ) {
            if ( ! $ignoreMetadata -and ( $graphException -or $emitChildren ) ) {
                Get-GraphUriInfo $resolvedUri.GraphUri -children -locatablechildren:(!$IncludeAll.IsPresent) | foreach {
                    $results += $_
                }
            }
        }
    }

    end {
        $contextIndex = 0

        # TODO: Results are a flat list even across multiple requests -- this is really complicated because
        # we need to know the context for each result
        foreach ( $intermediateResult in $intermediateResults ) {
            $currentContext = $contexts[$contextIndex] # The context associated with this result
            $contextIndex++
            if ( 'GraphSegmentDisplayType' -in $intermediateResult.pstypenames ) {
                $results += $intermediateResult
                continue
            }

            $restResult = $intermediateResult

            $isEmptyResult = $restResult -and ( $restResult | gm value -erroraction ignore ) -and ! $restResult.value

            $result = if ( ! $ignoreMetadata -and (! $RawContent.ispresent -and (! $resolvedUri.Collection -or $DetailedChildren.IsPresent) ) ) {
                if ( ! $responseContentOnly ) {
                    $uriMetadata = $restResult | Get-GraphUriInfo -GraphName $context.name
                    $::.SegmentHelper.GetNewObjectWithMetadata($restResult, $uriMetadata.__ItemMetadata())
                } else {
                    $restResult
                }
            } elseif ( ! $isEmptyResult ) {
                if ( ! $responseContentOnly ) {
                    # Getting uri info is expensive, so for a single request, get it only once and cache it
                    $requestSegment = $requestInfoCache[$contextIndex - 1].ResolvedRequestUri
                    if ( ! $requestSegment ) {
                        $requestSegment = Get-GraphUriInfo -GraphName $context.name $specifiedUri
                        $requestInfoCache[$contextIndex].ResolvedRequestUri = $requestSegment
                    }
                    # The request segment information gives information about the uri used to make the request;
                    # much of that is inherited by elements in the response, so it can be shared across
                    # a large number of elements to improve performance
                    $::.SegmentHelper.ToPublicSegmentFromGraphItem($currentContext, $restResult, $requestSegment)
                } else {
                    $restResult
                }
            }

            $noResults = $false

            # TODO: Investigate scenarios where empty collection results sometimes return
            # a non-empty result containing and empty 'value' field in the content
            if ( $resolvedUri.Collection -and ! $RawContent.IsPresent ) {
                if ( $isEmptyResult ) {
                    $noResults = $true
                }
            }

            if ( ! $noResults ) {
                $results += $result
            }
        }

        __AutoConfigurePrompt $context

        $targetResultVariable = $::.ItemResultHelper |=> GetResultVariable
        $targetResultVariable.value = $results

        if ( $results ) {
            $results
        }
    }
}

$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphResourceWithMetadata Uri (new-so GraphUriParameterCompleter LocationUri)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphResourceWithMetadata Select (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphResourceWithMetadata OrderBy (new-so TypeUriParameterCompleter Property)
$::.ParameterCompleter |=> RegisterParameterCompleter Get-GraphResourceWithMetadata Expand (new-so TypeUriParameterCompleter Property $false NavigationProperty)

