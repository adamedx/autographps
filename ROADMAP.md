# ROADMAP for AutoGraphPS

## To-do items -- prioritized

* Implement new Get-GraphItem, Remove-GraphItem commands
* Rationalize Get-GraphChildItem and new Get-GraphItem
* Rename ODataFilter parameter to Filter
* Add methods to Get-GraphType
* Add method invocation via Invoke-GraphMethod
* Fix CI on Linux to actually fail when test failures occur
* Get-GraphType and New-GraphObject should accept both fqn and uqn instead of just uqn for primitive types as for other type classes
* Remove module rename workaround for case issues in CI on Linux
* Possible refactor of ScalarTypeProvider and CompositeTypeProvider into per-typeclass providers
* Fix connect-graph to preserve appid across invocations in some cases
* clean up error stream
* Allow OData cast in URIs for get-graphchilditem, output of ggu
* Preserve identity when mounting graphs
* Fix qualified / vs. unqualified names in metadata classes
* Add `$value` support.
* Move app to new tenant (or create a new one)

* EntityAccess
  * Associate json fragments with graph object state

* Clean up parse methods in GraphUtilities
* Investigate console.writeline background thread
* Coding standards -- SOLID, casing, method call syntax
* document semver in build.md
* Minor doc update
* RELEASE_NOTES

* Release

* Clean up utilities, special-case, duplicate code in get-graphuri, invoke-graphrequest, get-graphitem, get-graphchilditem

* change $graphverbosepreference to $graphverboselevelpreference

* docs on set-graphprompt, new-graph
* docs on new-graphconnection, connect-graph
* docs on update-graphmetadata
* fix -expand issues
* fix parent issues in public segment

* Release

* Samples
* Bugfixes

* Release

* Add welcome command
* Tutorial
* Major doc update

* Release

* User research

* Bugfixes
* Usability changes
* Release

* Test schema and basic tests offline
* Unauthenticated functional tests
* Parse odata context
* Background runspace jobs

* Add CI

* Release

* Add fuzzy select
* Add find-property, find-type

* Local metadata cache

* Get-RequestLog
* Add more complex filter
* Add regex to gls

* Authenticated functional tests
* Refactor invoke-graphrequest to request builder
* Show-GraphRequest
* Fix bug with graph update not clearing uri cache due to async
* Enable schemaless execution
* Auto-refresh token when expired
* Use BEGIN, PROCESS, END in get-graphuri
* Add basic help
* Add uri completion
* Add copy-graphitem
  * graph to graph copy
  * json to graph copy
  * graph to json copy
* Get-GraphTypeData -typename -graphitem
* Get-GraphMetadata
* Add signout
* Simple samples
* Publish first preview / alpha
* Add anonymous connections for use with test-graph item, metadata
* Add new-graphentity -- PUT
* Add set-graphitem -- PUT / PATCH
* Add copy-graphitem
  * graph to graph copy
  * json to graph copy
  * graph to json copy
* add versions to schema, version objects
* consistency in apiversion, schemaversion names
* add predefined scopes: https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference
* common scopes -- use dynamicparam
* scope browser
* Add unit tests for parameters
* Enable token refresh
* Enable app-only auth
* Add reply url to new-graphconnection -- only works with confidential client
* Graph tracing
* Graph trace replay
* entity templates
* invoke-graphappregistry
* security for token
* set-graphconfig
* invoke-graphaction
* generate nuspec
* Find a better name!
* README
* Extended Samples
* More tests
* Add get-graphmetadata
* Help
* graph drive provider
  * Versions
  * Schemas
  * Graph
* create the python version
* Explore graph as an idempotent DSC resource
  * REST resource
  * Graph resource
* Graphlets -- modules built on this that expose specific parts of the graph
* Handle 403's in get-graphchilditem

### Done

