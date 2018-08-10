PoshGraph
=========

<img src="https://raw.githubusercontent.com/adamedx/poshgraph/master/assets/PoshGraphIcon.png" width="100">

----

* [Overview](#Overview)
* [Installation](#Installation)
* [Using PoshGraph](#using-poshgraph)
* [Common uses](#common-uses)
* [Command inventory](#command-inventory)
* [Developer installation from source](#developer-installation-from-source)
* [Contributing and development](#contributing-and-development)
* [Quickstart](#quickstart)
* [License and authors](#license-and-authors)

## Overview

**PoshGraph** is a PowerShell-based CLI for exploring the [Microsoft Graph](https://graph.microsoft.io/). It can be thought of as a CLI analog to the browser-based [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer). PoshGraph enables powerful command-line access to the Microsoft Graph REST API gateway. The Graph exposes a growing list of services such as

* Azure Active Directory (AAD)
* OneDrive
* Exchange / Outlook
* SharePoint
* And many more!

If you're an application developer, DevOps engineer, system administrator, or enthusiast power user, PoshGraph was made just for you.

The project is in the earliest stages of development and almost but not quite yet ready for collaborators.

### System requirements

PoshGraph requires Windows 10 and PowerShell 5.0.

## Installation
PoshGraph is available through the [PowerShell Gallery](https://www.powershellgallery.com/packages/poshgraph); run the following command to install the latest stable release of PoshGraph into your user profile:

```powershell
Install-Module PoshGraph -scope currentuser
```

## Using PoshGraph
Once you've installed, you can use a PoshGraph cmdlet like `Get-GraphItem` below to test out your installation. You'll need to authenticate using a [Microsoft Account](https://account.microsoft.com/account) or an [Azure Active Directory (AAD) account](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-whatis):

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
    userPrincipalName : starchild@mothership.io
    businessPhones    : +1 (313) 360 3141
    displayName       : Starchild Okorafor

Now you're ready to use any of PoshGraph's cmdlets to access and explore Microsoft Graph! Visit the [WALKTHROUGH](docs/WALKTHROUGH.md) for detailed usage of the cmdlets.

### How do I use it?

If you're familiar with the Microsoft Graph REST API or you've used [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer), you know that Graph is accessed via [URI's that look like the following](https://developer.microsoft.com/en-us/graph/docs/concepts/overview#popular-requests):

```
https://graph.microsoft.com/v1.0/me/calendars
https://graph.microsoft.com/v1.0/me/people
https://graph.microsoft.com/v1.0/users
```

With PoshGraph cmdlets, you can invoke REST methods from PowerShell and omit the common `https://graph.microsoft.com/v1.0` of the URI as follows:

```powershell
Get-GraphItem me/calendars
Get-GraphItem me/people
Get-GraphItem users
```

These commands retrieve the same data as a `GET` for the full URIs given earlier. Of course, `Get-GraphItem` supports a `-AbsoluteUri` option to allow you to specify that full Uri if you so desire.

As with any PowerShell cmdlet, you can use PoshGraph cmdlets interactively or from within simple or even highly complex PowerShell scripts and modules since the cmdlets emit and operate upon PowerShell objects.

### More fun commands

Run the command below to grant permission scopes that allow PoshGraph to read your **mail**, **contacts**, **calendar**, and **OneDrive files**:

```powershell
# You only have to do this once, not each time you use PoshGraph
Connect-Graph User.Read, Mail.Read, Contacts.Read, Calendars.Read, Files.Read
```

Now traverse the Graph via the `gcd` alias to "move" to a new Uri current location in the Graph. This is analgous to the usage of "cd" to change to a new current working directory in file-system oriented shells like `bash` and PowerShell:

```
gcd me
[starchild@mothership.io] v1.0:/me
PS>
```

Notice the update to your prompt showing your authenticated identity and your new current location after invoking that last cmdlet: `[starchild@mothership.io] v1.0:/me`. **Tip:** the `gwd` alias acts like `pwd` in the file system and retrieve your current working location in the Graph.

Now you can use the `gls` alias as you would `ls` in the file system relative to your current location. Here's how you can read your email:

```
[starchild@mothership.io] v1.0:/me
PS> gls messages
```

Here are a few more commands to try -- note that you can also use absolute paths rather than paths relative to the current location
```powershell
# Lists your calendars, sssuming you're at /me
gls calendars

# Same thing, uses an absolute path
gls /me/calendars

# Get data about your organizationn
gls /organization

# Get all the paths at the root of the Graph
gls /

```

Finally, here's one to enumerate your OneDrive files
```
[starchild@mothership.io] v1.0:/me
PS> gcd drive/root/children
[starchild@mothership.io] v1.0:/me/drive/root/children
PS> gls

Info Type      Preview       Name
---- ----      -------       ----
t +> driveItem Recipes       13J3XD#
t +> driveItem Pyramid.js    13J3KD2
```

#### PoshGraph tips
Here are a few simple tips to keep in mind as you first start using PoshGraph:

**1. Permission scopes matter:** PoshGraph can only access parts of the Graph for which you (or your organization's administrator) have given consent. Use the `Connnect-Graph` cmdlet to request additional scopes for PoshGraph, particularly if you run into authorization errors. Also, consult the [Graph permissions documentation](https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference) to understand what scopes are required for particular subsets of the Graph. Note that if you're using an Azure Active Directory account to access the Graph, you may need your organization's administrator to consent to the scopes on your behalf in order to grant them to PoshGraph.

**2. PoshGraph supports write operations on the Graph:** Use the `Invoke-GraphRequest` cmdlet to access write methods such as `PUT`, `POST`, `PATCH`, and `DELETE`. For operations that require input, the cmdlet provides options such as `-body` which allow the specificatio of `JSON` formatted objects. Support for a simpler cmdlet interface for write operations is coming soon to PoshGraph that will bring ease-of-use parity with the read cmdlets.

**3. You can access the Beta version of the Graph API**: By default, PoshGraph is targeted at the default API version of Graph, `v1.0`. It also works with the `beta` version -- just use the following commands to "mount" the `beta` version and set the current location to its root:

```powershell
new-graph beta
gcd beta:/ # This may take some time, you can CTRL-C and try again a few minutes later when its ready
```

And that brings us to this **Warning**: *PoshGraph takes some time to get fully ready for each API version.* When you first execute commands like `gls` and `gcd`,, some information about the structure of the Graph may be incomplete. In these cases you should see a "warning" message. You can also Use the `gg` alias to see the status of your mounted API versions, i.e. `Ready`, `Pending`, etc., which can take a few minutes to reach the desired `Ready` state. Eventually the warning will no longer occur and the cmdlets will return full information after the background metadata processing completes.

For a much more detailed description of PoshGraph's usage and capabilities, including advanced query and authentication features, see the [WALKTHROUGH](docs/WALKTHROUGH.md).

## Common uses

PoshGraph is your PowerShell interface to the Microsoft Graph REST API. In what contexts is such a tool useful? Here are several:

* **Developer - Graph education:** The Microsoft Graph is aimed at developers, and just as Graph Explorer helps developers learn how to make API calls to the Graph and debug them, PoshGraph offers the same capability, with the added benefit of the CLI's speed and automation
* **Developer - testing and debugging:** PoshGraph makes it trivial to reproduce errors you encounter in your application's REST calls to the Graph -- simply use the same credentials, REST method, and Uri in one of the Graph cmdlets, and you can obtain diagnostics without rebuilding your application or otherwise altering it to isolate failure cases and add debugging information. PoshGraph is also useful for pursuing ad hoc "what if"-style investigations of Graph functionality that is new to you or understanding Graph's corner cases without building a new application.
* **System administration:** Sysadmins manage the same services such as AAD, Exchange, and SharePoint that are exposed by the Microsoft Graph. Sysadmins are also heavy users of PowerShell. PoshGraph allows administrators to author PowerShell automation that takes full advantage of the management capabilities constantly being added to Microsoft Graph. Your existing PowerShell automation can be enhanced with PoshGraph or included in new tools based on it.
* **Developer - management tools:** Configuration management and system administration tools are popular output for developers, particularly in OSS communities. PoshGraph offers developers building PowerShell-based configuration management tools for their users a key library that solves authentication, modeling, querying, and deserialization. Graph calls with PoshGraph are typically one-liners requiring little in the way of setup, a quality that enhances your productivity as a developer.
* **Enthusiast / power user:** Users who enjoy learning about what powers their software will find PoshGraph a great way to not only learn about Graph, but exploit its capabilities to do things such as advanced e-mail or photo management through Exchange and OneDrive, implement their own backup features with OneDrive and SharePoint, or simply automate common tasks.

There are probably many more uses for PoshGraph, as wide-ranging as the Graph itself.

## Command inventory

The full list of cmdlets is given below; they go well beyond simply reading information from the Graph. As this library is in the early stages of development, that list is likely to evolve significantly along with their usage. Additional documentation will be provided for them as their status solidifies.

| Cmdlet                    | Alias | Description                                                                                     |
|---------------------------|-------|-------------------------------------------------------------------------------------------------|
| Connect-Graph             |       | Establishes authentication and authorization context used across cmdlets for the current graph  |
| Disconnect-Graph          |       | Clears authentication and authorization context used across cmdlets for the current graph       |
| Get-Graph                 | gg    | Gets the current list of versioned Graph service endpoints available to PoshGraph               |
| Get-GraphChildItem        | gls   | Retrieves in tabular format the list of entities for a given Uri AND child segments of the Uri  |
| Get-GraphConnectionStatus |       | Gets the `Online` or `Offline` status of a connection to a Graph endpoint                    |
| Get-GraphError            | gge   | Retrieves detailed errors returned from Graph in execution of the last command                  |
| Get-GraphItem             | ggi   | Given a relative (to the Graph or current location) Uri gets information about the entity       |
| Get-GraphLocation         | gwd   | Retrieves the current location in the Uri hierarchy for the current graph                       |
| Get-GraphSchema           |       | Returns the [Entity Data Model](https://docs.microsoft.com/en-us/dotnet/framework/data/adonet/entity-data-model) for a part of the graph as expressed through [CSDL](http://www.odata.org/documentation/odata-version-3-0/common-schema-definition-language-csdl/)       |
| Get-GraphToken            |       | Gets an access token for the Graph -- helpful in using other tools such as [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)  |
| Get-GraphUri              | ggu   | Gets detailed metadata about the segments of a Graph Uri or child segments of the Uri           |
| Get-GraphVersion          |       | Returns the set of workloads and their associated schemas for a given Graph API version         |
| Invoke-GraphRequest       |       | Executes a REST method (e.g. `GET`, `PUT`, `POST`, `DELETE`, etc.) for a Graph Uri           |
| New-Graph                 |       | Mounts a new Graph connection and associated metadata for availability to PoshGraph cmdlets     |
| New-GraphConnection       |       | Creates an authenticated connection using advanced identity customizations for accessing a Graph|
| Remove-Graph              |       | Unmounts a Graph previously mounted by `NewGraph`                                             |
| Set-GraphConnectionStatus |       | Configures `Offline` mode for use with local commands like `GetGraphUri` or re-enables `Online` mode for accessing the Graph service |
| Set-GraphLocation         | gcd   | Sets the current graph and location in the graph's Uri hierarchy; analog to `cd` / `set-location` cmdlet for PowerShell when working with file systems |
| Set-GraphPrompt           |       | Adds connection and location context to the PowerShell prompt or disables it                    |
| Test-Graph                |       | Retrieves unauthenticated diagnostic information from instances of your Graph endpoint          |
| Update-GraphMetadata      |       | Downloads the the latest `$metadata` for a Graph and updates local Uri and type information accordingly |

### Limited support for Azure Active Directory (AAD) Graph

Some PoshGraph cmdlets also work with [Azure Active Directory Graph](https://msdn.microsoft.com/Library/Azure/Ad/Graph/howto/azure-ad-graph-api-operations-overview), simply by specifying the `-aadgraph` switch as in the following:

```powershell
Get-GraphItem me -aadgraph
```

Most functionality of AAD Graph is currently available in MS Graph itself, and in the future all of it will be accessible from MS Graph. In the most common cases where a capability is accessible via either graph, use MS Graph to ensure long-term support for your scripts and code and your ability to use the full feature set of PoshGraph.

### More about how it works

If you'd like a behind the scenes look at the implementation of PoshGraph, take a look at the following article:

* [Microsoft Graph via PowerShell](https://adamedx.github.io/softwarengineering/2018/08/09/Microsoft-Graph-via-PowerShell.html)

## Developer installation from source
For developers contributing to PoshGraph or those who wish to test out pre-release features that have not yet been published to PowerShell Gallery, run the following PowerShell commands to clone the repository and then build and install the module on your local system:

```powershell
git clone https://github.com/adamedx/poshgraph
cd poshgraph
.\build\install-fromsource.ps1
```

## Contributing and development

Read about our contribution process in [CONTRIBUTING.md](CONTRIBUTING.md). The project is not quite ready to handle source contributions; suggestions on features or other advice are welcome while we establish a baseline.

See the [Build README](build/README.md) for instructions on building and testing changes to PoshGraph.

## Quickstart
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

License and authors
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

