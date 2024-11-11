Why AutoGraphPS (fka PoshGraph)?
================================

Many developers' first experience of the The Microsoft Graph is mediated through [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer). This web-based tool makes the abstract Graph API into something tangible to be navigated and manipulated as one would casually use a web browser.

Missing from Graph Explorer, however, is a facility for automation. That's the need filled by this project. AutoGraphPS is the programmable Graph Explorer designed for developers and system administrators. It's designed for both exploration AND automation.

## Developer wish list

Of the small number of tools focused on the Graph itself, there are none that support both human-oriented browsing AND automation. Such a tool would likely satisfy the "wish list" of characteristics below:

  * Universal -- acts on the entirety of the Graph, not just a particular subset
  * Integrated auth -- easy to use auth\*, no need to dive into auth protocols
  * Intuitive -- user interface that presents a simple but powerful conceptual model of the Graph to humans
  * Approachable -- requires no documentation to learn about not just the tool, but the Graph itself
  * Instructive -- progressively exposes you to more of the Graph, its features, and the tool's features as you use it
  * Scalable -- easy to use for the simplest Graph scenarios and also the most advanced
  * Command-line interface -- meet developers where they are
  * Programmable -- all tool functionality can be automated
  * Scriptable -- the same commands used for human interaction are used to automate the tool
  * Reusable -- can be used not just for automation, but for full-blown applications built with its runtime
  * Interoperable -- consumes and produces data using formats compatible with a wide range of standard tooling
  * Elastic -- requires no updates to take advantage of new APIs and services exposed in the Graph
  * Delightful -- your wildest ideas about the Graph made real with little to no friction

AutoGraphPS is a single app that provides "all of the above."

## Goals

The project's goals are:

  * Default UX for the Graph: Provide a human UX for DevOps engineers, including sysadmins and developers, to interactively access and experience the Graph
  * Zero-doc Graph onboarding: Teach users about the Graph API by using the Graph itself as opposed to starting with documentation
  * PowerShell Graph DevOps SDK: Provide a DevOps programming interface to the Graph for PowerShell-based automation and applications

## Design choices

The tool is designed to fulfill the aforementioned wish list, so each design choice below can be traced to one or more items on the list.

### UX built on PowerShell
The appeal of the command-line interface for developers, i.e. that users learn how to automate and build applications by using the same commands they issued to a shell in their everyday routines should be non-controversial. Similarly, the standardization of CLI tooling around PowerShell on Windows makes an obvious case that a developer tool targeting a largely Windows-focused user base must exist in that same PowerShell CLI environment.

However, the case for PowerShell goes beyond just fitting in. PowerShell has these advantages as a UX:

* Ease of implementation: PowerShell provides implementations of and formal interfaces for CLI UX conventions that have evolved over decades. So command-line argument / option parsing, verbose output, argument completion, environment overrides, and so many other behaviors have well-defined interfaces and even implementations of those features. When commands are developed on PowerShell, the UX is already specified, and the framework for providing those interfaces requires little to no effort to use.
* Approachability: Because PowerShell promotes a [standard naming convention](https://docs.microsoft.com/en-us/powershell/developer/cmdlet/approved-verbs-for-windows-powershell-commands) (i.e. "verb-noun" cmdlet names and standard verbs such as "get", "set," "new", etc.), users can often predict the name of the cmdlet needed for a given task, especially after using just one or two of the cmdlets in a related group. PowerShell commands have built-in argument completion as well, so users can often discover the usage of cmdlets without reading documentation.
* Scriptability / Programmability: PowerShell cmdlets are not just usable in adhoc cases, they may be used the same way from within scripts, i.e. programs / applications / automation, just as they are used interactively. Users can then create simple scripts by "replaying" commands entered interactively to test a scenario. Those scripts will be robust because PowerShell cmdlets take in and return return well-defined structured types (i.e. "objects") just as functions / procedures / methods do in any modern programming language. PowerShell scripts then can scale to the level of sophistication offered by other object-based scripting languages enabling full-blown applications and system libraries.
* Intuitiveness: Integrating with PowerShell's existing interfaces reveals omissions or inconsistencies in the intial conception of a CLI-UX; building on PowerShell forces implementors to reckon with those difficulties, ultimately resulting in an even simpler and more intuitive interface for users.

PowerShell through its conventions and CLI-feature support enforces a consistent, simple, scalable user interface for the CLI. By building with PowerShell, AutoGraphPS inherits those same productivity and delight-enhancing capabilities.

### Traverse it like the file system

For many command-line users and developers, a recurring structural metaphor is that of the hierarchical file system. It [pervades the Unix architecture and experience](https://en.wikipedia.org/wiki/Everything_is_a_file), and even on Windows, PowerShell surfaces ["drive providers"](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_providers?view=powershell-6) as a UX to abstract not just the file system, but also Windows-specific components such as the registry, certificate store, system environment variables, and even PowerShell's variables, functions, and aliases.

AutoGraphPS's cmdlets `Get-GraphChildItem`, `Get-GraphLocation`, and `Get-GraphLocation` provide a similar metaphor for the Graph, which, like a hierarchical file system, has a single root node from which all other nodes are reachable. Excepting the presence of the word "graph", the `cmdlets` names are the same as those of PowerShell's generic commands for traversing any provider, including the file system.

While AutoGraphPS's initial implementation does not include a PowerShell drive provider, the cmdlets emulate such behavior, allowing you to get and set your location in the hierarchy as in the `cd` command in many shells, and list the contents of the current location as in the `ls` or `dir` commands. More importantly, the notion of current and containing location allows you to omit long absolute paths for references to elements of the Graph when you are invoking the cmdlets from the shell, saving time and conserving cognitive space.

The effect is that just as one might explore the contents and capabilities of a file system in *nix, Windows, and other systems to discover capabilities and structure, the same can be done with AutoGraphPS, allowing users to learn where certain Graph functionality resides and how to use it.

### Keep it generic -- give it a REST

One approach to automating the Graph is to provide bespoke cmdlets dedicated to commonly used Graph capabilities, such as accessing e-mail or calendars, Active Directory data, cloud files, or spreadsheets. Cmdlets in each of these areas could be optimized for the given domain, and specific features or cmdlets updated over time as the services underlying those areas evolved.

The advantage to that approach is the ability to provide deep customization, including domain specific UX flows between cmdlets and also useful custom interactions with components outside of the Graph such as external databases, file systems, or visualization components.

That customization comes with a serious drawback: *Every time new features or capabilities are added to the Graph, the cmdlets must be updated to reflect it.*

AutoGraphPS uses a different approach: **Let AutoGraphPS act as a PowerShell layer on top of the Graph REST API layer.** This takes advantage of the fact that Graph is already a generic, and hopefully well-designed API based on a standard set of object types in the [Entity Data Model (EDM) metadata](https://developer.microsoft.com/en-us/graph/docs/concepts/traverse_the_graph). That data model is really what drives Graph, and it is continuously updated to reflect the new features added to services exposed by the Graph. In theory such an approach should be reasonable since if the Graph API itself is a truly usable API, making that API directly accessible through PowerShell should also result in similarly usable CLI experience.

AutoGraphPS's design is focused then on the following three things that apply to the entire Graph:

* Authentication: AutoGraphPS implements UX concepts for easy authentication and authorization via the OAuth2 protocol as required Microsoft Graph
* REST: AutoGraphPS automates REST conventions through consistent URI UX, handling of standard REST error statuses, and invocation of the appropriate REST methods (`GET`, `PUT`, `POST`, etc.)
* [Entity Data Model (EDM)](https://docs.microsoft.com/en-us/dotnet/framework/data/adonet/entity-data-model): AutoGraphPS consumes the [EDM metadata exposed by Graph](https://developer.microsoft.com/en-us/graph/docs/concepts/traverse_the_graph) to surface types and a sense of location, and thus capabilities, to the user

All of these design elements are universal throughout the Graph and are not specific to Entra ID (fka AAD), files, messaging, or any other part of the Graph. The advantages of aligning AutoGraphPS toward them are:

* No changes are needed to AutoGraphPS source code as new service features are enabled. Users do not need to continuously update their AutoGraphPS installations to get access to new Graph functionality.
* The AutoGraphPS code base is simpler as domain-specific code can be omitted
* Fewer poor cmdlet design choices are likely to be made in AutoGraphPS as domain-specific design is left to the Graph layer -- AutoGraphPS merely reflects what is in the Graph
* Domain-specific documentation developed for the Graph API itself can easily be consumed when using AutoGraphPS -- the URI's specified in the documentation along with REST methods are mapped 1-1 to URI's specified to AutoGraphPS cmdlets that themselves correspond to the appropriate REST methods.

This elasticity comes with a price, that of the loss of domain-specific optimization. The philosophy is that this tradeoff is worth it in the common case where there is value in avoiding frequent updates to AutoGraphPS to keep up with changes to the Graph API, and also in AutoGraphPS inheriting the Graph API's scalability of usage from simple to complex scenarios.

### Re-imagine Graph's rough spots

One of the most difficult aspects of using the Graph is authentication. While in theory standardization on OAuth2 should allow consumers of the Graph to take advantage of standard OAuth2 libraries, no such libraries exist explicitly for PowerShell itself. Even in C# where PowerShell can interoperate with libraries quite efficiently, there has been confusion on which of two major libraries to use, both of which support scenarios that the other does not. The result is that in languages with an OAuth2 SDK, several lines of code requiring knoweledge of specific authentication endpoints and "application identity" configurations, most notably the pre-registered application identity and redirection URIs, must be invoked.

AutoGraphPS aims to make authentication as easy as it is when using Graph Explorer -- invoke AutoGraphPS and provide credentials, and perhaps specify authorization scopes. No knowledge of the Entra ID application model, redirection URIs, application IDs, or login endpoints is required. A standalone cmdlet is even given to obtain authorization tokens that can be used with REST tools other than AutoGraphPS since those tools have no simple way of getting a Graph-specific token.

Another area of friction is that of the input and output format for interacting with the Graph. Graph uses JSON, which is well-supported by many tools and somewhat human readable. However, with the kinds of nested structures used by Graph, it is very easy to incorrectly interpret or construct Graph JSON.

To get around human comprehension of JSON, AutoGraphPS by default uses PowerShell objects which are converted between PowerShell objects and JSON through PowerShell's JSON serialization libraries. The result is that no careful JSON construction is required -- users can access Graph objects through AutoGraphPS as browsable objects as they would in native PowerShell, with C# via debuggers, or with dynamic languages including Javascript itself or Ruby, Python, etc.

### Don't RTFM

AutoGraphPS attempts to prompt users with solutions when certain kinds of errors are encountered. The goal is for users to be able to try scenarios that they think should work and get feedback from AutoGraphPS itself to correct their mistakes, rather than requiring study ahead of time or extensive web searches to understand workarounds for errors.

In general, AutoGraphPS also aims to take away the need to look up documentaiton, using much the same approach as Graph Explorer: use the Graph's EDM metadata to make it explorable. Allow entities and actions / functions to be discovered, or even make AutoGraphPS itself searchable. Then there is no need to leave AutoGraphPS to identify "docs" -- the tool itself surface the documentation.

### The PowerShell and REST ecosystems
A strength of PowerShell's object pipeline is that it facilitates modifications of objects emitted to the pipeline by any cmdlet. The modifications themselves are accomplished by another cmdlet operating on the pipeline. Thus the objects emitted by AutoGraphPS may be consumed not just be humans or as input to other commands, but by PowerShell's formatting cmdlets like `format-list` or `format-table`, or data processing cmdlets such as `select-object`, `sort-object`, `where-object`, and `compare-object`. These commands extend the usefulness of cmdlets provided by AutoGraphPS to richer scenarios in advanced analytics and applications.

Other PowerShell cmdlets such as the `convertto-*` and `convertfrom-*` cmdlets enable interperation with cmdlets or applications that consume alternative data formats such as `csv`. PowerShell's built-in usage of the C# XML serializer type `XmlSerializer` enables XML interoperability. The conversion capabilities, along with AutoGraphPS's capability to emit raw JSON, allow users to interoperate with non-PowerShell tools, including REST utilities popular in web app and API development.

Beyond the standard cmdlets included in PowerShell itself, repositories such as PowerShell Gallery and Nuget.Org provide a wide range of open source PowerShell modules that extend PowerShell. These libraries enable more than just scripting -- in concert with AutoGraphPS full-scale applications may be built with AutoGraphPS. Such modules can also extend the user experience provided by AutoGraphPS through richer formatting or query facilities.

### The missing PowerShell Programming Gateway for the Graph protocol
Given that PowerShell as a language has the same expressibilty and concepts as Javascript, Ruby, et. al., each of which have respective Graph SDKs, it makes sense to ask where a similar developer interface may be found for Graph. AutoGraphPS is that programming surface, and because it uses a simple layering on top of the Graph API, it is a robust experience that does not require PowerShell users to constantly update to the latest version of AutoGraphPS to use new Graph features.

### Powered by PowerShell

It's not just the user interface of AutoGraphPS that is based on PowerShell -- AutoGraphPS itself is written entirely in PowerShell, modulo external auth library dependencies.

This choice is rather unusual -- C# is typically the language used for non-trivial cmdlet modules like AutoGraphPS.

The reason behind the decision is simple: Given that the choice was made to base AutoGraphPS's UX in PowerShell, it's easier for those PowerShell users of AutoGraphPS to contribute to the project through PowerShell rather than C#:
  * More of AutoGraphPS's users know PowerShell compared to those who know C#. Those new to Windows-oriented technologies or trained with a systems administration focus may never have encountered C#. The larger pool of PowerShell users empowers a larger pool of potential contributors.
  * PowerShell is faster for rapid development scenarios: Everything you need to develop new PowerShell scripts is already installed on any modern Windows system. If AutoGraphPS runs on the system where you install it, you know you can write and test code for it. Exercising a change is as simple as editing text files and then running the relevant PowerShell cmdlets just as in everyday use of AutoGraphPS. To develop using C#, a fairly large IDE must be installed (after a reboot or two), that IDE and compiler tools *must* be a version compatible with the project's chosen version, and after editing source code a build step is required to exercise the change

The use of PowerShell rather than C# results in a substantially lower overhead of development and its more widespread penetration as a language for AutoGraphPS's target pool of users means more possible contributors. Both of these factors should increase the probabilty that users can and will contribute to AutoGraphPS.

### What's not in AutoGraphPS?

Given the positioning of AutoGraphPS as interactive tool, teaching instrument, and SDK, is there anything it can't do?

Absolutely. The best way to understand its limitations is simply to view AutoGraphPS as a thin but capable PowerShell layer on top of the Graph API, one that supports human interaction. With this framing, AutoGraphPS is clearly not an application in and of itself any more than the Graph API. Thus, fully-realized applications or functionality that operates on a subset of the Graph are out of scope for Graph. Such examples include:
* An Graph-based e-mail client
* A utility for managing OneDrive files
* A custom tree view of Azure Active Directory
* Dedicated cmdlets for SharePoint

In general, any capability that is relevant to the entire Graph is worthy of consideration for AutoGraphPS, particularly those capabilities that align with the wish list and conform to the AutoGraphPS design choices.

## Where next?

The AutoGraphPS project's initial focus was to prove the concept of a PowerShell-based Graph explorer. These first implementations delivered a simplifed authentication and authorization experience, navigation UX through the Graph's Entity Data Model metadata, and `GET`-based read-only Graph API calls through easy to use PowerShell objects instead of JSON.

There are, then, some obvious next steps for the project in terms of both features and making the project useful to the community of Graph users:

* Make existing capabilities even easier to use
* More tests to enable contributions from more than just the original maintainer
* Cmdlet help
* Performance enhancements
* Extension of the file system metaphor for move, copy, and similar semantics
* New projects to provide domain-specific cmdlets built on AutoGraphPS (e.g. file management, email, etc.)
* AutoGraphPS equivalents for other languages -- Python anyone?

These are suggestions. Ultimately for the project to move beyond a proof of concept, it is the community that must provide the guidance and source contributions that make AutoGraphPS a truly useful gateway to the Graph.

# Appendix

## Completed improvements

The following items were noted as upcoming improvements as part of the earlier *Where Next* section and have now been completed and removed from that list:

* Write (i.e. `PUT`) operations on the Graph
* Entity object construction
* Graph API method invocation with parameter passing
* Keyword search on entities and locations in the Graph