* get-graphschema
* model for identity
* get-graphtoken
* get-graphversion
* invoke-graphrequest
* support version in invoke-graphrequest
* support json output
* Re-implement get-graphitem
* add basic scopes
* Support paging through results
* Use content-type of response for deserialization
* add paging interface to graph enumeration commands
* Fix identity function names
* Get custom appid to work
* Session support
* Add connection support to test-graph
* Publish to psgallery
* Update build steps
* Rename stdposh to ScriptClass
* Refactor GraphBuilder
* Genericize GraphContext
* Update-GraphMetadata
* Get-GraphUri -- an offline api, with -parents flag,
* Add --children flag to get-graphuri
* Add full uri support to get-graphitem
* Set-Graphlocation
* Get-GraphLocation
* Add relative path support to invoke-graphrequest
* Support .. in paths
* Move path manipulation to common helpers
* get-graph
* Make context meaningful
  * new-graph
  * Make context meaningful
  * remove-graph
* Add display type for get-graphchilditem
* Aliases:
  * ggi Get-GraphItem
  * gls Get-GraphChildItem
  * gcd Set-GraphLocation
  * gwd Get-GraphLocation
  * ggu Get-GraphUri
  * gg  Get-Graph
* Add 'mode'-like column with compressed information in list view
* Add offline connection
* Change json to raw or nativeoutput or equivalent
* Optimize uri parsing
* limit uri cache size with lru policy
* Add app id, user name to get-graph
* Add prompt modification
* Add query
* Add $select
* Add $expand
* Add ODataFilter
* Make default graph drive just be v1.0
* Make appid substitution nicer
* Make connect-graph connect in the custom case
* Make content-columns auto-avoid collisions
* Rudimentary token auto-refresh
* Make graph drive collision nicer
* Link to scopes docs when unauthorized
* Fix bug where context is assumed to be current rather than from uri
* Make gls, gcd have ability to ignore schema parsing when not ready
* LastGraphRequest
* TOS, Privacy:
  https://developer.microsoft.com/en-us/graph/docs/misc/terms-of-use
* optimize child retrieval
* add back whatif support
* Make it ignore metadata failure by default for gls
* Fix bug in parsing relative uris in get-graphuri
* fix scope args on get-graphschema, get-graphversion
* Rearrange source
* Refactor directories
* Minor source cleanup
* Preview column in get-graphchilditem
* Add auto-prompt and preference
* Fix install-devmodule
* Add build README
* Add -order
* Add -sort parameter alias for orderby
* Add link to build instructions in README
* Fix preferencehelper source file relative path issue
* Add verbosity preference to avoid dumping entire requests
* Minor source rearrangement
* Better error messages when path not found
* CONTRIBUTING.md
* Code of conduct
* Issue template
* Pull request template
* Fix AADGraph bug where reply url seemed to be invalid
* Initial doc update
* Fix Application.ps1 -- class may not have initialized
* Motivation.md
* Update get-graphitem to give gls authorization warnings.
* Fix publishmoduletodev to use module publishing rather than nuget
* Fix token refresh
* Refactor into posh-graph core sdk and poshgraph ux
* Add auto-complete for ggu
* Add auto-complete for gls
* Add auto-mount to set-graphlocation
* Make gcd work without hanging for new graphs
* Get-GraphType
* Change methods for method building, copytosingletons, addedgestotype
* Move dynamic builder methods updatevertex, getentitytypevertex to entitygraph
  * Remove dynamic builder
  * reference datamodel and other members in exactly one place between entitygraph and graphbuilder
  * Make updatevertex GetVertexEdges
  * Make GetEntitytypeVertex GetVertexByType or slightly better name
* Investigate metadata perf optimization -- perform:
  * Discover roots only
  * Just-in-time discovery of types
  * Just-in-time resolution of navigation properties
  * Make metadata download a background job
  * Map actions / functions to entitytypes in background?
  * Process singletons metadata in foreground
  * Use expressions like  ($::.GraphManager.cache.graphversions.values[0].schema[0].edmx.dataservices.schema.action).parameter |where name -eq bindParameter
  * Better: $bindings = ( ($::.GraphManager.cache.graphversions.values[0].schema[0].edmx.dataservices.schema.action)) | foreach { $method = $_.name; $_.parameter | where name -eq bindingParameter | foreach {[PSCustomObject]@{Type=$_.type;Method=$method}}}
