PoshGraph
=========

<img src="https://raw.githubusercontent.com/adamedx/poshgraph/master/assets/PoshGraphIcon.png" width="100">

----

**PoshGraph** is a PowerShell-based CLI for exploring the [Microsoft Graph](https://graph.microsoft.io/). It can be thought of as a command-line analog to the browser-based [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer).

The project is in the earliest stages of development and almost but not quite yet ready for collaborators.

## System requirements

PoshGraph requires Windows 10 and PowerShell 5.0.

## Installation and usage
PoshGraph is available through the [PowerShell Gallery](https://www.powershellgallery.com); run the following command to install the latest stable release of PoshGraph into your user profile:

```powershell
Install-Module PoshGraph -scope currentuser
```

Once that's finished, you can use a PoshGraph cmdlet like `Get-GraphItem` below to test out your installation. You'll need to authenticate using a [Microsoft Account](https://account.microsoft.com/account) or an [Azure Active Directory (AAD) account](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-whatis):

```powershell
PS> get-graphitem me
```

After you've responded to the authentication prompt, you should see output that represents your user object similar to the following:

    id                : 82f53da9-b996-4227-b268-c20564ceedf7
    officeLocation    : 7/3191
    @odata.context    : https://graph.microsoft.com/v1.0/$metadata#users/$entity
    surname           : Okorafor
    mail              : starchild@mothership.io
    jobTitle          : Professor
    givenName         : Starchild
    userPrincipalName : starchild@microsoft.io
    businessPhones    : +1 (313) 360 3141
    displayName       : Starchild Okorafor

Now you're ready to use any of PoshGraph's cmdlets to access and explore Microsoft Graph!

### Installing from git for developers
For developers contributing to PoshGraph or those who wish to test out pre-release features that have not yet been published to PowerShell Gallery, run the following PowerShell commands to clone the repository and then build and install the module:

```powershell
git clone https://github.com/adamedx/poshgraph
cd poshgraph
.\build\install-fromsource.ps1
```

## How to explore with PoshGraph
After you've installed the module, use PoshGraph from any PowerShell session.

### Get started -- simple commands

**PoshGraph** cmdlets allow you to explore the graph. Before using the cmdlets, you must establish a connection to the graph. The easiest approach is to use the `Connect-Graph` cmdlet, after which you can execute other cmdlets such as `Get-GraphItem` which operate on the graph:

```powershell
Connect-Graph
Get-GraphItem me
```

After you respond to authentication prompts from `Connect-Graph` cmdlet, `GetGraphItem` returns a PowerShell object representing MS Graph's view of the `me` entity, i.e. the entity that represents your user object. The output will be as described in an earlier section.

Since `Connect-Graph` establishes a logical "session," you can continue to execute cmdlets without being asked to re-authenticate, e.g.

```powershell
PS> get-graphitem organization
```

which will return details about your organization:

    id              : fb6df3ba-c5f5-43dd-b108-a921f1a7e759
    businessPhones  : {206 881 8080}
    city            : Seattle
    displayName     : Akana
    postalCode      : 98144
    state           : Washington
    street          : 101 23rd Avenue Suite X

### Expanding your scope

The commands above are trivial demonstrations of Graph. In particular, they only require the authorization scope known as `User.Read`. More interesting explorations of the Graph require that you request additional [scopes](https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference) when you connect to the Graph.

Here's how you can request the `Files.Read` and `Contacts.Read` scopes in addition to `User.Read` -- the additional scopes enable you to access those parts of the Graph for reading information about user files from *OneDrive* and your list of personal contacts:

```powershell
Connect-Graph 'User.Read', 'Files.Read', 'Contacts.Read'
```

Now you can execute the following commands to read OneDrive file data and your contact information:

```powershell
PS> get-graphitem me/contacts | select displayname
```

```
displayName
-----------
Cosmo Jones
Akeelah Smith
John Henry
Deandre George

PS> get-graphitem me/drive/root/children | select name

name
----
grocerylist.md
history.md
graphsearch.ps1
```

Note that the subject of scopes and authorization in general is currently one of the most difficult aspects of Graph to understand. You'll need to consult the [permissions documentation](https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference) to understand what scopes are needed to access different locations of the Graph. In some cases, you will be unable to obtain the required scope without an action by your system administrator, or you will need to authenticate with an application identity rather than your user identity.

Future modifications to PoshGraph will address the usability of scopes and authorization.

### Command inventory

The full list of cmdlets is given below; they go well beyond simply reading information from the Graph. As this library is in the early stages of development, that list is likely to evolve signicantly along with their usage. Additional documentation will be provided for them as their status solidifies.

| Cmdlet                  | Description                                                                                     |
|-------------------------|-------------------------------------------------------------------------------------------------|
|  Connect-Graph          | Establishes an authentication and authorization context used for subsequent commands            |
|  Disconnect-Graph       | Clears authentication and authorization context used across commands                            |
|  Get-GraphItem          | Given a relative Uri from the root of graph, gets information about the entity                  |
|  Get-GraphError         | Retrieves detailed errors returned from Graph in execution of the last command                  |
|  Get-GraphSchema        | Returns the [Entity Data Model](https://docs.microsoft.com/en-us/dotnet/framework/data/adonet/entity-data-model) for a part of the graph as expressed through [CSDL](http://www.odata.org/documentation/odata-version-3-0/common-schema-definition-language-csdl/)       |
|  Get-GraphToken         | Gets an access token for the Graph -- helpful in using other tools such as [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)  |
|  Get-GraphVersion       | Returns the set of workloads and their associated schemas for a given Graph API version         |
|  Invoke-GraphRequest    | Executes a REST method (e.g. `GET`, `PUT`, `POST`, `DELETE`, etc.) for a Graph Uri           |
|  New-GraphConnection    | Creates an authentication / authorization context to be explictly supplied to commands          |
|  Test-Graph             | Retrieves unauthenticated diagnostic information from instances of your Graph endpoint          |

#### Limited support for Azure Active Directory (AAD) Graph

Some PoshGraph cmdlets also work with [Azure Active Directory Graph](https://msdn.microsoft.com/Library/Azure/Ad/Graph/howto/azure-ad-graph-api-operations-overview), simply by specifying the `-aadgraph` switch as in the following:

```powershell
Get-GraphItem me -aadgraph
```

Most functionality of AAD Graph is currently available in MS Graph itself, and in the future all of it will be accessible from MS Graph. In the most common cases where a capability is accessible via either Graph, use MS Graph to ensure long-term support for your scripts and code and your ability to use the full feature set of PoshGraph.

## Contributing / Development

The project is almost ready for contributors; suggestions on features or other advice are welcome while we establish a baseline.

See the [Build README](build/README.md) for instructions on building and testing changes to PoshGraph.

### Quickstart -- learn about the Graph
The Quickstart is a way to try out PoshGraph without installing the PoshGraph module. In the future it will feature an interactive tutorial. Additionally, it is useful for developers to quickly test out changes without modifying the state of the operating system or user profile. Just follow these steps on your workstation to start **PoshGraph**:

* [Download](https://github.com/adamedx/poshgraph/archive/master.zip) and extract the zip file for this repository **OR** clone it with the following command:

  `git clone https://github.com/adamedx/poshgraph`

* Within a **PowerShell** terminal, `cd` to the extracted or cloned directory
* Execute the command for **QuickStart**:

  `.\build\quickstart.ps1`

This will download dependencies, build the PoshGraph module, and launch a new PowerShell console with the module imported. You can execute a PoshGraph cmdlet like the following in the console -- try it:

  `Test-Graph`

This should return something like the following:

    ADSiteName : wst
    Build      : 1.0.9736.8
    DataCenter : west us
    Host       : agsfe_in_29
    PingUri    : https://graph.microsoft.com/ping
    Ring       : 4
    ScaleUnit  : 000
    Slice      : slicea
    TimeLocal  : 2/6/2018 6:05:09 AM
    TimeUtc    : 2/6/2018 6:05:09 AM

If you need to launch another console with Posh Graph, you can run the faster command below which skips the build step since QuickStart already did that for you (though it's ok to run QuickStart again):

    .\build\import-devmodule.ps1

These commmands can also be used when testing modifications you make to PoshGraph, and also give you an isolated environment in which to test and develop applications and tools that depend on PoshGraph.

License and Authors
-------------------
Copyright:: Copyright (c) 2018 Adam Edwards

License:: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

