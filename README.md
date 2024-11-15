# <img src="https://raw.githubusercontent.com/adamedx/autographps/main/assets/PoshGraphIcon.png" width="50"> AutoGraphPS

| [Documentation](https://github.com/adamedx/autographps/blob/main/docs/WALKTHROUGH.md) | [Installation](#Installation) | [Usage](#usage) | [Reference](#reference) | [Contributing and development](#contributing-and-development) |
|-------------|-------------|-------------|-------------|-------------|

[![Build Status](https://adamedx.visualstudio.com/AutoGraphPS/_apis/build/status/AutoGraphPS-CI?branchName=main)](https://adamedx.visualstudio.com/AutoGraphPS/_build/latest?definitionId=5&branchName=main)

**AutoGraphPS** is a PowerShell scripting and automation experience for the [Microsoft Graph API](https://graph.microsoft.io/), a programmable [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer). AutoGraphPS's enhancements to your run-of-the-mill REST UX allow you to:

* Explore the API with an `ls-cd-cat` idiom similar to [HttpRepl](https://github.com/dotnet/HttpRepl)
* Experience the joy of tab-completion and color throughout your Graph journey
* Find Graph APIs (*types*) and permissions by searching for API names / keywords
* Easily find API documentation from your shell
* Build requests with auto-completion and validation for property names and parameters instead of reading documentation
* Detailed success and error logging of Graph API requests with flexible views

If you're an application developer, DevOps engineer, system administrator, or enthusiast power user, AutoGraphPS was made just for you. If you're building Graph-based applications in PowerShell, consider using the lighter-weight [AutoGraphPS-SDK](https://github.com/adamedx/autographps-sdk) which contains a smaller kernel of Graph cmdlets focused on automation and omits the UX affordances found in this module.

If you have ideas on how to improve **AutoGraphPS**, please consider [opening an issue](https://github.com/adamedx/autographps/issues) or a [pull request](https://github.com/adamedx/autographps/pulls).

### System requirements

On the Windows operating system, PowerShell 5.1 and higher are supported. On Linux and MacOS, PowerShell 7.0 and higher are supported.

## Installation

AutoGraphPS is available through the [PowerShell Gallery](https://www.powershellgallery.com/packages/autographps); run the following command to install the latest stable release of AutoGraphPS into your user profile:

```powershell
Install-Module AutoGraphPS -scope currentuser
```

## Usage

Once you've installed the module, you can use an AutoGraphPS cmdlet like `Get-GraphResource` below to test out your installation. You'll need to authenticate using a [Microsoft Account](https://account.microsoft.com/account) or an [Entra ID (fka AAD) account](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-whatis):

```powershell
PS> Get-GraphResource me
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

Now you're ready to use any of AutoGraphPS's cmdlets to access and explore Microsoft Graph! Visit the [WALKTHROUGH](docs/WALKTHROUGH.md) for detailed usage of the cmdlets, or follow along below for a quick tour.

### How do I use it?

As with any PowerShell cmdlet, you can use AutoGraphPS cmdlets interactively or from within simple or even highly complex PowerShell scripts and modules since the cmdlets emit and operate upon PowerShell objects. For help with any of the commands in this module, try the standard `Get-Help` command, e.g. `Get-Help Get-GraphResource`.

AutoGraphPS cmdlets support two equivalent paradigms for accessing Microsoft Graph:

* The **resource-based** paradigm: Because Microsoft Graph is a REST-based API, the entirety of the Graph API surface may be reliably accessed via *Uniform Resource Identifiers (URIs)* as [documented in the Graph API reference](https://docs.microsoft.com/en-us/graph/api/overview?view=graph-rest-1.0). Most commands default to URI as all functionality is accessible through a URI; users with a developer background or general comfort with REST will be comfortable with this paradigm.
* The **type-based** paradigm: Entities modeled by the Graph are grouped into *"types"*, collections of objects with a common set of properties including a unique identifier field called `id`. A type might be the set of users or groups in a tenant, the set of drives, or any other concept you'd like to manage via the Graph API. *If you know the type of an object and its and `id`, and if needed its relationship to other objects, you can use AutoGraphPS commands to manage that object.* This information is usually easy to intuit or memorize and makes for simpler usage and improved readability for scripts, but since not all aspects of the API are expressible via type and `id`, this is not the default paradigm where both are applicable.

#### Access via URI

If you're familiar with the Microsoft Graph REST API or you've used [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer), you know that Graph is accessed via [URI's that look like the following](https://developer.microsoft.com/en-us/graph/docs/concepts/overview#popular-requests):

```
https://graph.microsoft.com/v1.0/me/calendars
https://graph.microsoft.com/v1.0/me/people
https://graph.microsoft.com/v1.0/users
```

With AutoGraphPS cmdlets, you can invoke REST methods from PowerShell and omit the common `https://graph.microsoft.com/v1.0` of the URI as follows:

```powershell
Get-GraphResource me/calendars
Get-GraphResource me/people
Get-GraphResource users
```

These commands retrieve the same data as a `GET` for the full URIs given earlier. Of course, `Get-GraphResource` supports a `-AbsoluteUri` option to allow you to specify that full Uri if you so desire.

For more details or reference material describing the Graph API URIs, visit the [Graph API documentation](https://docs.microsoft.com/en-us/graph/api/overview?toc=./ref/toc.json&view=graph-rest-1.0).

#### Access by type

Top-level objects such as `group` or `user` have an `id`. If you know that `id`, you can get information about the actual object using `Get-GraphItem`:

```powershell
Get-GraphItem user f7e9d7b6-f92f-4a78-8537-6b78d874936e

   Graph Location: /users

Id                                   DisplayName  Job Title UserPrincipalName
--                                   -----------  --------- -----------------
f7e9d7b6-f92f-4a78-8537-6b78d874936e Laquan Smith Directory lsmith@dragon.org


Get-GraphItem group a57f301b-4fc2-4fac-865c-ee4e1af3084d

   Graph Location: /groups

Id                                   DisplayName   MailNickName Enabled for
--                                   -----------   ------------ -----------
a57f301b-4fc2-4fac-865c-ee4e1af3084d Mathmeticians math         Security
```

Note that the header of the output gives the hint that you could construct the URI for that type and id combination by appending the `id` as a segment to the URI given by `Graph Location:`. Since `Get-GraphItem` supports a `Uri` parameter, that URI can be specified rather than the type and id parameters. This is the same URI as that used with `Get-GraphResource`, though the output of the two commands is different:

```powershell
Get-GraphResource /users/f7e9d7b6-f92f-4a78-8537-6b78d874936e

id                : f7e9d7b6-f92f-4a78-8537-6b78d874936e
officeLocation    : 3/1415
@odata.context    : https://graph.microsoft.com/v1.0/$metadata#users/$entity
surname           : Smith
mail              : laquan@newgriot.edu
jobTitle          : Researcher
givenName         : Laquan
userPrincipalName : laquan@newgriot.edu
...
```

Note that the output of `Get-GraphItem` is an object that in addition to the protocol response from Graph contains metadata about the response data such as the name of its type, the URI used to access it, a heuristically generated `Preview` field intended for human browsing, etc. The actual API response data exists in the `Content` field and is identical to that returned by the `Get-GraphResource` command. The `-ContentOnly` parameter for `Get-GraphItem` removes the metadata and returns only the response just as with `Get-GraphResource`, eliminating the need to use `Select-Object` or otherwise filter the response to just the `Content`:

```powershell
# These all have the same output:
Get-GraphItem user f7e9d7b6-f92f-4a78-8537-6b78d874936e | select -ExpandProperty Content
Get-GraphItem -Uri /users/f7e9d7b6-f92f-4a78-8537-6b78d874936e -ContentOnly
Get-GraphResource /users/f7e9d7b6-f92f-4a78-8537-6b78d874936e
```

There is also a related command, `Get-GraphChildItem` that enables the enumeration of multiple objects and relates to `Get-GraphItem` in a fashion similar to the relationship between the standard `Get-ChildItem` and `Get-Item` commands of PowerShell.

### More fun commands

Run the command below to grant permissions that allow AutoGraphPS to read your **mail**, **contacts**, **calendar**, and **OneDrive files**:

```powershell
# You only have to do this once, not each time you use AutoGraphPS
Connect-GraphApi -Permissions User.Read, Mail.Read, Contacts.Read, Calendars.Read, Files.Read
```

Now traverse the Graph via the `gcd` alias to "move" to a new Uri current location in the Graph. This is analgous to the usage of "cd" to change to a new current working directory in file-system oriented shells like `bash` and PowerShell:

```powershell
gcd me
[starchild@mothership.io] /v1.0:/me
PS>
```

Notice the update to your prompt showing your authenticated identity and your new current location after invoking that last cmdlet: `[starchild@mothership.io] /v1.0:/me`. **Tip:** the `gwd` alias acts like `pwd` in the file system and retrieve your current working location in the Graph.

Now you can use the `gls` alias as you would `ls` in the file system relative to your current location. Here's how you can read your email:

```powershell
[starchild@mothership.io] /v1.0:/me
PS> gls messages
```

Here are a few more commands to try -- note that you can also use absolute paths rather than paths relative to the current location
```powershell
# Lists your calendars, assuming you're at /me
gls calendars

# Same thing, uses an absolute path
gls /me/calendars

# Get data about your organizationn
gls /organization

# Get all the paths at the root of the Graph
gls /

```

Finally, here's one to enumerate your OneDrive files
```powershell
[starchild@mothership.io] /v1.0:/me
PS> gcd drive/root/children
[starchild@mothership.io] /v1.0:/me/drive/root/children
PS> gls

   Graph Location: /v1.0:/me/drive/root/children

CreatedBy           LastModifiedDateTime       Size Name
---------           --------------------       ---- ----
cosmo@soulsonic.org 2017-10-24 21:36         612440 Recipes
cosmo@soulsonic.org 2008-12-21 07:51     3411429771 Games
```

#### Don't forget write operations

Yes, you can perform write operations! Commands like `New-GraphItem`, `Set-GraphItem`, and `Remove-GraphItem` allow you to make changes to data in the Graph.

#### Create a new item with New-GraphItem

The `New-GraphItem` command creates new entities in the Graph. The example below creates a new security group:

```powershell
New-GraphItem group -Property mailNickName, displayName, mailEnabled, securityEnabled -Value blackgold, 'Black Gold', $false, $true

description                   :
mailNickname                  : blackgold
@odata.context                : https://graph.microsoft.com/v1.0/$metadata#groups/$entity
createdDateTime               : 2020-07-03T07:00:16Z
displayName                   : Black Gold
...
```

##### Update an item with Set-GraphItem

The `Set-GraphItem` command lets you change the properties of an existing item:

```powershell
$newGroup | Set-GraphItem -Property displayName, description -Value 'Black Gold Team', 'Collaboration for the Black Gold Gala event'
$newGroup | Get-GraphItem -ContentOnly | select displayName, description

displayName     description
-----------     -----------
Black Gold Team Collaboration for the Black Gold Gala event
```

In this case, the `displayName` and `description` properties of the newly created group are updated to new values when `Set-GraphItem` is executed. A subsequent invocation of `Get-GraphItem` to request the current version of the object from Graph reflects the updates made to those properties.

##### New-GraphObject makes write operations easier

In the example above the input required to create the new object, in this case a group, was easy to specify -- just a handful of strings. However for more complicated objects, e.g. nested structures, specifying them on the command-line can be rather convoluted. The `New-GraphObject` command makes it fairly simple to create objects of any type required by the Graph, and of course it provides parameter completion to save you time and the worry that you might have typed a non-existent parameter.

For example, if you know the name of the type of object, say `contact`, and you know the properties you need to set, you can specify that information explicitly. This would result in the straightforward usage below:

```powershell
$emailAddress = New-GraphObject emailAddress -Property name, address -value Work, cleo@soulsonic.org
$contactData = New-GraphObject contact -Property givenName, emailAddresses -value 'Cleopatra Jones', @($emailAddress)
$newContact = $contactData | New-GraphItem -Uri me/contacts
```

##### Clean up with Remove-GraphItem

The `Remove-GraphItem` command deletes an entity from the Graph -- it is the inverse of `New-GraphItem`. It includes a set of parameters that allows for the specifiation of the type and the id of the entity to remove and also provides the option to specify the entity's URI. And if you already have an instance of the object available as we do from the above example, you can just pipe the instance to delete to `Remove-GraphItem`:

```powershell
$newContact | Remove-GraphItem
```

Subsequent attempts to retrieve the entity from the Graph by identifier or URI using commands such as `Get-GraphItem` or `Get-GraphResource` will fail because the entity has been deleted by `Remove-GraphItem`.

##### Invoke-GraphApiRequest handles all the REST

What if you can't find exactly the command you need to interact with the Graph? The `Invoke-GraphApiRequest` is a general-purpose command that, with the right parameters, can emulate any of the other commands that interact with Graph. It is a generic REST client capable of issuing any valid request to the Graph. You can use it if you run into a scenario that isn't covered by the other commmands. In general it may be useful if you're already using REST to interact with the Graph.

Here's one example that issues the same request as in the earlier example for `New-GraphItem':

```powershell
$contactData = @{givenName='Cleopatra Jones';emailAddresses=@(@{name='Work';Address='cleo@soulsonic.org'})}
Invoke-GraphApiRequest -Method POST me/contacts -Body $contactData
```

As its name suggests, the `Method` parameter of `Invoke-GraphApiRequest` lets you specify any **REST** method, i.e. `PUT`, `POST`, `PATCH`, and `DELETE`. Thus `Invoke-GraphApiRequest` is capable of executing any capability of Graph and can be considered *the universal Graph command.* The example given here is less readable than the `New-GraphObject` / `New-GraphItem` example and requires you to know more about the underlying Graph protocol (e.g that creation of data usually means you must use the `POST` method), but it is consistent with the idea that if you can't find the command you need, you can always find a way to get things working with `Invoke-GraphApiRequest`, even if it trades off simplicity.

Note that the `Body` parameter allows you to specify the JSON body of the request which typically describes the information to write. In the example above, rather than specify the JSON directly, we chose to express it as a PowerShell `HashTable` object. When the `Body` parameter is not a JSON string, `Invoke-GraphApiRequest` converts whatever type you specify to JSON for you. The way the `HashTable` was structured in this example allowed it to be serialized into exactly the JSON format required to `POST` a `contact` object to `/me/contacts` as a well-formed request.

#### So how do I find all the URIs and JSON for Graph?

In the examples above, specific URIs were featured to explain how common uses of the Graph API are surfaced in AutoGraphPS. But in general how does one discover which URIs implement which functionality? And particularly for write requests, what is the required structure for the JSON body?

In general, this information may be found in the [Graph documentation](https://docs.microsoft.com/en-us/graph/?view=graph-rest-1.0). The [reference section](https://docs.microsoft.com/en-us/graph/api/overview?toc=./ref/toc.json&view=graph-rest-1.0) in particular is organized around *resources* such as `user`, `group`, `message`, `contact`, `driveItem`, `profilePhoto`, .etc, which model the surface of what can be managed with Graph. These resources are named after concepts that are likely familiar and accessible to you; you can learn browse through the reference and related documentation with these concepts as a guide to finding the resource, and thus its documented URI, that corresponds to the capability you'd like to exercise.

In the spirit of documentation, AutoGraphPS includes the `Show-GraphHelp` command that provides a shortcut to the documentation. Just specify the name of a resource, such as `user`, and it will launch a web browser to that landing page:

```powershell
Show-GraphHelp user
```

This command above shows help for user for the `v1.0` API version. To see help for the `beta` version, you can use

```powershell
Show-GraphHelp user -version beta
```

`Show-GraphHelp` launches the system's default web browser to display documentation. If you'd like to use a different web browser, or if AutoGraphPS is running in a browser-free environment, `ShowGraph-Help` can output the URI instead of starting a browser. Specify the `ShowHelpUri` parameter to obtain this URI:

```powershell
Show-GraphHelp user -ShowHelpUri
https://developer.microsoft.com/en-us/graph/docs/api-reference/v1.0/resources/user
```

#### AutoGraphPS tips
Here are a few simple tips to keep in mind as you first start using AutoGraphPS:

**1. Permissions matter:** AutoGraphPS can only access parts of the Graph for which you (or your organization's administrator) have given consent. Use the `Connnect-Graph` cmdlet to request additional permissions for AutoGraphPS, particularly if you run into authorization errors. Also, consult the [Graph permissions documentation](https://docs.microsoft.com/en-us/graph/permissions-reference) to understand what permissions are required for particular subsets of the Graph. Note that if you're using an Entra ID (formerly known as Azure Active Directory) account to access the Graph, you may need your organization's administrator to consent to the permissions on your behalf in order to grant them to AutoGraphPS.

**2. Use tab-completion to learn and save time:** Many AutoGraphPS commands, including `Get-GraphResource`, `gls`, and `gcd` will tab-complete command parameters just like many other popular PowerShell commands do. URIs, resource names, and permission names are just some of the kinds of parameters that AutoGraphPS will tab-complete for you to reduce the time needed to issue a command and also clue you in on when you're potentially providing invalid input.

**3. Use commands like `gcd` and `gls` to explore the Graph!** In addition to browsing Graph documentation to find out how to use Graph APIs, you can use AutoGraphPS to browse the Graph itself. Try executing the command `gls`, and then performing a `gcd` to one of the items of the output. Invoking another `gls` may show you additional destinations to which you can `gcd`. And auto-complete is there to auto-complete URIs and minimize user input labor. By using AutoGraphPS commands in this way, you can explore the API surface of the Graph in the way you'd explore your local file system with commands like `cd` and `ls`.

**4. You can access the Beta version of the Graph API**: By default, AutoGraphPS is targeted at the default API version of Graph, `v1.0`. It also works with the `beta` version -- many commands provide a `-Version` parameter for which you can supply the value `beta` to run that command against the `beta` API version. You can tell AutoGraphPS to use `beta` for all commands by "mounting" the `beta` version. Below we mount `beta`  and set the current location to its root:

```powershell
# You could also issue the command 'new-graph beta' to mount beta explicitly
gcd /beta: # This sets the current location and implicitly mounts the 'beta' API version
```

And that brings us to this **Warning**: *AutoGraphPS takes some time to get fully ready for each API version.* When you first execute commands like `gls` and `gcd`,, some information about the structure of the Graph may be incomplete. In these cases you should see a "warning" message. You can also Use the `gg` alias to see the status of your mounted API versions, i.e. `Ready`, `Pending`, etc., which can take a few minutes to reach the desired `Ready` state. Eventually the warning will no longer occur and the cmdlets will return full information after the background metadata processing completes.

For a much more detailed description of AutoGraphPS's usage and capabilities, including advanced query and authentication features, see the [WALKTHROUGH](docs/WALKTHROUGH.md).

## Common uses

AutoGraphPS is your PowerShell interface to the Microsoft Graph REST API. In what contexts is such a tool useful? Here are several:

* **Developer - Graph education:** The Microsoft Graph is aimed at developers, and just as Graph Explorer helps developers learn how to make API calls to the Graph and debug them, AutoGraphPS offers the same capability, with the added benefit of the CLI's speed and automation
* **Developer - testing and debugging:** AutoGraphPS makes it trivial to reproduce errors you encounter in your application's REST calls to the Graph -- simply use the same credentials, REST method, and Uri in one of the Graph cmdlets, and you can obtain diagnostics without rebuilding your application or otherwise altering it to isolate failure cases and add debugging information. AutoGraphPS is also useful for pursuing ad hoc "what if"-style investigations of Graph functionality that is new to you or understanding Graph's corner cases without building a new application.
* **System administration:** Sysadmins manage the same services such as Entra ID, Exchange, and SharePoint that are exposed by the Microsoft Graph. Sysadmins are also heavy users of PowerShell. AutoGraphPS allows administrators to author PowerShell automation that takes full advantage of the management capabilities constantly being added to Microsoft Graph. Your existing PowerShell automation can be enhanced with AutoGraphPS or included in new tools based on it.
* **Developer - management tools:** Configuration management and system administration tools are popular output for developers, particularly in OSS communities. AutoGraphPS offers developers building PowerShell-based configuration management tools for their users a key library that solves authentication, modeling, querying, and deserialization. Graph calls with AutoGraphPS are typically one-liners requiring little in the way of setup, a quality that enhances your productivity as a developer.
* **Enthusiast / power user:** Users who enjoy learning about what powers their software will find AutoGraphPS a great way to not only learn about Graph, but exploit its capabilities to do things such as advanced e-mail or photo management through Exchange and OneDrive, implement their own backup features with OneDrive and SharePoint, or simply automate common tasks.

There are probably many more uses for AutoGraphPS, as wide-ranging as the Graph itself.

## Configuration and preferences

The module allows for customization through conventional PowerShell preference variables as a configuration file. In general, when a behavior may be specified by both a preference variable and a setting from the configuration file, the preference variable behavior takes precedence, making it easy to change a behavior at runtime without redefining profiles.

### Preference variables

The following preference variables are defined by the module:

* `GraphAutoPromptPreference`: specifies whether the PowerShell prompt should be automatically updated by the module to reflect information about the current Graph location as seen by `Get-GraphLocation`. Set this to one of the valid values of `Behavior` parameter of `Set-GraphPrompt`
* `GraphMetadataPreference`: determines whether commands that require Graph API metadata must wait for metadata to be retrieved and processed before attempting to execute the command. The value `Wait` causes the command to wait for processing to complete and notifies the user that the command is waiting. This is the default value. `Silently` wait has the same behavior except the user is given no notification. The `Ignore` value causes the command to proceed with execution even if there is no updated metadata, which may cause it to fail.
* `GraphPromptColorPreference`: specifies the color of the text added to the PowerShell prompt by the module. Valid values can be any color value used in commands like `Write-Host` which expose parameters like `ForeGroundColor` conform to the same set of color values.

### Settings file

AutoGraphPS supports the use of a local settings configuration file at the location `~/.autographps/settings.json`. The format and behavior of the settings file is described in the [AutoGraphPS settings documentation](https://github.com/adamedx/autographps-sdk/blob/main/docs/settings/README.md).

This particular module implements the following settings **in addition to those supported by AutoGraphPS-SDK**:

* `PromptBehavior`: This setting has the same allowed values and associated semantics as the `GraphAutoPromptPreference` preference variable
* `PromptColor`: This setting has the same allowed values and associated semantics as the `GraphPromptColorPreference` preference variable

The full list of configurable settings is described by the [AutoGraphPS settings documentation](https://github.com/adamedx/autographps-sdk/blob/main/docs/settings/README.md).

## Command reference

The full list of cmdlets is given below; they go well beyond simply reading information from the Graph. As this library is in the early stages of development, that list is likely to evolve significantly along with their usage. Additional documentation will be provided for them as their status solidifies.

Note that since AutoGraphPS is built on [AutoGraphPS-SDK](https://github.com/adamedx/autographps-sdk), this list includes cmdlets from AutoGraphPS-SDK as well. If you are building a Graph-based application in PowerShell, consider taking a dependency on AutoGraphPS-SDK rather than AutoGraphPS if its subset of cmdlets suits your use case.

| Cmdlet (alias)            | Description                                                                                             |
|---------------------------|---------------------------------------------------------------------------------------------------------|
| Add-GraphRelatedItem      | Creates a new resource to an existing resource using a relationship property of the existing resource -- this can be used to create a new and it to an existing group through the group's `member` relationship for instance |
| Clear-GraphLog            | Clear the log of REST requests to Graph made by the module's commands                                   |
| Connect-GraphApi (conga)  | Establishes authentication and authorization context used across cmdlets for the current graph          |
| Disconnect-GraphApi       | Clears authentication and authorization context used across cmdlets for the current graph               |
| Find-GraphLocalCertificate  | Gets a list of local certificates created by AutoGraphPS-SDK to for app-only or confidential delegated auth to Graph |
| Find-GraphPermission     | Given a search string, `Find-GraphPermissions` lists permissions with names that contain that string    |
| Find-GraphType            | Given simple search terms returns a set of types relevant to those terms sorted by relevance            |
| Format-GraphLog (fgl)       | Emits the Graph request log to the console in a manner optimized for understanding Graph and troubleshooting requests |
| Get-Graph (gg)            | Gets the current list of versioned Graph service endpoints available to AtuoGraphPS                     |
| Get-GraphApplication              | Gets a list of Azure AD applications in the tenant                                              |
| Get-GraphApplicationCertificate   | Gets the certificates with public keys configured on the application                            |
| Get-GraphApplicationConsent       | Gets the list of the tenant's consent grants (entries granting an app access to capabilities of users)     |
| Get-GraphApplicationServicePrincipal | Gets the service principal for the application in the tenant                                 |
| Get-GraphChildItem (ggci) | Retrieves in tabular format the list of entities for a given Uri AND child segments of the Uri          |
| Get-GraphConnection (gcon)           | Gets information about all named connections and the current connection                      |
| Get-GraphCurrentConnection (gcur) | Gets information about a connection to a Graph endpoint, including identity and  `Online` or `Offline` |
| Get-GraphError (gge)      | Retrieves detailed errors returned from Graph in execution of the last command                          |
| Get-GraphItem (ggi)       | Retrieves an entity specified by type and ID or URI |
| Get-GraphItemRelationship (ggrel) | Retrieves a specified subset of relationships from the specified item                           |
| Get-GraphLastOutput (glo) | Retrieves the last output returned from commands like `gls` and associates them with an index           |
| Get-GraphLocation (gwd)   | Retrieves the current location in the Uri hierarchy for the current graph                               |
| Get-GraphLog (ggl)        | Gets the local log of all requests to Graph made by this module                                         |
| Get-GraphLastOutput       | Gets the value or indexed elmeent of the `$LASTGRAPHITEMS` variable, i.e. the objects returned by the previous invocation of commands like Get-GraphResource or Get-GraphResourceWithMetadata and associates them with an index that can be used with commansd like `Set-GraphLocation` |
| Get-GraphLogOption        | Gets the configuration options for logging of requests to Graph including options that control the detail level of the data logged |
| Get-GraphMember (ggm)     | Gets information about the members of a Graph object's given type or an explicitly specified type, similar to the standard PowerShell Get-Member command |
| Get-GraphMethod (ggmt)    | Gets information about the methods of a Graph object's given type or an explicitly specified type, similar to the standard PowerShell Get-Member command |
| Get-GraphProfile                     | Gets the list of profiles defined in the [settings file](https://github.com/adamedx/autographps-sdk/blob/main/docs/settings/README.md) -- these profiles may be enabled by the `Select-GraphProfileSettings` command. |
| Get-GraphRelatedItem (gri)| Gets the items related to a specified item through a specified relationship                             |
| Get-GraphResource (ggr)   | Given a relative (to the Graph or current location) Uri gets information about the entity               |
| Get-GraphResourceWithMetadata (gls) | Retrieves in tabular format the list of entities and metadata for a given Uri                 |
| Get-GraphAccessToken      | Gets an access token for the Graph -- helpful in using other tools such as [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)  |
| Get-GraphType             | Gets metadata for the specified resource type as documented in the [Graph reference](https://developer.microsoft.com/en-us/graph/docs/concepts/v1-overview)         |
| Get-GraphUri (guri)       | Gets the graph URI for the specified type and an optional object identifier                             |
| Get-GraphUriInfo (ggu)    | Gets detailed metadata about the segments of a Graph Uri or child segments of the Uri                   |
| Invoke-GraphApiRequest    | Executes a REST method (e.g. `GET`, `PUT`, `POST`, `DELETE`, etc.) for a Graph Uri                      |
| Invoke-GraphMethod        | Executes a method on a given Graph object specified by Type and Id or URI                               |
| Measure-Graph             | Returns statistics about the types exposed by the Graph API                                             |
| New-Graph                 | Mounts a new Graph connection and associated metadata for availability to AutoGraphPS cmdlets           |
| New-GraphApplication      | Creates an Azure AD application configured to authenticate to Microsoft Graph                           |
| New-GraphApplicationCertificate | Creates a new certificate in the local certificate store and configures its public key on an application |
| New-GraphConnection       | Creates an authenticated connection using advanced identity customizations for accessing a Graph        |
| New-GraphItem     | Creates an instance of the specified entity type in the Graph given a set of properties |
| New-GraphItemRelationship | Links a target resource to a source resource using the specified relationship property of the source -- this can be used to add a user to a group through the group's `member` relationship for instance |
| New-GraphLocalCertificate | Creates a certificate in the local device's certificate store that may be used as a credential for the specified application |
| New-GraphMethodParameter  | Creates a local representation of a Graph type for the specified parameter of a specified Graph method  |
| New-GraphObject           | Creates a local representation of a type defined by the Graph API that can be specified in the body of write requests in commands such as `Invoke-GraphApiRequest` |
| Register-GraphApplication | Creates a registration in the tenant for an existing Azure AD application    |
| Remove-Graph              | Unmounts a Graph previously mounted by `NewGraph`                                                       |
| Remove-GraphApplication   | Deletes an Azure AD application                                                                         |
| Remove-GraphApplicationCertificate | Removes a public key from the application for a certificate allowed to authenticate as that application |
| Remove-GraphApplicationConsent | Removes consent grants for an Azure AD application                                                 |
| Remove-GraphConnection    | Removes a named graph connection                                                                        |
| Remove-GraphItem          | Removes an entity specified by type and ID or URI |
| Remove-GraphItemRelationship | Removes the relationship between a source resource and a target resource without modifying the resources themselves |
| Remove-GraphResource      | Makes generic ``DELETE`` requests to a specified Graph URI to delete resources                      |
| Select-GraphConnection (scon) | Sets the named connection used by default for commands in the current Graph                         |
| Select-GraphProfile       | Enables the behaviors mandated by the setting values of the specified profile. Profiles are defined by the user's [settings file](https://github.com/adamedx/autographps-sdk/blob/main/docs/settings/README.md). |
| Set-GraphApplicationCertificate      | Given the specified certificate or certificate path sets the application's certificates                                             |
| Set-GraphApplicationConsent       | Sets a consent grant for an Azure AD application                                                |
| Set-GraphConnectionStatus | Configures `Offline` mode for use with local commands like `GetGraphUri` or re-enables `Online` mode for accessing the Graph service |
| Set-GraphItem     | Updates properties of a given Graph entity with the specified values |
| Set-GraphLocation (gcd)   | Sets the current graph and location in the graph's Uri hierarchy; analog to `cd` / `set-location` cmdlet for PowerShell when working with file systems |
| Set-GraphLogOption        | Sets the configuration options for logging of requests to Graph including options that control the detail level of the data logged |
| Set-GraphPrompt           | Adds connection and location context to the PowerShell prompt or disables it                            |
| Show-GraphHelp            | Given the name of a Graph resource (e.g. 'user', 'group', etc.) launches a web browser focused on documentation for it |
| Test-Graph                | Retrieves unauthenticated diagnostic information from instances of your Graph endpoint                  |
| Test-GraphSettings        | Validates whether AutoGraph settings specified as a file, JSON content, or in deserialized form are valid                                               |
| Unregister-GraphApplication | Removes consent and service principal entries for the application from the tenant                     |
| Update-GraphMetadata      | Downloads the the latest `$metadata` for a Graph and updates local Uri and type information accordingly |

### More about how it works

If you'd like a behind the scenes look at the implementation of AutoGraphPS, see the following article:

* [Microsoft Graph via PowerShell](https://adamedx.github.io/softwarengineering/2018/08/09/Microsoft-Graph-via-PowerShell.html)

## Developer installation from source
For developers contributing to AutoGraphPS or those who wish to test out pre-release features that have not yet been published to PowerShell Gallery, run the following PowerShell commands to clone the repository and then build and install the module on your local system:

```powershell
git clone https://github.com/adamedx/autographps
cd autographps
.\build\install-fromsource.ps1
```

## Contributing and development

Read about our contribution process in [CONTRIBUTING.md](CONTRIBUTING.md). In addition to submitting pull requests, we also invite bug reports, eature requests, and architectural improvements through this repository's [issues page](https://github.com/adamedx/autographps/issues).

See the [Build README](build/README.md) for instructions on building and testing changes to AutoGraphPS.

## Quickstart
The Quickstart is a way to try out AutoGraphPS without installing the AutoGraphPS module. In the future it will feature an interactive tutorial. Additionally, it is useful for developers to quickly test out changes without modifying the state of the operating system or user profile. Just follow these steps on your workstation to start **AutoGraphPS**:

* [Download](https://github.com/adamedx/autographps/archive/main.zip) and extract the zip file for this repository **OR** clone it with the following command:

  `git clone https://github.com/adamedx/autographps`

* Within a **PowerShell** terminal, `cd` to the extracted or cloned directory
* Execute the command for **QuickStart**:

  `.\build\quickstart.ps1`

This will download dependencies, build the AutoGraphPS module, and launch a new PowerShell console with the module imported. You can execute a AutoGraphPS cmdlet like the following in the console -- try it:

  `Test-Graph`

This should return something like the following:

```powershell
TestUri                : https://graph.microsoft.com/v1.0/$metadata
ServerTimestamp        : 10/14/2021 04:01:45 +00:00
ClientElapsedTime (ms) : 15.6793
RequestId              : 74745fab-7184-46f0-b577-3549ee054115
DataCenter             : West US 2
Ring                   : 1
RoleInstance           : CO1PEPF000007E4
ScaleUnit              : 000
Slice                  : E
NonfatalStatus         : 405
```

If you need to launch another console with AutoGraphPS, you can run the faster command below which skips the build step since QuickStart already did that for you (though it's ok to run QuickStart again):

    .\build\import-devmodule.ps1

These commmands can also be used when testing modifications you make to AutoGraphPS, and also give you an isolated environment in which to test and develop applications and tools that depend on AutoGraphPS.

License and authors
-------------------
Copyright:: Copyright (c) 2024 Adam Edwards

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