* Add app creation, enumeration, update
* Fix verbose output for scriptclass
* Remove get-graphchilditem invalid params
* fix get-childitem logic with containers vs non-containers
* change mode output to reflect containers
* add client request id to get-graphchilditem, getgraphitemwithmetadata
* Add enumeration type support to get-graphtype
* Ability to create Graph JSON

### Postponed

* transform schema, version objects to hashtables
* Delay schema parsing at startup -- this didn't seem to improve startup perf, and the sleep we inserted took effect after the module was available for user input, which itself had a 10s + delay. Optimizing that delay would seem to be in order before putting in a delay to processing.
* Make content column actually add the columns
* Add -filter to get-graphitem
* Add -filter to get-graphschema
* Add hint of additional records
* Add continue feature?
* Test Release
* Get a fix from sdk for scope helper in find-graphpermissions
* Rename propertylist in new-graphitem, new-graphobject to propertymap
* Add-GraphItemReference

### Abandoned

* Get-GraphItem -offline # offline retrieves type data, requires metadata download
* Get-GraphChildItems -offline # offline retrieves type data, requires metadata download
* # So offline allows you to set an offline mode in the drive provider -- providers will have both offline and online, or maybe metadata itself is a drive
* Show content in default list view?
* Change listview content from name to id?
* Make public graph items have id instead of name
* switch to 3 columns by default -- remove class
* Move some data to info, possibly show rwx

#### Stdposh improvements

* Fix deserialization of scriptproperty members
* Performance of method calls through |=> rather than .
* Make default display of objects sane
* Fix initializers, use scriptblock for non-string object types
* Add private methods
* Private fields
* strict-val for pscustomobjects
* remove script-level variables
* inheritance

#### Finished stdposh improvements

* Store methods per class rather than per instance to save space
* Fixed deserialization of scriptmethod members

## Notes on specific problems

### Identity model

In order to authenticate as a user, you need the following:

1. An AppID -- this can just be hard-coded into the app
2. A login endpoint
3. A graph endpoint
4. User credentials
5. A tenant for the user credentials in the case of aad
6.  An authentication method

In order to authenticate as an app, you need the same thing, except

1a. You need a unique app id
4a. Instead of user credentials, you need an app secret


#### Proposed model

The model contains the following entities:

* Connection
  * Endpoint
    * Login endpoint - 2
    * graph endpoint - 3
    * Kind
  * Auth method - 6
  * Identity
    * Tenant - 5
    * App
      * ID - 1, 1a
      * Secret - 4a
      * Kind
    * User name - 4
    * Token - 4, 4a

So, this corresponds to the following non-leaf objects or enums from the list above:

```
class GraphConnection
    class GraphEndpoint
        enum GraphKind
    enum AuthMethod
    GraphIdentity
        GraphApplication
    GraphToken
```


## Stdposh fixes -- completed

These issues have been addressed -- see following section for details.

A key issue now is that each method is duplicated for every instance -- actually twice, since the type data is part of the instance and includes the entire class script.

A related problem is that of serialization. Currently methods and even hidden members are serialized as snapshots.

We might be able to use a type adapter to better solve the latter problem:
    https://blogs.msdn.microsoft.com/besidethepoint/2011/11/22/psobject-and-the-adapted-and-extended-type-systems-ats-and-ets/
    Derive from PSPropertyAdapter

In general though we need to simplify ScriptClass objects. Here are a few notes:

* NoteProperty members are serialized as you would expect, i.e. as JSON representations of themselves (expanded if their state is non-scalar).
  * NoteProperty members of type ScriptBlock are tostring()'d as the full script representation of the ScriptBlock, causing problems objects like ScriptClass (not good)
* ScriptProperty members are serialized as the output of calling the ScriptBlock, so a ScriptProperty with a highly complex function will still be serialized as the string form of "2" if that's what the function returns (good)
* Properties that are not part of the DefaultDisplayPropertySet are serialized anyway -- not good as these include "hidden" properties underlying the type
* ScriptMethod members are a good alternative to ScriptProperty members for read-only members that you want to prevent from being serialized and are ok with being "hidden" from property enumeration via DefaultDisplayPropertySet


The solution to the duplication problem and in some ways the formatting problem is something like the following:

