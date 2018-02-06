PoshGraph
=========
PoshGraph is a PowerShell-based CLI for exploring the [Microsoft Graph](https://graph.microsoft.io/) and the [Azure Active Directory Graph](https://msdn.microsoft.com/Library/Azure/Ad/Graph/howto/azure-ad-graph-api-operations-overview).

The project is in the earliest stages of development and almost but not quite yet ready for collaborators.

## Prerequisites
**PoshGraph** requires the following:
* A **Windows 10** operating system or later
* The [NuGet](https://nuget.org) command-line tools, which can be installed [here](https://dist.nuget.org/win-x86-commandline/latest/nuget.exe).
* (Optional): [Git command-line tools](https://git-for-windows.github.io/) to clone this repository locally

## Quickstart -- try it now!
Follow these steps on your workstation to start **PoshGraph**:

* [Download](https://github.com/adamedx/poshgraph/archive/master.zip) and extract the zip file for this repository **OR** clone it with the following command:

  `git clone https://github.com/adamedx/poshgraph`

* Within a **PowerShell** terminal, `cd` to the extracted or cloned directory
* Execute the install command:

  `.\build\quickstart.ps1`

This will download dependencies, build the PoshGraph modiule, and launch a new PowerShell console with the module imported. You can execute a PoshGraph command like the following in the console -- try it:

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

See the section **Building PoshGraph** for additional ways to install the module.

## Usage
After you've installed the module, use **PoshGraph** from any PowerShell session.

### Get connected

**PoshGraph** cmdlets allow you to explore the graph. Before using such cmdlets, you must obtain a connection to the graph of your choice. For example, to get an implicit connection to the [Microsoft Graph](https://graph.microsoft.io/), use the `Connect-Graph` cmdlet:

```powershell
Connect-Graph
Get-GraphItem me
```

### Explicit connections
The `New-GraphConnection` cmdlet lets you create an explicit connection, including to the Graph endpoints outside of the Public cloud.

```powershell
# If no arguments are specified, New-GraphConnection defaults to
# returning a connection to the MS Graph public cloud endpoint
$msgraphconnection = New-GraphConnection
```

Note that we assign the connection to a variable -- we can use it later with cmdlets that actully access the graph. The cmdlet does not actually "connect" to the graph -- in fact, no authentication is actually performed when this command executes. Instead, authentication will occur the first time this connection is used in a subsequent call to one of the graph access cmdlets.

The `New-GraphConnection` cmdlet supports arguments that specify both the authentication mechanism and the type of Graph (MS Graph or AAD Graph). For example, the previous invocation with no arguments is the equivalent of the following command:

```powershell
$msgraphconnection = New-GraphConnection -Cloud ChinaCloud # connects to MS Graph in the China cloud
```

To get a connection to the [Azure Active Directory Graph](https://msdn.microsoft.com/Library/Azure/Ad/Graph/howto/azure-ad-graph-api-operations-overview), use those same options with arguments that specify AD Graph and Azure Active Directory (AAD) authentication, along with the tenant in which to authenticate, which is required for AAD auth:

```powershell
$adgraphconnection = New-GraphConnection -AADGraph
```

### Explore the graph
The simplest cmdlet for accessing the graph is `Get-GraphItem`. The first time you execute it or any other graph access cmdlet, you'll see an authentication popup that may require you to enter credentials. Subsequent uses of the same connection will proceed without any popups. Here's an example that gets the `me` entity for MS Graph:

```powershell
Connect-Graph
Get-GraphItem me
```

After you respond to authentication popups that result from invoking a command, the `GetGraphItem` cmdlet returns a PowerShell .NET object deserialized from the JSON response returned by MS Graph that describes the `me` entity, i.e. information about the user you authenticated as via the popup. Since `me` is supported through both MS Graph and AAD graph, you can invoke the exact same `GetGraphItem` command and arguments to get AAD Graph's view of `me` for an AAD user:

```powershell
$adgraphconnection = New-GraphConnection -aadgraph
Get-GraphItem me -connection $adgraphconnnection
```

As mentioned earlier, you can use the same connection for multiple commands. In the example below for AAD Graph, both the `me` and the `tenantDetails` entity (note: case matters with entity names) are accessed using the same connection:

```powershell
$msgraphconnection = New-GraphConnection
Get-GraphItem me $adgraphconnection -connection $msgraphconnection
Get-GraphItem users/starchild@mothership.org -connection $msgraphconection
```

The connection may be reused until the token acquired by the initial authentication expires (this typically takes several minutes). You can always execute `New-GraphConnection` or `Connect-Graph` to get a new one if that happens to you. Of course, **PoshGraph** should eventually support some sort of token renewal scheme eventually to avoid manual token renewal...

That's it for now -- there are many more cmdlets to arrive soon!

## Contributing/Development
The project is not yet ready for contributors, but suggestions on features or other advice are welcome while I establish a baseline.

License and Authors
-------------------
Copyright:: Copyright (c) 2017 Adam Edwards

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

