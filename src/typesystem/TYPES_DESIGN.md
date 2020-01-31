Graph Type System modeling in AutoGraphPS
=========================================

The TypeSystem subsystem of AutoGraphPS enables Graph API schema browsing and the creation of objects of the types defined in the Graph API schema. A key role for this component is to improve usability of scenarios in which users make requests to create and update requests to the Graph and or specify parameters for action and function invocation requests to the API.

#### Terms and concepts

The basis of the type system design includes the following concepts:

* *Type schema*: This refers formally to the definition of the Graph API's types expressed through the OData standard Common Schema Definition Language (CSDL).
* *Type class* refers to one of the four types that can be expressed in CSDL: Entity, Complex, Enumeration, and Primitive.
* *Type definition* refers to a canonical representation of types expressed in CSDL and OData in a format specific to AutoGraphPS.
* A *Property definition* is the subset of a *Type definition* that describes properties represented in CSDL.
* A  *Type Id* is an identifier unique to each type exposed in the CSDL for a given Graph API.
* The *Type provider* class can satsify queries that return *type definitions* and other type metadata for types of a given *type class*.
* A *prototype* for a given type is an object that satisfies the type's *type definition* and therefore also its *type schema*.

#### Classes

Below are some schematic representations of the classes for this subsystem. This section does not literally describe the implementation in this codebase, rather it serves as the initial thinking around the responsibility and state for each class.

* TypeSchema -- helper class with methods for accessing CSDL schema
* TypeDefinition -- abstraction of types defined in the CSDL
  * TypeId
  * Namespace
  * TypeClass (Entity, Complex, Primitive, Enumeration)
  * BaseTypeId
  * DefaultValue
  * DefaultCollectionValue
  * Properties
  * NativeSchema
  * Methods
    * Get
* Property -- used to declare properties in a TypeDefinition
  * Name
  * TypeId
  * IsCollection
* TypeManager -- provides access to graph types and prototype objects across Graph APIs
  * Methods
    * FindTypeDefinition
    * GetTypeDefinition
    * GetPrototype
* GraphObjectBuilder -- builds a prototype object given a type definition
  * Methods
    * ToObject
* ScalarTypeProvider -- returns type definitions for scalar types, i.e. types whose structure cannot be decomposed further, specifically Enumeration and Primitive types.
  * Methods
    * GetTypeDefinition
    * GetSortedTypeNames
* CompositeTypeProvider -- returns type definitions for composite types, i.e. types whose structure is composed of properties of other types
  * Methods
    * GetTypeDefinition
    * GetSortedTypeNames