* Make ScriptClass a ScriptMethod and implement set it to a DefaultDisplayProperty. It should return a value from the class table. It should also be hidden. The ScriptClass will look up the ScriptClass to find the actual class in the state table.
* Make all methods just invoke methods from the class table
* Make PSTypeName hidden unless it helps with type adapters

Now we need to add ToHashTable() -- this can be used eliminate the hidden members and then it can be serialized. In theory we can deserialize from it as well via a type adapter.

### How these issues were addressed

* Method duplication: Methods are actually defined in an external table referenced by the class, and there is only one instance of that table

## Entity data model type traversal

Ok, you can grab the entire data model (e.g. type definitions and associations) from the root of the versioned graph service + `$metadata`, i.e. `https://graph.microsoft.com/v1.0/$metadata`. While consuming it can be rather convoluted for my purposes, it appears we can use it to answer the following questions which are key to our use cases:

1. An object was just returned to me -- what is its schematized type definition?
2. If I traverse a navigation property, what type will I get back?

### Getting the type of an entity
So it looks like we can use the `@odata.context` returned in every response. Here's how I think it works:

Let's say you get an `@odata.context` like the following after a `GET` to https://graph.microsoft.com/v1.0/me/drive/root/children. You'll get an `@odata.context` like this:

    @odata.context             : https://graph.microsoft.com/v1.0/$metadata#users('5e3d030a-cb5c-4c5e-afbe-3c4513c2c962')/drive/root/children/$entity

Ok, so the alphanumeric string after `$metadata` is the *entity set* that contains the type, i.e. `users`. Now if you've already retrieved all the metadata (you need to pre-process and cache it -- it's huge), just look up the entity set and get the `entitytype` object -- you'll get `Microsoft.DirectoryServices.User`.

And now you have the type.

### Determining the type of the entities returned by a navigation property

Imagine that you've retrieved an entity and you'd like to know what other entities are reachable from it. How do you do this? The ability to get the type for an entity or entity set as described earlier is what helps us here:

1. Get the type of the entity as described in the previous section
2. Enumerate the navigation properties of that type
3. Each navigation property has a "Target" attribute -- this is the entity set that this property returns
4. Use the entity set again as above to obtain the actual type

### What are the next Graph URL segments?
The tricks described earlier, combined with some knowledge of how Graph constructs URL's, will let you determine how to find the next possible segments in the URL. We'll describe the algorithm below. To make it easier to understand, we give some analogies for OData terminology that pervades the schema:

* Entity: These are essentially "objects" that can be described with a schema. The schema is a set of properties with unique names within the entity. An entity has exactly one schema that describes it. Each property has a scalar or complex type and an associated value that conforms to that type.
* EntityType: This is the infinite class of all entities that share the same schema that could ever exist. Each EntityType is associated with exactly one EntitySet.
* EntitySet: One or more finite subsets of an EntityType -- it can be thought of as a database table, where each row is an entity. Rows may have different columns depending on the EntityType of the entity for that row
* Singleton: An alias to a single instance of a particular entity that is accessed outside the context of an EntitySet
* Navigation property: this is a property whose value is itself a subset of some EntitySet.

Here are a few things to keep in mind:

* Every Entity is a member of exactly one and only one EntitySet.
* EntitySets can contain entities of more than one EntityType

An important (to me) note is that the name *Graph* is constantly invoked but its descriptive applicability is never explained in any reference I've seen. I use the definitions from the data model above to suggest a clear definition how of the *Graph* conforms to the technical definition of Graph:

> *Graph* can be described as a graph because its data model can be mapped to the formal definition of graph. Specifically, a graph is an object G(V,E) where V is a set of of vertices and E is a set of ordered pairs (u,v) where u and v are members of V. This has an exact correspondence for *Graph* where union of the data model's EntitySet corresponds to V, and all entities in the graph are the members of V. The edges E correspond to each ordered pair of entities such that a navigation property of the first entity in the pair refers to a set that contains the second entity in the pair.

To put it simply, entities are the vertices of the graph, and navigation properties are the (sets) of edges.

And here are some axioms about how Graph URL's are structured with regard to the data model. In dicussing the URL, we ignore the service URI and its version, segment e.g. we will not mention `https://graph.microsoft.com/v1.0/`.

