# ROADMAP for PoshGraph

## To-do items -- prioritized

* Use BEGIN, PROCESS, END in get-graphuri
* Make context meaningful
  * unmount-graph -- remove-graph
* Aliases:
  * gls - get-graphchilditems
  * gcd - set-graphlocation
  * gwd - get-graphlocation
  * ggi - get-graphitem
* Add display type for get-graphchilditem
* Add display type for get-graphitem
* Get-GraphItem -offline # offline retrieves type data, requires metadata download
* Get-GraphChildItems -offline # offline retrieves type data, requires metadata download
* # So offline allows you to set an offline mode in the drive provider -- providers will have both offline and online, or maybe metadata itself is a drive
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
* Add -filter to get-graphitem
* Add -filter to get-graphschema
* common scopes -- use dynamicparam
* scope browser
* Refactor directories
* Add unit tests for parameters
* Enable token refresh
* Enable app-only auth
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

### Postponed

* transform schema, version objects to hashtables

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


