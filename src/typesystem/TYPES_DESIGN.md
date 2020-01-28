Graph Type System modeling in AutoGraphPS
=========================================

The TypeSystem subsystem of AutoGraphPS enables Graph API schema browsing and the creation of objects of the types defined in the Graph API schema. A key role for this component is to improve usability of scenarios in which users make requests to create and update requests to the Graph and or specify parameters for action and function invocation requests to the API.

#### Terms and concepts

The basis of the type system design includes the following concepts:

* *Type schema*: This refers formally to definition of types found on the Common Schema Definition Language (CSDL) defined by the OData standard that is used by Graph to define APIs.
* Use *type* to refer to the user-friendly type as returned by Get-GraphType -- raw from EDM
* Use *definition* to refer to an alternate representation of the raw type from Graph
* Use *declaration* when referencing a type, typically in the context of membership
* Use *typename* to index types in a declaration
* Use *prototype* to indicate a fully-resolved instance of a type

Question: should types have both a resolved and unresolved state? That's the initial approach. This avoids a situation where we have separate type and definition objects with overlapping property sets. We seem to have separate concepts of members and declarations -- why?
Think of what happens when you serialize -- if two types A and B both contain a member of type C, then serializing A and B duplicates C.
To avoid this, I think we should separate into type and template, or type and prototype.


#### Classes

* GraphType -- with singleton dictionary to unresolved graph types
  - A, B, C, F
  * TypeName
  * TypeClass (Entity, Complex, Primitive, Enumeration)
  * BaseTypeName
  * Members
* Member -- used to declare members
  - G, D
  * Name
  * GraphType
  * IsCollection
* GraphTypeManager -- provides access to graph types and prototype objects
  - H
  * Methods
    * GetGraphType
* TypeDefinition
  * Methods
    * GetProperties
* TypeDefinitionBuilder
  * NewGraphType
* ObjectBuilder -- builds objects from type definitions -- is this just the implementation of GetPrototype?
  - Not one of the previously covered classes
  * Methods
    * GetPrototype
    * NewObject
* PrimitiveType -- singleton
  - K, E
  * Name
  * Type
  * DefaultValue
  * DefaultCollectionValue
* EnumerationType -- singleton
  - I, J
  * Name
  * Members dictionary
* ParameterBuilder? -- builds the body for a given method
  * Can build functions (parameters in uri's)
  * Can build actions (parameters in body)

### Variation 4

#### Terms

* Use *type* as the abstract concept of a set of objects rather than a specific artifact of the design
* Use *schema* to refer to the low-level "native" description of the type, including its composition based on other types. For entity and complex types, this is logically equivalent to the CSDL schema.
* Use *type class* to refer to a classification of types -- primitive, enumeration, open, and complex with semantics from OData
* Use *type definition* to refer to a canonical representation of a type described by some schema
* Use *member* to denote a named subset of the data in an instance and description of that subset's structure via reference to a type definition
* Use *typeid* to uniquely identify types in a graph and reference types in a type definition for a composite type
* Use *prototype* to indicate an instance of a type definition whose structure conforms to the definition

#### Classes

* GraphTypeClass -- enumeration of different classes of type supported by Microsoft Graph:
  * Primitive
  * Enumeration
  * Complex
  * Open
* TypeManager -- provides access to graph type definitions and prototype objects for a given graph
  - H
  * Methods
    * FindTypeDefinition
    * GetTypeDefinition
    * GetPrototype
* TypeDefinition -- canonical representation of a type
  - B, C, F
  * TypeId
  * BaseType
  * Name
  * Namespace
  * Members
  * Class
  * IsComposite
  * DefaultValue
  * DefaultCollectionValue
  * Static Methods
    * Get -- Finds a type for a given type class and type id -- the only supported way to create an instance of this class
* Member -- models structure of a subset of the data modeled by a type
  - G, D
  * Name
  * TypeId
  * IsCollection
* TypeSchema -- helper class for accessing schema
  * Static methods
    * Methods for extracting and formatting information from schema data sources
* TypeProvider
  * GetTypeDefinition
  * Static Methods
    * GetTypePRovider
* ScalarTypeProvider
  - I, J, E
  * GetTypeDefinition
  * Static Methods
    * GetTypeProvider
* CompositeTypeProvider
  - H
  * GetTypeDefinition
  * Static Methods
    * GetTypeProvider
* GraphObjectBuilder
  - A
  * ToObject

### Commands

* Invoke-GraphMethod
* Set-GraphItem
* New-GraphItem

#### Code layout

src/typesystem


#### Feature rollout

1. Type Creation
2. Entity creation
3. Parameter Creation
4. Method invocation
5. Patching