* The first URL segment is either the name of an EntitySet or a Singleton
* The second segment is either an entity identifier if the first segment was an EntitySet, or a navigation property if the first was a singleton
* Any segment after the two above is either an entity if the preceding segment referred to a navigation property, or a navigation property if the preceding segment was an entity set.

In generic graph terms, the Graph URL segments are structured in the following way if we consider each segment a vertex, and say that there is an edge from one segment to another if that segment can precede the other segment in the URL:

* There exists a set of vertices with no incoming edges. These vertices are labeled either singletons or entitysets. These vertices can reach every other vertex in the graph that is not a singleton or entityset vertex, and these are the only such vertices.
* For all other vertices there is at least one incoming edge -- these vertices are called entities.
* Singleton vertices and entitiy vertices, there is an edge to one more more entity vertices if that entity contains a non-empty navigation property

### Algorithm for finding the next segment from the previous segment

With the above definitions, we can obtain the possible values for the next segment from the previous segment. Note that in order to retrieve entities, we need to actually query the Graph service, but schematically we can usually refer to a placeholder since the entity will have a specific entiytype in all cases except where it is preceded by an entityset segment. In the case of entitysets, the specific type is ambiguous in many cases, i.e. where the set of all schemas defines more than one type as included in an entityset. In the worst case, we could allow interrogators to select from a list of possible types and then continue to traverse the URI.

Here is an algorithm:

Let R be the set of the names of all singletons and entitysets from the schema. We define the root of URI R to be the versioned service URI S, e.g. https://graph.microsoft.com/v1.0. If U is a graph URI of the form `S/U1/U2/...UN` where S is the predecessor of U1 and UN-1 is the predecessor of UN, the successor of segment UN can be determined as follows:

If S is the predecessor of UN, then UN may be the name of any of the members of R

If the predecessor of UN is an entityset or a navigationproperty that returns a collection, then UN may be any of the identifiers of any of the entities in the entityset or returned by the navigation property. A query can be made to determine those identifiers.

If the predecessor of UN is an entityset or a navigationproperty that returns a single entity, then UN may be any of the navigation properties of the type of the entity returned by the navigation property.

If the predecessor of UN is a singleton or an entity identifier, then UN may be the name of any of the navigation properties of the singleton or entity


### Example output for compressed list view
PowerShell's default `ls` (i.e. get-childitem) and Unix's `ls` both have a "mode" column that gives compressed information about the item in the list. Output can be very repetitive for `class` and `type` fields, especially when enumerating a collection, so compressing this into one field and then using one field for something that's unique, say the actual content, could be more appealing.

For example, this:

    Relation   Class     Type                  Name
    --------   -----     ----                  ----
    Collection EntitySet contract              contracts
    Data       Singleton deviceAppManagement   deviceAppManagement
    Data       Singleton deviceManagement      deviceManagement
    Collection EntitySet device                devices
    Data       Singleton directory             directory
    Collection EntitySet directoryObject       directoryObjects
    Collection EntitySet directoryRole         directoryRoles
    Collection EntitySet directoryRoleTemplate directoryRoleTemplates
    Collection EntitySet domainDnsRecord       domainDnsRecords

Could be

Location (bool) , Source (bool), Kind (char), Size (bool

Kind
Entityset
Singleton
entityType
Action
Function
Navigation



-
*
.

E
V


ok

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    lg*   EntitySet  contract              contracts
    lm    Singleton  deviceAppManagement   deviceAppManagement
     m*   EntityType deviceManagement      deviceManagement
     g    Action     device                devices
     m    Function   directory             directory
    lg    Navigation directoryObject       directoryObjects

or
ok

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    lg*   EntitySet  contract              contracts
    lm-   Singleton  deviceAppManagement   deviceAppManagement
    -m*   EntityType deviceManagement      deviceManagement
    -g-   Action     device                devices
    -m-   Function   directory             directory
    lg-   Navigation directoryObject       directoryObjects

or

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    lg*   EntitySet  contract              contracts
    lm-   Singleton  deviceAppManagement   deviceAppManagement
    -m*   EntityType deviceManagement      deviceManagement
    -g-?  Action     device                devices
    -m-   Function   directory             directory
    lg-   Navigation directoryObject       directoryObjects


or
no


    Info  Class      Type                  Name
    ----  -----      ----                  ----
    ++*   EntitySet  contract              contracts
    +-    Singleton  deviceAppManagement   deviceAppManagement
    --*   EntityType deviceManagement      deviceManagement
    -+    Action     device                devices
    --    Function   directory             directory
    ++    Navigation directoryObject       directoryObjects

or
no

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    ++*   EntitySet  contract              contracts
    +     Singleton  deviceAppManagement   deviceAppManagement
      *   EntityType deviceManagement      deviceManagement
     +    Action     device                devices
          Function   directory             directory
    ++    Navigation directoryObject       directoryObjects

or
no

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    l+*   EntitySet  contract              contracts
    l     Singleton  deviceAppManagement   deviceAppManagement
      *   EntityType deviceManagement      deviceManagement
     +    Action     device                devices
          Function   directory             directory
    l+    Navigation directoryObject       directoryObjects

or
no

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    .+*   EntitySet  contract              contracts
    .     Singleton  deviceAppManagement   deviceAppManagement
      *   EntityType deviceManagement      deviceManagement
     +    Action     device                devices
          Function   directory             directory
    .+    Navigation directoryObject       directoryObjects

or
ok

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    >+*   EntitySet  contract              contracts
    >     Singleton  deviceAppManagement   deviceAppManagement
      *   EntityType deviceManagement      deviceManagement
     +    Action     device                devices
          Function   directory             directory
    >+    Navigation directoryObject       directoryObjects

or
no

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    >+*   EntitySet  contract              contracts
    >--   Singleton  deviceAppManagement   deviceAppManagement
    --*   EntityType deviceManagement      deviceManagement
    -+-   Action     device                devices
    ---   Function   directory             directory
    >+-   Navigation directoryObject       directoryObjects

or
no

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    >g*   EntitySet  contract              contracts
    >m-   Singleton  deviceAppManagement   deviceAppManagement
    -m*   EntityType deviceManagement      deviceManagement
    -g-   Action     device                devices
    -m-   Function   directory             directory
    >g-   Navigation directoryObject       directoryObjects

or

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    >g*   EntitySet  contract              contracts
    >m-   Singleton  deviceAppManagement   deviceAppManagement
     m*   EntityType deviceManagement      deviceManagement
     g-   Action     device                devices
     m-   Function   directory             directory
    >g-   Navigation directoryObject       directoryObjects

or

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    g* >  EntitySet  contract              contracts
    m-    Singleton  deviceAppManagement   deviceAppManagement
    m*    EntityType deviceManagement      deviceManagement
    g ?   Action     device                devices
    m- >  Function   directory             directory
    g- >  Navigation directoryObject       directoryObjects


or

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    g* >  EntitySet  contract              contracts
    m     Singleton  deviceAppManagement   deviceAppManagement
    m*    EntityType deviceManagement      deviceManagement
    g ?   Action     device                devices
    m  >  Function   directory             directory
    g  >  Navigation directoryObject       directoryObjects



or

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    >g*   EntitySet  contract              contracts
    >m    Singleton  deviceAppManagement   deviceAppManagement
     m*   EntityType deviceManagement      deviceManagement
     g    Action     device                devices
     m    Function   directory             directory
    >g    Navigation directoryObject       directoryObjects


or

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    >g*   EntitySet  contract              contracts
    >m    Singleton  deviceAppManagement   deviceAppManagement
     m*   EntityType deviceManagement      deviceManagement
     g ?  Action     device                devices
     m    Function   directory             directory
    >g    Navigation directoryObject       directoryObjects

or

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    >g*   EntitySet  contract              contracts
    >m-   Singleton  deviceAppManagement   deviceAppManagement
     m*   EntityType deviceManagement      deviceManagement
     g-?  Action     device                devices
     m-   Function   directory             directory
    >g-   Navigation directoryObject       directoryObjects

or

    Info  Class      Type                  Name
    ----  -----      ----                  ----
    *g >  EntitySet  contract              contracts
     m >  Singleton  deviceAppManagement   deviceAppManagement
    *m    EntityType deviceManagement      deviceManagement
     g?   Action     device                devices
     m    Function   directory             directory
     g >  Navigation directoryObject       directoryObjects

### Replacing -json with -rawcontent

Here are the cmdlets using -json:

* Invoke-GraphRequest
* Get-GraphItem.ps1
* Get-GraphSchema.ps1
* Get-GraphVersion.ps1
* Test-Graph.ps1
* Get-GraphChildItem.ps1


### Another try at the 'Info' column

The 'Class' column is not very useful -- other than at the root, it's always the same for all results when actions and funtions are excluded, which is the normal case.

So let's stick it in the Info column.
'\>' is equivalent to 'not executable.'

Hmm, didn't like it :(.

Update: added 'Preview' column, so we ended up removing the 'Class' column and moving it to 'Info,' so in the end we did do a version of this.

### OrderBy support
I thought it was possible to specify a named parameter more than once in a PowerShell cmdlet, looks like this is not the case. In that case, to support multi-column sorts with arbitrary ascending / descending directions, we'll have to go beyond basic parameters and add extra interpretation to the values. Unfortunate.

Here's an attempt

```powershell
ggi /me/messages -first 10 -orderby Received -descending
ggi /me/messages -first 10 -orderby Received -descending
ggi /me/messages -first 10 -orderby @{Received=$true;Sender=$false}
```

### Get-GraphChildItem logic
The goal is for it to "feel" like ls / dir commands for the file system.

If we look at ls, it has the following behavior:

1. With no arguments, it has the same behavior as an argument of '.', the current directory
2. With an argument, the following happens:
   a. If the argument is has content rather than being a container, it simply returns information about that container
   b. If the argument is a container, it enumerates the current directory

We'd like to imitate that with `Get-GraphChildItem`, but there is a challenge:

> For Graph items, unlike file system items, the properties of possessing content and being containers are not mutually exclusive

That means we cannot differentiate between 2a and 2b above.

Perhaps, though, we don't have to -- we can apply some rule, e.g. a precedence, over what behavior to take for cases where Graph items fall into both categories. We could evaluate such approaches by how useful, deterministic, and intuitive they feel to users.

Here is a proposal -- here `gls` refers to `Get-GraphChildItem`:

1. We define "container" as EntitySet, or NavigationProperty.
2. When `gls` receives no argument, it enumerates all children of the current object and does not include the current object
   * This allows `cd`/ `ls` style browsing
3. When `gls` receives an argument and the argument is a container, the argument's children are returned and not the current object
   *
4. When `gls` receives an argument and the argument is not an entity, only the entity is returned.
   * This allows "selecting" a specific item
5. The switch `ItemAndChild` causes the argument and the children to be returned.
6. Another alias / function can proxy and always give the `ItemAndChild` behavior
7. We could make another command that `gls` aliases -- that way `Get-GraphChildItem` can retain the consistent container semantics expected in the `Get*-ChildItem` cmdlets.

### Set-GraphItemProperty parameters
Parameter sets in decreasing order of common usage. Basic issue is computing the abstract parameters:

* The target object -- there are various ways to describe this, but ultimately it must resolve to a URI. Options are:
  * By type + id
  * By Uri
  * By Uri (parent) + Id
  * By object
  * By object + type
  * By Uri (parent) + object
* The properties to set and their values -- this is the set of properties to change to specified values. This must ultimately resolve to a set P of properties with a 1:1 mapping to the set V of values.
  * By parallel list
  * By hash tables
  * By JSON object

```powershell

# Looks like parameters have the following parameterset counts
# TypeName: 8
# Uri: 6
# InputObject 4
# TemplateObject: (8+6+4)/2 = 9, Property: (8+6+4)/2 = 9, Value: (8+6+4)/2 = 9

# Default: TypeAndIdList

# By type name

# TypeAndIdList
# TypeAndIdMap
Set-GraphItemProperty user userid prop1, prop2 val1, val2
Set-GraphItemProperty user userid -TemplateObject @{prop1=val1;prop2=val2}

# By object

# TypedObjectList
# TypedObjectMap
$existing | Set-GraphItemProperty prop1, prop2 val1, val2
$existing | Set-GraphItemProperty -TemplateObject @{prop1=val1;prop2=val2}

# ObjectAndTypeList
# ObjectAndTypeMap
$existing | Set-GraphItemProperty user prop1, prop2 val1, val2
$existing | Set-GraphItemProperty user @{prop1=val1;prop2=val2}

# By property

# TypeAndPropertyNameList
# TypeAndPropertyNameMap
# UriParentAndPropertyNameList
# UriParentAndPropertyNameMap
Set-GraphItemProperty user -ByProperty name -ByValue myname prop1, prop2 val1, val2
Set-GraphItemProperty user -ByProperty name -ByValue myname @{prop1=val1;prop2=val2}
Set-GraphItemProperty -uri /users -ByProperty name -ByValue myname prop1, prop2 val1, val2
Set-GraphItemProperty -uri /users -ByProperty name -ByValue myname -TemplateObject @{prop1=val1;prop2=val2}

# By Uri

# UriList
# UriMap
# UriParentAndObjectList
# UriParentAndObjectMap
Set-GraphItemProperty -uri /users/userid prop1, prop2 val1, val2
Set-GraphItemProperty -uri /users/userid -TemplateObject @{prop1=val1;prop2=val2}
$existing | Set-GraphItemProperty -uri /users prop1, prop2 val1, val2
$existing | Set-GraphItemProperty -uri /users -TemplateObject @{prop1=val1;prop2=val2}


```

### Get-GraphItem vs. Get-GraphResource

As new write commands `New-GraphItem`, `Add-GraphItemReference`, `Set-GraphItemProperty` are added,
it becomes clear that these commands are not symmetric with the pre-existing "Item" commands
`Get-GraphItem` and `RemoveGraph-Item`. The newer commands are dependent on metadata, while the older
ones are not. The newer commands allow the user to specify Graph locations by type + id or
even by passing in an object obtained form the Graph, the older ones do not.

To resolve this, the following refactoring of the commands across modules is made, along with
clarification of their purposes:

* The existing `Get-GraphItem` and `Remove-GraphItem` commands will be renamed `Get-GraphResource` and `Remove-GraphResource`. They will remain in the `autographps-sdk` module as their purpose and dependencies aligns with that of the module: enable access to the Graph solely via REST without any dependency on metadata. The noun *Resource*" is actually appropriate here as the interface for these commands is URI-based, i.e. *Uniform Resource Identifier*-based.
* New versions of `Get-GraphItem` and `Remove-GraphItem` will be implemented in `autographps` rather than `autographps-sdk`. These commands will conform to the selection facilities used by `Set-GraphItemProperty` and the other new commands to specify a specific object.
  * `Get-GraphItem` will use `Property` rather than select to specify properties, other search / filter capabilities will probably be removed.
  * `Get-GraphItem` will output fully resolved type URIs via `Get-GraphUri`.
  * The default parameterset for `Get-GraphItem` may actually be URI-based -- URI's work for all cases, where type + id only works for entity types and does not return collections.
    * We could make a single element parameter set assume a singleton, a two-element parameter set a type + id, and `Uri` would have to be explicit.
* `Get-GraphChildItem` will be re-implemented using the same selection capability as `Get-GraphItem`.
* `Get-GraphItemWithMetadata` will be changed to `Get-GraphResourceWithMetadata`.
* The `gls` alias will continue to point to `Get-GraphResourceWithMetadata` as its behavior conforms more closely to the user experience of `ls` than `Get-GraphChildItem` does.
* Note that `AutoGraphPS` core aliases preserve the idea of resource-based navigation of the Graph vs. retrieving objects, and this is even compatible with the new commands which support a `Uri` parameter which is compatible with the navigable resource paradigm.

#### New Get-GraphChildItem parameters

`Get-GraphChildItem` will have all the parameters of `Get-GraphItem` in addition to the following:

* `PropertyFilter`: constructs a where clause of conjoined property equality expressions
* `ODataFilter`: allows for the user of an arbitrary OData filter
* `Search`: allows use of OData search
