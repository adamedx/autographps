AutoGraphPS Walkthrough
=======================

This walkthrough will expose you to the key capabilities of AutoGraphPS and the Microsoft Graph. It is certainly not exhaustive, but should be enough for you understand how to use AutoGraphPS in your work, where it falls short, and how you might remedy any omissions with your own contributions to the project.

The walkthrough assumes you are familiar with PowerShell and basic usage of the object pipeline, and that you are familiar with REST concepts.

## How to explore with AutoGraphPS
After you've installed the module, invoke AutoGraphPS cmdlets from any PowerShell session.

### Get started -- simple commands

**AutoGraphPS** cmdlets allow you to explore the graph. Before using the cmdlets, you must establish a connection to the graph by signing in. If you have not already done this using `Connect-GraphApi`, that's ok -- any commands that need a connection will request one before communicating with the graph. After that, any subsequent commands will re-use that same connection, so you won't have to sign in again.

Here's a really simple command you can execute -- if it asks you to sign-in, please do so:

```powershell
Get-GraphResource me
```

After you respond to authentication prompts, `Get-GraphResource` returns a PowerShell object representing MS Graph's view of the `me` entity, i.e. the entity that represents your user object:

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

Since the first execution of `Get-GraphResource` establishes a logical "session," you can continue to execute cmdlets without being asked to re-authenticate, e.g. a subsequent invocation like

```powershell
PS> Get-GraphResource organization
```

will not prompt for credentials but immediately return details about your organization:

    id              : fb6df3ba-c5f5-43dd-b108-a921f1a7e759
    businessPhones  : {206 881 8080}
    city            : Seattle
    displayName     : Akana
    postalCode      : 98144
    state           : Washington
    street          : 101 23rd Avenue Suite X

### Expanding your (permission) scope

The commands above are trivial demonstrations of Graph. In particular, they only require the Graph permission known as `User.Read`. More interesting explorations of the Graph require that you request additional [permissions](https://docs.microsoft.com/en-us/graph/permissions-reference) when you connect to the Graph.

Here's how you can request the `Files.Read,` `Mail.Read`, and `Contacts.Read` permissions in addition to `User.Read` -- the additional permissions enable you to access those parts of the Graph for reading information about user files from *OneDrive*, your mail, and your list of personal contacts:

```powershell
Connect-GraphApi User.Read, Files.Read, Mail.Read, Contacts.Read
```

This will prompt you to authenticate again and consent to allow the application to acquire these permissions. Note that it is generally not obvious what permissions are required to access different functionality in the Graph; future updates to AutoGraphPS will attempt to address this. For now, consult the [Graph permissions documentation](https://docs.microsoft.com/en-us/graph/permissions-reference) whenever you're accessing a new part of the Graph.

> Note that there are more than 500 permissions (and counting). If you're not sure which permission you need to request with `Connect-GraphApi`, (i.e. `Files.Read`, `Mail.Read`, etc.), you can use the `Find-GraphPermissions` to find permissions and their descriptions by specifying a search keyword.

Now you can issue commands to read contacts, mail, and files. In addition to the `Get-GraphResource` cmdlet which returns data as a series of flat lists, you can use `Get-GraphResourceWithMetadata` or its alias `gls` to retrieve your personal contacts:

```powershell
PS> Get-GraphResourceWithMetadata me/contacts

Info Type    Preview        Name
---- ----    -------        ----
t +> contact Cosmo Jones    XMKDFX1
t +> contact Akeelah Smith  XMKDFX2
t +> contact John Henry     XMKDFX4
t +> contact Deandre George XMKDFX8
```

The `Preview` column shows data returned from Graph that `Get-GraphResourceWithMetadata` deems to be most human-readable -- in this case, the `displayName` of the `contact` entity.

Items with a `+` in the `Info` field returned by `Get-GraphResourceWithMetadata` contain content. The actual content, i.e. data that would be returned by `Get-GraphResource` is not displayed by default, but you can use the `Select` alias of PowerShell to retrieve the `Content` property of each row. In this way `Get-GraphResourceWithMetadata` returns a superset of the data returned from `Get-GraphResource`. The use of `Get-GraphResource` below

```powershell
Get-GraphResource me/contacts/XMKDFX1
```

which returns the contact with `id` `XMKDFX1` may also be retrieved through the sequence below through `Get-GraphResourceWithMetadata` (alias `gls`) with a `Select` for the `Content` property on the first result:

```powershell
PS> gls me | select -expandproperty content -first 1

@odata.etag          : W/"EQAAABYAAAD5jm8FcN/LSI12IpUPSDUMAADaa2EQ"
id                   : XMKDFX1
createdDateTime      : 2017-01-27T07:33:04Z
lastModifiedDateTime : 2017-01-28T10:12:47Z
categories           : {}
birthday             :
fileAs               : Jones, Cosmo
displayName          : Cosmo Jones
givenName            : Cosmo
...
```

And if you're really just interested in the content, you can just specify `ContentOnly`. This makes `gls` behave like `Get-GraphResource (ggr)`:

```powershell
# Retrieves contacts and the last time they were modified
# Preview and info columns are already there by default
gls me/contacts -ContentOnly
ggr me/contacts
```

#### The `$LASTGRAPHITEMS` variable

As with any PowerShell cmdlet that returns a value, the `Get-GraphResource`, `Get-GraphResourceWithMetadata`, `Get-GraphChildItem` cmdlets can be assigned to a variable for use with other commands or simply to allow you to dump properties of objects and their child objects:

```powershell
$mycontacts = gls me/contacts
```

However, even if you neglect to make such an assignment, the results of the last invoked `Get-*Item` cmdlet is available in the `$LASTGRAPHITEMS` variable:

```powershell
PS> gls me/drive

Info Type      Preview  Name
---- ----      -------  ----
t +> drive     OneDrive drive
n* > driveItem          items
n  > list               list
n  > driveItem          root
n* > driveItem          special

PS> $LASTGRAPHITEMS[0].content.lastModifiedDateTime
2017-06-12T03:12:33Z
```

This makes ad-hoc exploration of the Graph less expensive -- you don't have to query the Graph again with another cmdlet to examine the objects you just recently retrieved. They are available in `$LASTGRAPHITEMS`.

**IMPORTANT NOTE:** The example above illustrates an import aspect behavior of `Get-GraphResourceWithMetadata`:
1. When the Uri argument for the cmdlet references a collection, the result is simply the items in the collection. This is actual data from Graph.
2. But when the Uri references a single entity AND the URI is not empty AND is not the value `.`, only that entity is returned.
3. If the URI references a single entity and is either not specified or is the value `.`, the returned elements are the allowed segments (if any) that can immediately follow the entity in a valid Uri for Graph. This is metadata about Graph that reveals its structure.
4. This contrasts with `Get-GraphResource` which only exhibits the behavior in (1).

Note that `Get-GraphChildItem` is similar to `Get-GraphResourceWithMetadata`, except it does not exhibit the behavior in (2) above, it always exhibits both (1) and (3) at the same time.

This makes the `Get-GraphResourceWithMetadata` / `gls` and `Get-GraphChildItem` commands effective ways to recursively discover the Uris for both Graph data and structure (metadata).

### Explore new locations

You may have noticed that after the first time you invoked `gls`, your PowerShell prompt displayed some additional information:

```powershell
[starchild@mothership.io] /v1.0:/
PS>
```

By default, AutoGraphPS automatically adds this to your path on your first use of the exploration-oriented cmdlets `Get-GraphResourceWithMetadata`, `Get-GraphChildItem` and `Set-GraphLocation` (alias `gcd`). The text in square brackets denotes the user identity with which you've logged in. The next part before the `:` tells you what Graph API version you're using, in this case the default of `v1.0`. The part following this is your *location* within that API version. Any Uris specified to `Get-GraphResourceWithMetadata`, `Get-GraphChildItem`, `Get-GraphResource`, or `Set-GraphLocation` are interpreted as relative to the current location, in very much the same way that file-system oriented shells like `bash` and PowerShell interpret paths specified to commands as relative to the current working directory. In this case, your current location in the Graph is `/`, the root of the graph.

With AutoGraphPS, you can traverse the Graph using `gls` and `gcd` just the way you'd traverse your file system using `ls` to "see" what's in and under the current location and "move" to a new location. Here's an example of exploring the `/drive` entity, i.e. the entity that represents your `OneDrive` files:

```powershell
gcd me/drive/root/children
[starchild@mothership.io] /v1.0:/me/drive/root/children
PS> gls

Info Type      Preview       Name
---- ----      -------       ----
t +> driveItem Recipes       13J3XD#
t +> driveItem Pyramid.js    13J3KD2
t +> driveItem Panther.md    13J3SDJ
t +> driveItem Spacetime     13J3DDF
```

If you'd like to know what's "inside" of Recipes, you can `gcd` and `gls` again:

```powershell
[starchild@mothership.io] /v1.0:/me/drive/root/children
PS> gcd me/drive/root/children/Recipes
[starchild@mothership.io] /v1.0:/me/drive/root/children/Recipes
PS> gls

Info Type             Preview    Name
---- ----             -------    ----
t +> driveItem        Recipes candidates
n* > driveItem                   children
n  > listItem                    listItem
n* > permission                  permissions
n* > thumbnailSet                thumbnails
n* > driveItemVersion            versions
n  > workbook                    workbook

[starchild@mothership.io] /v1.0:/me/drive/root/children/Recipes
PS> gls

Info Type      Preview           Name
---- ----      -------           ----
t +> driveItem SweetPotatePie.md 13K559
t +> driveItem Gumbo.md          13K299

[starchild@mothership.io] /v1.0:/me/drive/root/children/Recipes
PS> gls
```

Note that as in the file system case, you can save yourself a lot of typing of long Uri's by using `gcd` and taking advantage of the ability to use shorter Uri's relative to the current location.

Of course, you can always use absolute Uri's that are independent of your current location, just start the Uri with `/`, e.g.

```powershell
gls /me/contacts
```

which returns the same result regardless of your current location, for which you can also query using `get-graphlocation`, aka `gwd` (like `pwd` in the file system):

```powershell
gwd

Path
----
/v1.0:/me/drive/root/children/candidates/children
```

## Query capabilities

The Microsoft Graph supports a rich set of query capabilities through its [OData](https://www.odata.org) support. You can learn the the specifics of MS Graph and OData query specification as part of MS Graph REST Uri's via [Graph's query documentation](https://developer.microsoft.com/en-us/graph/docs/concepts/query_parameters), the [OData query tutorial](http://www.odata.org/getting-started/basic-tutorial/#queryData), or simply by using the [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer).

AutoGraphPS's query capabilities are exposed in the `Get-GraphResource` `Get-GetGraphItemWithMetadata` (`ggr` and `gls` aliases respectively), and `Get-GraphChildItem` commands. To use them, you don't need to construct query Uri's as you might if you were making direct use of OData. And in most cases you will not need to know very much about OData.

### Filtering data with `-Filter`

The one area of AutoGraphPS usage in which it is helpful to understand OData is the filtering language. The `-Filter` option on `Get-GraphResource` and `Get-GraphChildItem` allows you to specify an OData query to limit the result set from Graph to items that satisfy certain conditions much like a SQL `where` clause. The query is performed by the Graph service, so your network and AutoGraphPS don't have to waste time processing results that don't match the criteria you specified:

```powershell
gls me/people -Filter "department eq 'Ministry of Funk'"
```

In the example above we've retrieved all people related to `me` whose `department` property is equal to `Ministry of Funk`. Note that single quotes are used to delimit strings in the OData query syntax, and `eq` is an equality operator. OData supports many other operators, including mathematical and logical operators as well as additional operators related to strings, such as `startsWith`:


```powershell
gls /users -Filter "startsWith(mail, 'pfunk')"
```

This example returns all the users whose `mail` property (i.e. their e-mail address) starts with `pfunk`.

Complex expressions combining multiple operators using logical operators like `and`, `or`, and `not` allow for far more complicated queries involving multiple predicates. For more details on OData filter queries, consult [Microsoft Graph documentation for `$filter`](https://developer.microsoft.com/en-us/graph/docs/concepts/query_parameters#filter-parameter).

### Limiting enumerations with `-First` and `-Skip`

Another way to avoid excessive traffic between AutoGraphPS and Graph is to use the `-First` and `-Skip` options, which are [PowerShell standard parameters for paging](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute?view=powershell-6#supportspaging). These options are implemented as analogs to the `$top` and `$skip` options in OData syntax. For example:

```powershell
gls me/contacts -first 3
```

returns the first 3 items in your contacts list.

Note that by default Graph will limit the number of results returned even when you don't specify `-first` to avoid performance issues with the service. If you have 200 contacts and would like to retrieve them all with one command, you'll need to specify `-first` to get them as Graph currently defaults to returning only 10 at a time:

```powershell
# If I have ~200 contacts, this ensures I get them all :)
gls me/contacts -first 1000
```

You can also skip ahead -- perhaps you want the last elements of a sorted collection or you've already read some number of previous items:

```powershell
gls me/contacts -skip 3 -first 3
```

### Projecting fields with `-Property`

By default, Graph does not return all properties of an object -- it returns those deemed most likely to be useful without retrieving every field to avoid excessive network traffic. For example, the query below for a given user is missing the `department` property in the response:

```powershell
ggr /users/starchild@mothership.io

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
```

To fix this, use `-Property` to project the exact set of fields you're interested in. This has the benefit of allowing you to reduce network consumption as well, which is most useful when handling large result sets:

```powershell
ggr me -property displayName, department, mail, officeLocation

@odata.context : https://graph.microsoft.com/v1.0/$metadata#users(displayName,department,mail,officeLocation)
                 /$entity
department     : Ministry of Funk
displayName    : Starchild Okorafor
officeLocation : 7/3191
mail           : starchild@mothership.io
```

For a better understanding of how and when OData services like Graph can project properties, see the [Microsoft Graph documentation for `$select`](https://developer.microsoft.com/en-us/graph/docs/concepts/query_parameters#select-parameter).

### Sorting with `-Sort` and `-Descending`

Particularly when retrieving large result sets, it is important to be able to specify the order in which items are returned. For an e-mail inbox with 1000 messages for instance, you may only want to retreive the first 50 or so after sorting by descending date (the most recent messages). In other cases you may want to sort on multiple fields.

The following example uses the `-Sort` option to retrieve the 10 oldest messages -- note that we use PowerShell's client-side select cmdlet to limit the displayed fields:

```powershell
ggr /me/messages -first 10 -Sort receivedDateTime | select ReceivedDateTime, Importance, Subject
```

However, to retrieve the 10 newest high-importance items, you should specify the `-Descending` option, which means that all fields specified through `OrderBy` will have a descending order by default:

```powershell
ggr /me/messages -first 10 -Sort receivedDateTime, importance -Descending | select ReceivedDateTime, Importance, Subject
```

What if you want to sort using ascending order for one field, and descending for another? You can specify a PowerShell `HashTable` to identify sort directions for specific fields. This lets you find the oldest high-importance items:

```powershell
ggr /me/messages -first 10 -Sort @{receivedDateTime=$false;importance=$true} | select ReceivedDateTime, Importance, Subject
```

The `$false` assignment in the hash table means that the field will use *ascending* sort order, and `$true` means *descending* order.

### Beyond read-only -- writing the Graph

AutoGraphPS isn't just an excellent browsing experience, it features commands for modifying the Graph as well:

* `New-GraphItem`
* `Set-GraphItem`
* `New-GraphObject`
* `New-GraphItemRelationship`
* `Remove-GraphItem`

The following examples demonstrate common usage of these commands in creating and editing Graph resources. Unlike the read-only cases we've explored so far, you're likely to need some light research before jumping in with these command, i.e. you might want to read the actual Graph API documentation first. In particular, you'll need to have some basic answers in mind for the following questions before using write-operation commands:

* When creating a resource
  * What is the name of the resource you want to create / modify? E.g. `user`, `group`, `message`, etc.
  * Alternatively do you know the resource's parent URI, e.g. `users` for `user`, `me/contacts` for `contact`, etc.
  * What properties of the resource are **required** and must be set at creation time? You can find this information in the searchable / browseable Graph API reference; you can use the `Show-GraphHelp` command to quickly access the documentation for a resource if you know its name (e.g. `Show-GraphHelp contact`).
  * What are the other (non-required) properties you'd like to configure? The commands will automatically complete the property name parameters if you've already specified the resource name or URI to help you find them. You can also use `Get-GraphType <resourcename> -Members` to get a list of the property names and their data types.
* When modifying an existing resource
  * As in create, what is the name of the resource you want to modify?
  * And alternatively, what is the resource's URI, e.g. `users/user@domain.com` for a user, `me/contacts/<contactid>` for a contact
  * What are the names of the properties you want to modify and what are their types? Just like the create use case, parameter completion, `Get-GraphType -Members` and `Show-GraphHElp` to find out.

With this information, you can use a single command to create or update the resource -- just supply it with

* For create: resource name and required property values **OR** parent URI and required property values
* For modify: resource name and ID and the property values to update **OR** resource URI and the property values

Lastly, while in many cases the property values are simple "primitive" types like strings and integers that can be easily expressed as command parameters, they may also themselves be nested "complex" data structures that contain their own properties. If you've obtained the type name of that property from the documentation (remember `Show-GraphHelp`) or `Get-GraphType`, you can specify that name to the `New-GraphObject` command with the `TypeClass Complex` parameter, i.e.:

```powershell
# This command also lets you specify properties -- if you don't, it creates
# an object with empty values for all top-level properties
$ipRange = New-GraphObject ipv6Range
```

You can then set the properties of the `$ipRange` variable as desired, and specify that variable as one of the property values to `New-GraphItem` or `Set-GraphItem`.

Now this preamble may seem rather lengthy compared to our near zero-knowledge approach of read-only use cases, but all of this really boils down to the need to know what you're going to change before you make an update, which isn't unreasonable for these more "dangerous" write use-cases. Fortunately, the answers to all of those questions are a few tab-completions or `Get-GraphType` / `Show-GraphHelp` invocations away.

Now let's see concrete examples of these commands in action.

#### The prerequisite: get write access

Our earlier examples were read-only operations. For write-operations to succeed, you'll need to request specific write permissions, so execute this command before you try the examples:

```powershell
Connect-GraphApi User.ReadWrite.All, Group.ReadWrite.All, Contacts.ReadWrite
```

A few notes are in order:

* As long as you sign in with the same account used to execute the command above, you'll only need to run it *once* -- even if you start a new PowerShell session and sign in without executing that command, AAD will continue to grant those permissions to AutoGraphPS until you take an explicit action to revoke your consent to those permissions.
* These write permissions are typically not available to ordinary users in an AAD tenant; for the AAD-only scenarios, you'll need to be highly-privileged. If this isn't the case for you in your standard usage, you should use an alternate tenant, potentially one acquired through a developer program or trial Azure subscription.

#### Create a simple resource: group (AAD accounts only)

This example uses the `New-GraphItem` command to creates a new AAD security group:

```powershell
PS> $newGroup = New-GraphItem group -Property mailNickName, displayName, mailEnabled, securityEnabled -Value Group7Access, 'Group 7 Access', $false, $true
```

The example specifies the following parameters for `New-GraphItem`:
* The first (unnamed) parameter `group` specifies that the type of the resource to create is `group`
* The `Property` parameter specifies the properties that must be set for the new resource
* The `Value` parameter specifies the values to which those properties must be set

Note that the choice of properties to specify was not arbitrary; the [Graph documentation for the user resource](https://docs.microsoft.com/en-us/graph/api/user-post-users?view=graph-rest-1.0&tabs=http) states that for our use case the `mailNickName`, `displayName`, `mailEnabled`, and `securityEnabled` properties are mandatory. Additional properties may also be specified so that the resulting resource object has those properties configured to desired values, but the properties given in this example are the minimum set required for the `user` resource.

When the command is issued, a request is made to Graph to create the security group, and Graph returns the serialized representation of the Group, the same representation that would be returned if that group were retrieved from Graph through `Get-GraphResource`.

Since the value was assigned to the variable `$newGroup`, it can be used in subsequent script operations, or as in the remainder of this example, inspected simply by evaluating it:

```powershell
PS> $newGroup | select createdDateTime, displayName, mailNickname

createdDateTime      displayName    mailNickname
---------------      -----------    ------------
2020-04-22T01:27:41Z Group 7 Access Group7Access
```

The example specifies the following parameters for `New-GraphItem`:
* The first (unnamed) parameter `group` specifies that the type of the resource to create is `group`
* The `Property` parameter specifies the properties that must be set for the new resource
* The `Value` parameter specifies the values to which those properties must be set

Additionally, following the invocation of `New-GraphItem` that creates the new security group, the example assigns the result of the creation to the variable `$newGroup`, and then outputs 3 columns of the variable to the console for inspection.

#### Create a resource with nested data: user

Creating a group was easy. Let's create a user. Before doing so, a quick consultation of the user resource's documentation via `Show-GraphHelp user` indicates that we need to specify the following properties at creation time: `mailNickName`, `userPrincipalName`, `displayName`, `accountEnabled`, and `passwordProfile`. The first four are simple types (`string`, `string`, `string`, and `bool` respectively) that we know how to specify via command line arguments, but according to the documentation (and also `Get-GraphType user`), the last is of type `passswordProfile`, how do we specify that?

We can use the `New-GraphObject` command to create the data structures as PowerShell objects (or optionally as `JSON` text). `New-GraphObject` does not issue requests or otherwise interact with Graph, but the local objects it creates can be can be specified to commands like `New-GraphItem`, `Set-GraphItem`, etc., that must submit such objects in requests. The parameters of `New-GraphObject` have similar naming and semantics to thsoe of `New-GraphItem` when it comes to types and properties, so after consulting the documentation for `passwordProfile` we see that we can create the `passwordProfile` object with this command:

```powershell
$passwordProfile = New-GraphObject passwordprofile -Property forceChangePasswordNextSignIn, password -value $true, (Get-Credential user).GetNetworkCredential().Password
```

Note that we could have directly specified the password property value via the `Value` parameter, but we chose to use `Get-Credential` which provides an interactive UX for you to type the password. This approach prevents anyone nearby from seeing the password and also keeps it out of your PowerShell command history (however, it *is* now unencrypted in memory because it must be passed this way to Graph, hence care must be taken when configuring symmetric keys like this via Graph -- certificates are a much safer form of credential for instance).

Now we're ready to actually make the request to Graph that creates the user:

```powershell
# This assumes you set `$passwordProfile` using the earlier `New-GraphObject` example
$newUser = New-GraphItem user -Property mailNickname, userPrincipalName, displayname, accountEnabled, passwordProfile -Value treejack, treejack@newnoir.org, 'Treemonisha Jackson', $true, $passwordProfile
```

We can see that the user has been successfully created by issuing a request to the Graph to get the new user using a command like the following:

```powershell
PS> Get-GraphItem user $newUser.Id

   Graph Location: /users

Info Type Preview             Id
---- ---- -------             --
t +> user Treemonisha Jackson 8618a75d-a209-44f3-b2f8-2423cb211eed
```

#### Create a resource with nested data: contact

In this example, a new `contact` (i.e. e-mail or phone contact; requires either a free Microsoft account or non-trial AAD subscription) for the signed-in user is created. Here's a first attempt:

```powershell
PS> $newContact = New-GraphItem contact

foreach : Exception calling "InvokeMethod" with "2" argument(s): "Unable to find URI for type 'contact' -- explicitly specify the target URI and retry."
```

Unfortunately, that didn't work. The exception and resulting error message indicating we should *specify the target URI and retry* means that `New-GraphItem` could not translate our request to create a contact to a REST URI for Graph. Unlike the user case, there is no well-known request URI at which to create a contact (for `user` it is a URI like `https://graph.microsoft.com/v1.0/users`) because *`contact` is the type of object that exists only in relation to another object, not as a standalone instance*.

Actually reviewing the REST documentation for contact shows that the use case for creating a contact is accomplished via `POST` to the resource URI `https://graph.microsoft.com/v1.0/me/contacts`. Conveniently, `New-GraphItem` supports a `Uri` parameter that allows you to specify the URI (`me` since AutoGraphPS commands abstract the earlier parts of the URI), so after searching for additional documentation about `contact` and experimenting to make up for the fact that as of this writing the documentation lacks details about which properties are required at creation time, we can execute the following commands to create a `contact`:

```powershell
# Create the emailAddress object that is required at creation time as an array
$emailAddress = New-GraphObject emailAddress -Property name, address -Value Work, cleo@soulsonic.org
$newContact = New-GraphItem -uri /me/contacts -Property givenName, emailAddresses -Value 'Cleopatra Jones', @($emailAddress)

# Dump the returned item to the console
PS> $newContact | select createdDateTime, displayname, emailAddresses

createdDateTime      displayName     emailAddresses
---------------      -----------     --------------
2020-04-22T04:20:11Z Cleopatra Jones @{name=Work; address=cleo@soulsonic.org}
```

You can confirm that it really exists in the Graph by invoking a command such as

```powershell
Get-GraphResource -Uri /me/contacts | where displayName -eq $newContact.displayName
```

which will issue a request to Graph to retrieve all contacts, and then filter the results with `where` to find the new contact by its display name and output it.

#### Update an existing resource: contact, group, and user

To modify an existing Graph resource, use the `Set-GraphItem` command. You can pipe in the result of a previous `Get-GraphItem`, `Get-GraphResource`, `New-GraphItem`, etc., invocation as the object to modify:

```powershell
$newGroup | Set-GraphItem -Property displayName, description -Value 'Group 7 Access Level', 'All users with Group 7 access'
```

This changes the group's display name to *Group 7 Access Level* and updates the description as well. This example takes the object to modify from the pipeline. Since this command has analogs of parameters from `New-GraphItem` and `New-GraphObject`, you can also specify commands using the following syntax:

```powershell
Set-GraphItem group $newGroup.Id -Property displayName, description -Value 'Group 7 Access Level', 'All users with Group 7 access'
```

And there are still more equivalent syntaxes, using the `PropertyTable` or `TemplateObject` parameters. `PropertyTable` is just a more concise way to specify the `Property` and `Value` parameters via a `HashTable`:

```powershell
$newGroup | Set-GraphItem -PropertyTable @{displayName='Group 7 Access Level'; description='All users with Group 7 access'}
```

The `TeamplateObject` parameter allows the these properties and values to be specified in the form of an object, such as one returned by `New-GraphObject` or even from the Graph itself via `Get-GraphResource` or `gls`:

```powershell
$modifiedGroup = New-GraphObject group description 'Just the description'
$newGroup | Set-GraphItem -TemplateObject $modifiedGroup

$newGroup | gls -ContentOnly | select displayname, description

displayName          description
-----------          -----------
Group 7 Access Level Just the description
```

Both the `TemplateObject` and `PropertyTable` parameters can be specified simultaneously -- this could be useful for copying parts of one object as a "template" while adding additional properties:

```powershell
$existingGroup = Get-GraphItem group 4e5701ac-92b2-42d5-91cf-45f4865d0e70 -ContentOnly

$existingGroup | gls -ContentOnly | select description, displayName

mailNickname displayName description
------------ ----------- -----------
             Unused      Unassinged group

$templateGroup = Get-GraphItem group 0b828d58-2f7d-4ec5-92fb-20f0f88aa1a2 -Property displayName, description -ContentOnly

$existingGroup | Set-GraphItem -TemplateObject $templateGroup -PropertyTable @{mailNickName='dorateam'}

$existingGroup | gls -ContentOnly | select description, displayName

mailNickname displayName description
------------ ----------- -----------
dorateam     Team group  Standard team collaboration group
```

Finally, an object returned from the Graph may be "edited" locally and then resubmitted so that the local changes are reflected in the Graph. In this case,
the `GraphItem` parameter supplied to the pipeline is both the target item to update and the source of data to modify:

```powershell
$existingGroup = Get-GraphItem group 4e5701ac-92b2-42d5-91cf-45f4865d0e70 -ContentOnly
$existingGroup.displayName += ' - ' + [DateTime]::now

$existingGroup | Set-GraphItem

$existingGroup | gls -ContentOnly | select description, displayName

description                       displayName
-----------                       -----------
Standard team collaboration group Team group - 05/16/2019 15:14:41
```

Note that `Set-GraphItem` includes an `ExcludeObjectProperty` parameter that allows you to ignore properties specified through `TemplateObject` and `GraphItem` which is useful when the object contains read-only properties that may have been returned as part of an object from a previously executed command.

#### Link resources: add a user to a group (AAD accounts only)

The Graph is not just about individual resources, its power comes from the relationships between those resources. With groups and users for example, the fact that users are members of a group is modeled by a relationship property called `members`. This means that by modifying the `members` relationship property, we can modify which users are members of a group.

To modify a relationship, the `New-GraphItemRelationship` command may be used:

```powershell
New-GraphItemRelationship -FromItem $newGroup -ToItem $newUser -Relationship members


Relationship TargetId                             FromUri                                      TargetUri
------------ --------                             -------                                      ---------
members      71edbed4-a7e7-4b46-8e2f-a28e9135ca54 /groups/f8418e85-e865-45ba-bec6-d16b6dc44045 /directoryObjects/e510d45c-aec3-4026-ba8e-317480ae7bc5
members      71edbed4-a7e7-4b46-8e2f-a28e9135ca54 /groups/f8418e85-e865-45ba-bec6-d16b6dc44045 /directoryObjects/71edbed4-a7e7-4b46-8e2f-a28e9135ca54
```

This adds a directional relationship between the group and the user "group is related to user" through the `members` relationship. In accordance with the API documentation for group, the interpretation of this relationship is that the user is now a member of the group.

To see the new relationship, but not the related items themselves, use the `Get-GraphItemRelationship` command:

```powershell
$newGroup | Get-GraphRelatedItem -WithRelationship members
```

To see the actual items from the relationships (e.g. the members of a group and not just their id's), use the `Get-GraphRelatedItem` command:

```powershell
$newGroup | Get-GraphRelatedItem -WithRelationship members

   Graph Location: /v1.0:/groups/053850da-691d-4605-9bda-6b3d74c7addb/members

Info Type            Preview             Id
---- ----            -----------         --
t +> directoryObject Treemonisha Jackson 8618a75d-a209-44f3-b2f8-2423cb211eed
```

Another useful syntax for `New-GraphItemRelationship` is to supply the items on the "to" side of the relatinoship via the pipeline -- this exploits PowerShell pipeline idioms to simplify operating on sets of objects:

```powershell
# Create passwords for some new users
$passwordProfile1 = New-GraphObject passwordprofile -Property forceChangePasswordNextSignIn, password -Value $true, (Get-Credential user).GetNetworkCredential().Password
$passwordProfile2 = New-GraphObject passwordprofile -Property forceChangePasswordNextSignIn, password -Value $true, (Get-Credential user).GetNetworkCredential().Password

# Create the actual users
$newUser1 = New-GraphItem user -Property mailNickname, userPrincipalName, displayname, accountEnabled, passwordProfile -Value vashford, vashford@newnoir.org, 'Val Ashford', $true, $passwordProfile1
$newUser2 = New-GraphItem user -Property mailNickname, userPrincipalName, displayname, accountEnabled, passwordProfile -Value nsimpson, nsimpson@newnoir.org, 'Nick Simpson', $true, $passwordProfile2

# Create a new group for the users
$teamGroup = New-GraphItem group mailNickName, displayName, mailEnabled, securityEnabled Group7AccessT1, 'Group 7 Access 2', $false, $true

# Add the users to the group
$newUser1, $newUser2 | New-GraphItemRelationship $teamGroup members | out-null

# Display the group's updated membership with the new users

$teamGroup | Get-GraphRelatedItem -WithRelationship members

   Graph Location: /v1.0:/groups/c436312c-4f6e-4963-ac05-bf68b98d7475/members

Info Type            Preview      Id
---- ----            -------      --
t +> directoryObject Val Ashford  d126df35-b441-472e-a3d1-2de370cbbbb7
t +> directoryObject Nick Simpson aafbc281-cce2-450b-9409-7113033d2f62
```

#### Removing a relationship

The inverse of the `New-GraphItemRelationship` command is `Remove-GraphItemRelationship`. In this example the user with id `36d3e3d4-55f2-405f-a601-fd522b7998f4` is removed from the group with id `51a617a1-9174-4836-9a8c-d1cee804bc61`:

```powershell
Remove-GraphItemRelationship -FromType group -FromId 51a617a1-9174-4836-9a8c-d1cee804bc61 -Relationship members -Id 36d3e3d4-55f2-405f-a601-fd522b7998f4
```

A syntax that supports an object rather than identifier for the subject or object of the relationship or both is also available:

```powershell
Remove-GraphItemRelationship -FromItem $existingGroup -Relationship members -Id 36d3e3d4-55f2-405f-a601-fd522b7998f4
```

And the pipeline is also supported -- these example removse all members from the group `$teamGroup`:

```powershell
$teamGroup | Get-GraphItemRelationship -WithRelationship members | Remove-GraphItemRelationship
```

#### Delete resources

Lastly, the resources we've created can all be deleted using the `Remove-GraphItem` command. This example deletes the group with the id `c436312c-4f6e-4963-ac05-bf68b98d7475`:

```powershell
Remove-GraphItem group c436312c-4f6e-4963-ac05-bf68b98d7475
```

The command also takes an object returned by `Get-GraphItem` or `Get-GraphResource`, etc., which is useful for deleting resources accessible only through a relationship with another resource, such as `contact`:

```powershell
# If you have a variable containing the contact retrieved by an AutoGraphPS
# command such as Get-GraphResource, New-GraphItem, gls, etc., you can easily
# delete it by passing it to Remove-GraphItem
$oldContact | Remove-GraphItem
```

#### Write operation tips and tricks

* Use `Show-GraphHelp` to get the documentation for the Graph resource in which you're interested.
* Use `Get-GraphType -Members` to view the properties of the type or structure you're updating
* Use parameter completion with commands like `New-GraphObject`, `New-GraphItem`, `Set-GraphItem`, etc. to ease your workflow and avoid the need to refer to documentation
* Pay attention to error messages from Graph -- these messages will often give useful information about missing or invalid properties so that you can try again, or at least help you navigate a particular help topic.
* Look for opportunities to use the PowerShell pipeline with AutoGraphPS command for concise, efficient, and scalable automation of Graph resource management.

### Invoking Graph methods for complex behaviors and operations

We've covered the ways in which data can be created, updated, queried, and deleted. Graph also supports capabilities beyond those circumscribed by such `CRUD` operations through *methods*. Graph methods, not to be confused with methods like `PUT`, `GET`, et. al. of the HTTP protocol upon which the Graph protocol is layered, can perform arbitrary operations. These Graph methods are very much like *methods* in the object-oriented sense, i.e. they are named units of computation that operate on state within the scope of some object. Methods in Graph have the following characteristics:

* Methods are scoped to an entity type, e.g. `user`, `group`, `drive`, etc.
* Methods have a name that can be used to invoke them -- examples are `sendMail` on the user object, `assignLicense` on the group object, or `search` on the drive object.
* To invoke a method, you need to be able directly or indirectly space the `id` of the entity and the name of the method

Within the framework of the Graph's REST protocol, invoking a method involves constructing the appropriate URI just as in the case of all the `CRUD` operations. The URI in this case will refer to both a particular instance of an entity, typically using an `id` but potentially using a singleton such as `me`.

#### Using Invoke-GraphMethod to access Graph methods

AutoGraphPS provides the `Invoke-GraphMethod` command to make it easy to invoke methods. Here's an example that performs a search of the user's drive, using the [`search` method](https://docs.microsoft.com/en-us/graph/api/driveitem-search?view=graph-rest-1.0&tabs=http) of the calling user's `drive` and passing the query string in the method's `q` parameter:

```powershell
Invoke-GraphMethod /me/drive/search q 'name:docx powershell'

Info Type      Preview                                               Id
---- ----      -------                                               --
t +> driveItem Exploring the Microsoft Graph.docx                    AX893842
t +> driveItem PowerShell user experience for Graph.docx             ZZ8972ZR
t +> driveItem DevOps and PowerShell use cases.docx                  KSJFLAJ3
t +> driveItem Analysis of PowerShell and REST API usability         K8JRAJZE
```

The method returned a set of `driveItem` objects that satisfied the query `name:docx powershell`, the intent of which was to return any content on the drive that contained the keyword `powershell` in items with a `name` containing `docx`.

Since the URI given as the first parameter is relative to the current location, the following invocation would produce the same result:

```powerShell
gcd /me/drive
Invoke-GraphMethod search q 'name:docx powershell'
```

In the next example, `Invoke-GraphMethod` is used to send an email message. In this case, we construct the email message to send using `New-Graphobject` and `New-GraphMethodParameterObject` before passing it as a parameter to `Invoke-GraphMethod`:

```powershell
$me = gls me
$recipientEmail = new-graphobject emailAddress address katwe@newnoir.org
$recipient = new-graphobject recipient emailAddress $recipientEmail

$sendMailParameters = New-GraphMethodParameterObject user sendMail

$sendMailParameters.SaveToSentItems = $true
$sendMailParameters.Message = $sendMailParameters.Message | select subject, body, toRecipients

$sendMailParameters.Message.toRecipients = @($recipient)
$sendMailParameters.Message.Subject = 'What time is it?'
$sendMailParameters.Message.Body.ContentType = 'text'
$sendMailParameters.Message.Body.Content = "The time is $([DateTime]::now), so it's time to Wake Up! --Love, $($me.Content.givenName)"

$me | Invoke-GraphMethod -methodname sendmail -ParameterObject $sendMailParameters
```

In this case, we invoke the method `sendMail` on the previously retrieved `$me` object by passing `$me` in the pipeline. The constructed parameters are specified by the `ParameterObject` parameter of `Invoke-GraphMethod`.

### Discovering resources, methods, URIs, and documentation

All of the rich Microsoft Graph operations described here, even simple read operations, require you to have *some* minimum amount of knowledge, e.g. the URI or the "type" of the resource you'd like to access. You will find all of the required information in the Microsoft Graph documentation. Fortunately, you don't have to spend your time poring over manuals: *AutoGraph provides the tools that often eliminate the need to leave PowerShell to read documentation, or at least help you find the right docs for your scenario.*

The commands described below are very useful when you know you want to use Microsoft Graph to do *something*, but you're not sure where to start.

#### What is the name of the resource I need?

In the Microsoft Graph documentation, the term "resource" is used to refer to any aspect of the Graph that is addressable by an identifier (whether a URI or non-URI) and that is capable of relating to or being related to by other resources. The OData specification upon which Microsoft Graph is currently defined at the protocol level refers to this same resource concept as an "entity type," and this latter terminology is mostly what you'll find in AutoGraphPS. Either way, resources / entity types are the key concepts exposed by Graph that form a cohesive model within and across the problem domains (e.g. security, communication, document management, etc.) that you understand. Once you understand the resource for your use case, you've unlocked your comprehension of a meaningful chunk of the Graph.

Let's say you want to find a security group that has a specific name. Since you know you want to do something with a "group," you can look for resources related to "group" using the `Find-GraphType` command:

```powershell
Find-GraphGype group

TypeClass TypeId                               Criteria MatchedTerms
--------- ------                               -------- ------------
Entity    microsoft.graph.group                {Name}   {microsoft.graph.calendargroup microsoft.graph.group microso...
Entity    microsoft.graph.grouplifecyclepolicy {Name}   {microsoft.graph.calendargroup microsoft.graph.group microso...
Entity    microsoft.graph.schedulinggroup      {Name}   {microsoft.graph.calendargroup microsoft.graph.group microso...
```

The output of `Find-GraphType` in this case is a list of types deemed "relevant" to the supplied search term `group`. The results are sorted by relevance, so the first item in the list can be treated as most likely to be the one you're looking for. The command contains several parameters that allow you to customize the criteria used to identify matches as well as the "fuzziness" of those matches.

#### Now I know the resource, where are the docs so I can understand what it does?

The `Show-GraphHelp` command launches a web browser with the web page displaying help for a resource specified by URI, an object returned as a response from the Graph API, and also the name of a type, i.e. Graph resource. Since the command takes input from the pipeline, the type can be supplied by the output of the `Find-GraphType` command we demonstrated above:

```powershell
Find-GraphGype group | Select-Object -First 1 | Show-GraphHelp
```

This command shows the help page for the first result in the output of the search for `group`, the result for `microsoft.graph.group`. Now you can read about the `group` resource to confirm that it is indeed the resource you need, and also find out more details about the operations that can be performed on the resource.

#### What permissions do I need?

The documentation for the resource *should* contain information describing the permissions you need to perform specific operations on the resource. If you don't already have the web-based documentation for the relevant operation in view, you can look for this information within your PowerShell session via the `Find-GraphPermission` command:

```powershell
Find-GraphPermission group

Type      ConsentType Name                                    Description
----      ----------- ----                                    -----------
Delegated Admin       Group.Read.All                          Allows the app to list groups, and to read their prope...
Delegated Admin       Group.ReadWrite.All                     Allows the app to create groups and read all group pro...
AppOnly   Admin       Group.Read.All                          Allows the app to read group properties and membership...
AppOnly   Admin       Group.ReadWrite.All                     Allows the app to create groups, read all group proper...
```

Using this output which includes a description of the permission, you can determine which permission applies to your scenario. Do you need write access, or just read? Are you accessing the resource using interactive delegated sign-in, or as part of a non-interactive background application? Once you've used those answers to narrow the list down to the least-privileged permission required for your scenario, you can request that permission using the `Connect-GraphApi` command so that your application is able to access the resource.

#### Can I use PowerShell to look at the resource's documentation instead of a web browser?

Currently, the resource's rich documentation, including examples, is available only the web browser and can be accessed via the `Show-GraphHelp` command. However, in many cases your focus is on understanding the structural properties, methods, or relationships between resources. This information about the types *is* available within PowerShell via several commands: `Get-GraphType`, `Get-GraphMember`, and `Get-GraphMethod`. For example, here is the output of `Get-GraphType` for the `group` resource identified earlier:

```powershell
Get-GraphType group

TypeId        : microsoft.graph.group
TypeClass     : Entity
BaseType      : microsoft.graph.directoryObject
DefaultUri    : /groups
Relationships : {@{Parameters=; MethodType=; MemberType=Relationship; IsCollection=True; Name=appRoleAssignments;
                TypeId=microsoft.graph.appRoleAssignment; ScriptClass=}, @{Parameters=; MethodType=;
                TypeId=microsoft.graph.directoryObject; ScriptClass=}...}
Properties    : {@{Parameters=; MethodType=; MemberType=Property; IsCollection=True; Name=assignedLabels;
                TypeId=microsoft.graph.assignedLabel; ScriptClass=}, @{Parameters=; MethodType=; MemberType=Property;
                Name=createdDateTime; TypeId=Edm.DateTimeOffset; ScriptClass=}...}
Methods       : {@{Parameters=; MethodType=Action; MemberType=Method; IsCollection=False; Name=subscribeByMail;
                MethodType=Action; MemberType=Method; IsCollection=False; Name=resetUnseenCount; TypeId=;
                ScriptClass=}...}
```

The resulting object contains information such as the "default" URI, this case `/groups`,  under which instances of the `group` resource may be found. You can use `Select-Object` to project the `Relationships` field that shows the connections with other resources, the `Properties` field which gives the structure of the object, and the `Methods` field which returns all of the methods available to the object.


#### Is there an easier way to see the properties?

Yes -- the `Get-GraphMember` command which is similar to the widely utilized core PowerShell command `Get-Member` emits output that provides a streamlined representation of all of the members, including `Property`, `Relationship`, and `Method` members. To view just the structural properties, the `MemberType` parameter can be specified with the value `Property`:

```powershell
Get-GraphMember -TypeName group -MemberType Property

Name                          MemberType TypeId                                      IsCollection
----                          ---------- ------                                      ------------
allowExternalSenders          Property   Edm.Boolean                                        False
assignedLabels                Property   microsoft.graph.assignedLabel                       True
assignedLicenses              Property   microsoft.graph.assignedLicense                     True
...

theme                         Property   Edm.String                                         False
unseenCount                   Property   Edm.Int32                                          False
visibility                    Property   Edm.String                                         False
```

For each property name the data type is given as well as whether it's a collection, and can save you a trip to the web browser.

#### How do I understand the structure of a properties that aren't just strings or numbers?

In the example above, the properties that are named without the `Edm` prefix are actually structured to definitions present in the API schema. They are typically nested structures, and you can simply use `Get-GraphMember` again along with the associated resource name (`TypeId` in acccordance to the output of `Get-GraphMember`) to find it:

```powershell
Get-GraphMember -TypeName assignedLicense -MemberType Property

Name          MemberType TypeId   IsCollection
----          ---------- ------   ------------
disabledPlans Property   Edm.Guid         True
skuId         Property   Edm.Guid        False

```

This is useful both in understanding what to expect in terms of responses and also what you may need to supply in submitting requests that include these types. Note that simply using `New-GraphObject` to create an "empty" object can allow you to inspect an object representing the resource directly:

```powershell
$sample = New-GraphObject group -Recurse -SetDefaultValues
$sample.licenseProcessingState

state
-----
```

It should be noted that when constructing resources to submit requests that create new resource instances or update them, the commands that do this actually simplify the specification of the structure. It's often unnecessary to know about every single property of a resource. See the earlier examples for `New-GraphItem`, `Set-GraphItem`, and `New-GraphObject` for more details on how you can efficiently specify just the properties required to submit a resource as part of a request to Graph.

#### I want the resource's URI so I can `gcd` to it and `gls` it

If you are using PowerShell to browse resources exposed by the Graph, the documentation will explain the URIs under which you might find them. The `Get-GraphType` command exposes a `DefaultUri` field that provides a possible location where you might find the type, though not all types have a "default" URI:

```powershell
Get-GraphType group | Select-Object DefaultUri

DefaultUri
----------
/groups

gcd /groups
gls
```

#### What other resources is it related to?
The `Get-GraphMember` command's `MemberType` can be specified as `Relationship` to enumerate all of the relationships from this resource to other resources:

```powershell
Get-GraphMember -TypeName group -MemberType Relationship

Name                     MemberType   TypeId                                          IsCollection
----                     ----------   ------                                          ------------
acceptedSenders          Relationship microsoft.graph.directoryObject                         True
appRoleAssignments       Relationship microsoft.graph.appRoleAssignment                       True
calendar                 Relationship microsoft.graph.calendar                               False

...


threads                  Relationship microsoft.graph.conversationThread                      True
transitiveMemberOf       Relationship microsoft.graph.directoryObject                         True
transitiveMembers        Relationship microsoft.graph.directoryObject                         True
```

#### Does the resource have interesting methods I can call?

You can use `Get-GraphMember` again to view just `Method` members, but the specialized `Get-GraphMethod` command provides more focused output:

```powershell
Get-GraphMethod -TypenName group

Name                          MethodType ReturnType                                                Parameters
----                          ---------- ----------                                                ----------
addFavorite                   Action     @{TypeId=; IsCollection=False}
assignLicense                 Action     @{TypeId=microsoft.graph.group; IsCollection=False}       {@{Name=addLicenses; TypeId=microsoft.g...
checkGrantedPermissionsForApp Action     @{TypeId=microsoft.graph.resourceSpecificPermissionGrant;
removeFavorite                Action     @{TypeId=; IsCollection=False}
renew                         Action     @{TypeId=; IsCollection=False}
resetUnseenCount              Action     @{TypeId=; IsCollection=False}
subscribeByMail               Action     @{TypeId=; IsCollection=False}
unsubscribeByMail             Action     @{TypeId=; IsCollection=False}
validateProperties            Action     @{TypeId=; IsCollection=False}                             {@{Name=displayName; TypeId=Edm.String;...
```

#### What are the parameters for a given method?

When you've identified a useful method, the next question is what parameters do you need to feed it? `Get-GraphMethod` has a `Parameter` option that lists just the parameters for a method:

```powershell
Get-GraphMethod -TypeName group assignLicense -Parameters

Name           TypeId                          IsCollection
----           ------                          ------------
addLicenses    microsoft.graph.assignedLicense         True
removeLicenses Edm.Guid                                True
```

#### In summary: now put your knowledge to work!

By making use of these "type" introspection commands, you can easily find your way to detailed web-based documentation when you need it, and otherwise get focused, relevant reference information  within the comfortable and efficient environment of PowerShell.

## Managing and customizing application identities

AutoGraphPS provides commands to manage Azure Active Directory application identities, including the ability to manage permission consent for the applications. These commands are useful for provisioning any application or service for your organization, and may also be used to create new identities for which to execute AutoGraphPS-based scripts. And because application management commands are built-in to the module, AutoGraphPS is a self-contained Graph automation solution; there is no need jump outside to other command-line or graphical tools / portals if you need to provision an application identity dedicated to automation since AutoGraphPS itself can perform the provisioning.

### Provision a new application for interactive AutoGraphPS usage

By default, AutoGraphPS uses a particular multi-tenant application identity to allow you to sign in to your organization and execute all of the AutoGraphPS commands that access the Graph API. This application was provisioned by the maintainer of AutoGraphPS. Alternatively, you may use a different application with AutoGraphPS, one that you have provisioned and over which you have complete and sole control.

The `New-GraphApplication` command provisions a new public client application for interactive sign-in -- the application is granted the specific delegated permissions `User.Read` and `Group.Read.All` in this invocation:

```powershell
$newApp = New-GraphApplication 'Custom Graph PowerShell App' -DelegatedPermissions User.Read, Group.Read.All -ConsentForAllUsers

Connect-GraphApi -AppId $newApp.AppId

Id         : 86b02091-9a57-43c0-a2c2-bf805b85deda
AppId      : 32a7262b-492a-4ad2-bb96-2ff8ff6cf680
Endpoint   : https://graph.microsoft.com/
User       : natossa@ether.org
Status     : Online

$groups = Get-GraphResource groups
```

The `New-GraphApplication` command issued a request through the Graph API to create a new public client AAD application. Anyone in the organization can sign in to the application. Since the optional `ConsentForAllUsers` parameter was also specified, consent has been granted to the application for all users in the organization; they will not get prompted for consent when using it. By default, any delegated permissions specified to the command will be consented only for the user issuing the `New-GraphApplication` command, not the entire organization.

The subsequent use of the `Connect-GraphApi` command with the `AppId` parameter shown above allows users to sign in with this (or any other) application by specifying the application's identifier. Once signed in, AutoGraphPS commands may be issue just as they are when using the default AutoGraphPS application; the commands will be authorized by the Graph API based on the permissions granted to this application at sign-in.

In general, consent can be managed outside of application creation by using commands such as `Set-GraphApplicationConsent`, `Get-GraphApplicationConsent`, and `Remove-GraphapplicationConsent`

### Provision a new application for non-interactive unattended AutoGraphPS usage

The built-in application identity for AutoGraphPS requires a user to sign-in before commands can be issued against the Graph. The requirement for human interaction won't work for fully automated scenarios such as running AutoGraphPS PowerShell scripts as background jobs or in other unattended contexts. To address this, you can use `New-GraphApplication` to provision a confidential client application that authenticates without human intervention:

```powershell
# In addition to creating the app identity with Graph, this commmand
# creates a certificate in the local certificate store for unattended
# authentication
$newApp = New-GraphApplication 'Daily user information stats background app' -Confidential -ApplicationPermissions User.Read.All

# This command requires no user interaction because a certificate in the local
# certificate store is being used
Connect-GraphApi -AppId $newapp.AppId -Confidential -NoninteractiveAppOnlyAuth -TenantId natossa@ether.org

Id         : bfb7167a-e8b3-4238-aff2-9c673e8e8ffb
AppId      : 3ea110e5-80e1-48a6-b67f-a3c5dc108b96
Endpoint   : https://graph.microsoft.com/
User       :
Status     : Online

$users = Get-GraphResource users
```

In this example, `New-GraphApplication` creates a new confidential client application identity and provisions it with `User.Read.All`. However, if the AutoGraphPS script is executed from the Windows OS, then by default `New-GraphApplication` **also** creates a certificate in the local certificate store specific to this application and configures AAD to enable that certificate as a credential for the identity.

The example continues by using the newly created application to sign in to Graph using `Connect-GraphApi`. In addition to specifying the new application's identifier using the `AppId` parameter, the `Confidential` parameter must be supplied to direct the command to require credentials for the application itself and not just a user's credentials, AND the `NonInteractiveAppOnlyAuth` parameter must be supplied so that only the application credential is required (no user interaction is desired in this case). Additionally, the `TenantId` parameter must be specified using either the domain name of the tenant as in this case or the the tenant identifer. This allows the command to direct the sign-in to the correct tenant.

`Connect-GraphApi` then searches for a certificate for the application in the local certificate store, and will find the one created by `New-GraphApplication` and use it to authenticate.

After authentication succeeds, the example retrieves all of the users in the tenant by invoking `Get-GraphResource` against the `users` URI.

The following considerations related to non-interactive authentication should be noted:
  * The automatic certificate provisioning in the local certificate store by `New-GraphApplication` is optional, and indeed only occurs on the Windows platform
  * The certificates created by `New-GraphApplication` and related commands can be enumerated using the `Find-GraphLocalCertificate` command and filtered by the application identifier.
  * `New-GraphApplication` allows for certificates from other sources such as files to be specified instead of allowing `New-GraphApplication` to create the certificate. The latter approach is fully supported for non-Windows platforms.
  * `Set-GraphApplicationCertificate` can be used to update the application credentials outside of the context application creation. This is useful for periodic certificate rotations prior to the expiration of the certificate for instance. In general it can be used set pre-existing certificates as application credentials (fully supported for non-Windows PowerShell environments)
  * `Remove-GraphApplicatinCertificate` removes the association of a certificate from an application -- this is also useful as part of a certificate rotation process. It does not impact the actual certificate itself, even if it is stored on the local system.
  * `New-GraphApplicationCertificate` can be used to create a new certificate as an object, in the file system, or in the local certificate store (Windows-only) and sets that certificate as a credential for the application.
  * As is the case with the applications using delegated permissions, the `Set-GraphApplicationConsent`, `Get-GraphApplicationConsent`, and `Remove-GraphApplication` consent commands may be used to manage application permissions outside of the application creation flow
  * Certificates used as credentials for applications are secrets and must be treated as such; they must be secured from discovery and made available only on trusted systems for authorized uses.

The parameters of all of these commands allow for additional scenarios beyond those described here, so be sure to explore the commands further in evaluating identity provisioning and sign-in capabilities against your needs.

## Troubleshooting and debugging

### Diagnosing errors
Whether it's due to coding defects in scripts or typos during your exploration of the Graph, you'll inevitably encounter errors. The cmdlet `Get-GraphError` will show you the last error returned by the Microsoft Graph API during your last cmdlet invocation:

```powershell
Get-GraphResource /users -Filter "startwith(userPrincipalName, 'pfunk')"
```

This results in an error:

```
Invoke-WebRequest : The remote server returned an error: (400) Bad Request.
At C:\users\myuser\Documents\WindowsPowerShell\modules\autographps-sdk\0.4.0\src\rest\restrequest.ps1:73 char:17
+ ...             Invoke-WebRequest -Uri $this.uri -headers $this.headers - ...
+                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebRequest:HttpWebRequest) [Invoke-WebRequest], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeWebRequestCommand
```

The `400` is a fairly generic error -- to debug it, we'd like to see the response body from the server. `Get-GraphError` exposes it along with other useful information. For the error above, the `message` field of the response gives a hint at what was wrong with the request: `Invalid filter clause`:

```
Get-GraphError

AfterTimeLocal    : 7/6/2018 10:08:41 PM
AfterTimeUtc      : 7/7/2018 5:08:41 AM
PSErrorRecord     : The remote server returned an error: (400) Bad Request.
Response          : System.Net.HttpWebResponse
ResponseHeaders   : @{x-ms-ags-diagnostic={"ServerInfo":{"DataCenter":"West US","Slice":"SliceC","Ring":"5","
                    ScaleUnit":"001","Host":"AGSFE_IN_28","ADSiteName":"WUS"}}; Transfer-Encoding=chunked;
                    request-id=a5a65cde-bb6b-45ad-9eb6-15f192bc8849; Content-Type=application/json;
                    Cache-Control=private; Strict-Transport-Security=max-age=31536000; Date=Sun, 08 Jul 2018
                    05:10:12 GMT; Duration=7.5021; client-request-id=a5a65cde-bb6b-45ad-9eb6-15f192bc8849}
ResponseStream    : {
                      "error": {
                        "code": "BadRequest",
                        "message": "Invalid filter clause",
                        "innerError": {
                          "request-id": "a5a65cde-bb6b-45ad-9eb6-15f192bc8849",
                          "date": "2018-07-06T05:08:42"
                        }
                      }
                    }
StatusCode        : BadRequest
StatusDescription : Bad Request
```

A close look at the filter clause shows that `startwith` is missing an `s` after `start` -- the corrected command below will succeed with a `200`:

```
Get-GraphResource /users -Filter "startwith(userPrincipalName, 'pfunk')"

Info Type Preview     Name
---- ---- -------     ----
t +> user Sir Nose    83dd3dbb-d7f3-44d3-a4a1-b92971ba7379
t +> user PFunk 4Life 30285b8b-70ba-42e0-9bd9-fbcee5d1ce64
```

You can inspect the various properties and object returned by `Get-GraphError` to find additional details that help you debug a failure.

### Logs for exploration and troubleshooting

AutoGraphPS records a log of every request and response to Graph issued by AutoGraphPS commands. To view the contents of the log, invoke the `Get-GraphLog` command. In the example below, `Get-GraphLog` is invoked immediately following an attempt to create a new security group using `New-GraphItem`

```powershell
$newGroup = New-GraphItem group -Property mailNickName, displayName, mailEnabled  -Value ReportViewers, 'Report Viewers', $false

Get-GraphLog

RequestTimestamp             StatusCode Method Uri
----------------             ---------- ------ ---
2/26/2021 10:08:38 PM -08:00        400 POST   https://graph.microsoft.com/v1.0/groups
2/26/2021 10:01:07 PM -08:00        204 DELETE https://graph.microsoft.com/v1.0/groups/7330583a-d3e5-494b-800c-8e4b67be8460
2/26/2021 10:01:07 PM -08:00        200 GET    https://graph.microsoft.com/v1.0/groups/7330583a-d3e5-494b-800c-8e4b67be8460
2/26/2021 10:00:57 PM -08:00        201 POST   https://graph.microsoft.com/v1.0/groups
2/26/2021 9:58:56 PM -08:00         200 GET    https://graph.microsoft.com/v1.0/organization
2/26/2021 9:55:28 PM -08:00         200 GET    https://graph.microsoft.com/v1.0/users?$search=johnson
2/26/2021 9:47:23 PM -08:00         200 GET    https://graph.microsoft.com/v1.0/groups?$search=ashford
```

> TIP: You can pipe the output of Get-GraphLog to the Format-GraphLog command and use its `View` parameter to provide output optimized for scenarios such as investigating timing or authentication issues.

The log shows information about the underlying REST protocol request issued by the commands, sorted with the most recent requests first. The `StatusCode` column shows that the most recent request was a failed request because its value of `400` is outside the `2xx` success range. There are many more diagnostic fields such as HTTP request and response headers available outside of the default tabular view for the command -- use the `Get-Member` command on the output of `Get-GraphLog` to learn more.

You can use commands like `Clear-Log` and `Set-GraphLogOption` to manage the log's data and the module's logging behaviors including retention and level of detailed logging:

* By default, AutoGraphPS logs information such as the HTTP request URI, request and response headers, and status code, but omits the request and reponse body to protect the privacy of users and organizations using AutoGraphPS.
* Headers known to contain secrets such as the `Authorization` header used to communicate the access token are always redacted -- the actual value of the header is never logged
* To completely disable logging which is enabled by default, use the command `Set-GraphLogOption -LogLevel None`
* To erase previously logged data, issue the `Clear-Log` command
* Currently the log persists only in-memory, so when the PowerShell session ends or the AutoGraphPS-SDK module is unloaded, the log contents are completely erased.

The log allows for the full range of protocol debugging and can help diagnose connectivity issues or problems with intermediate gateways between AutoGraphPS and the Graph API service. When used in conjunction with standard network diagnostic tools you'll be able to narrow down just about any issue.

In addition, the logs are a great way to learn about Microsoft Graph at the REST protocol level; with each command, you can see the resulting REST requests and responses to gain an understanding of the Graph API protocol.

#### Get a closer look at errors

In the example above, the most recent command was

```powershell
$newGroup = New-GraphItem group -Property mailNickName, displayName, mailEnabled  -Value ReportViewers, 'Report Viewers', $false
```

which failed with a `400 Bad Request` error. We can get more information on the failure by looking in more detail at the log entry:

```powershell
Get-GraphLog -first 1 | Format-List *

RequestTimestamp        : 2/27/2021 1:15:23 AM -08:00
Uri                     : https://graph.microsoft.com/v1.0/groups
Method                  : POST
ClientRequestId         : f8e1b815-cd69-4431-b362-554d901c4019
RequestHeaders          : {Authorization, Content-Type, client-request-id}
RequestBody             :
HasRequestBody          : True
AppId                   : ac70e3e2-a821-4d19-839c-b8af4515254b
AuthType                : Delegated
UserObjectId            : a524cd16-58e0-48d3-93be-8cc25be634c1
UserUpn                 : harrow@dragonking.org
TenantId                : f2280b9c-8858-49cc-9544-db2e0529c22b
Permissions             : {directory.accessasuser.all, email, openid, profile...}
ResourceUri             : groups
Query                   :
Version                 : v1.0
StatusCode              : 400
ResponseTimestamp       : 2/27/2021 1:15:59 AM -08:00
ErrorResponse           : {
                            "error": {
                              "code": "Request_BadRequest",
                              "message": "A value is required for property 'securityEnabled' of resource 'Group'.",
                              "innerError": {
                                "date": "2021-02-27T09:14:50",
                                "request-id": "2f2f9077-1c5b-46f1-a7a1-c706924b2ba3",
                                "client-request-id": "f8e1b815-cd69-4431-b362-554d901c4019"
                              }
                            }
                          }
ResponseClientRequestId : f8e1b815-cd69-4431-b362-554d901c4019
ResponseHeaders         : {x-ms-ags-diagnostic, Transfer-Encoding, request-id, Content-Type...}
ResponseContent         :
ResponseRawContent      :
ClientElapsedTime       : 00:00:35.8903225
LogLevel                : Basic
```

Note that the `ErrorResponse` field provides the detail needed to resolve the issue: `A value is required for property 'securityEnabled' of resource 'Group'.` The request did not include an explicit value for the `securityEnabled` property of the group; Graph requires this property be specified at creation time. The fix then is simple -- the original command can be modified to include the required property and re-invoked as followed:

```powershell
$newGroup = New-GraphItem group -Property mailNickName, displayName, mailEnabled, securityEnabled  -Value ReportViewers, 'Report Viewers', $false $true
```

This modified command now succeeds.

### Enabling full logging

To ensure the privacy of Graph data accessed by AutoGraphPS, by default the module does not log the body of a request or response. These elements of the protocol can contain sensitive information such as the actual contents of a document or e-mail, as well as the title or subject of such communication. This safe default behavior can be overridden when the need arises using the `Set-GraphLogOption` command:

```powershell
$newGroup = New-GraphItem group -Property mailNickName, mailEnabled, securityEnabled -Value Group7Access,  $false, $true

# This command generates no output because the request body
# is not emitted to the log by default
Get-Graphlog -Newest 1 | Select-Object -ExpandProperty RequestBody

# Issue this command to enable full logging of request and response body
Set-GraphLogOption -LogLevel Full

# Now retry the scenario
$newGroup = New-GraphItem group -Property mailNickName, mailEnabled, securityEnabled -Value Group7Access,  $false, $true

# Now the JSON request body from the retried command is emitted:
Get-Graphlog -Newest 1 | Select-Object -ExpandProperty RequestBody

{
    "mailEnabled":  false,
    "securityEnabled":  true,
    "displayName":  "Group 7 Access",
    "mailNickname":  "Group7Access"
}
```

The ability to view the full request and response enhances debugging scenarios, aids users learning about the Graph API protocol, and provides an easy way to generate REST protocol sequences for use in developing non-PowerShell applications that make direct use of REST to access the Graph API.

Full logging enabled by `Set-GraphLogOption` will remain in effect for the duration of the PowerShell session until the `Basic` logging level is restored by another invocation of `Set-GraphLogOption`. Note that changing the log level does not affect the content of previous logs, so to remove any full request or response data in the log, use `Clear-Log` to erase it once it is no longer needed, or simply close the PowerShell session.

### Diagnostic output via `-verbose`
All AutoGraphPS cmdlets support the PowerShell standard option `-verbose` and the associated `$VerbosePreference` preference variable. When using cmdlets such as `Get-GraphResource` and `Get-GraphChildItem`, specifying `-verbose` will output not only the `http` verb and `uri` used to access the Graph, but also the request headers and for responses the response body and headers.

By default, the response body is truncated after a certain length, though the behavior can be overridden by setting `GraphVerboseOutputPreference` to `High`.

### Authorization errors
Microsoft Graph requires callers to obtain specific authorization for applications like AutoGraphPS to access particular capabilities of the Graph. Because the mapping of required permissions to functionality is currently only available through human-readable [documentation](https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference), it's easy for developers and other human users of applications including AutoGraphPS to encounter errors due to insufficient permissions.

Often, users and developers remedy the error by reading the documentation, and updating the application to request the missing permissions. AutoGraphPS tries to hasten such fixes by surfacing authorization failures with a warning encouring the user to request additional permissions as in the example below where the caller tries to access `me/people` to get information about the people with whom she has been interacting:

```powershell
PS> gls me/people
WARNING: Graph endpoint returned 'Unauthorized' accessing 'me/people'. Retry after re-authenticating via the
'Connect-GraphApi' cmdlet and requesting appropriate permissions. See this location for documentation on
permissions that may apply to this part of the Graph:
'https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference'.
WARNING: {
  "error": {
    "code": "ErrorAccessDenied",
    "message": "Access is denied. Check credentials and try again.",
    "innerError": {
      "request-id": "bfcd8509-1a0e-4e8b-8b15-435bb413003b",
      "date": "2018-07-07T30:43:14"
    }
  }
}
```

The warning message in the AutoGraphPS output includes a link to the permissions documentation and suggestion to use `Connect-GraphApi` to grant AutoGraphPS additional permissions. Consultation of the documentation may lead the user to conclude that AutoGraphPS is missing the 'People.Read' scope, and a retry of the original attempt after using `Connect-GraphApi` to request `People.Read` will succeed:

```powershell
# This will prompt the user to re-authenticate and grant People.Read
# to AutoGraphPS
Connect-GraphApi People.Read

gls me/people

Info Type   Preview       Name
---- ----   -------       ----
t +> person Cosmo Jones   X8FF834
t +> person Minerva Smith X8FF835
t +> person Rufus Chang   X8FF332
```

## Advanced commands and concepts

The concepts and commands below are described briefly as their usage is (currently) less common. In cases where they prove to cover important scenarios, simpler cmdlets will eventually be added for those uses.

### Advanced queries with `-Query`

The `-Query` parameter for several commands lets you directly specify the Uri query parameters for the Graph call made by AutoGraphPS. It must conform to [OData specifications](http://docs.oasis-open.org/odata/odata/v4.0/errata03/os/complete/part2-url-conventions/odata-v4.0-errata03-os-part2-url-conventions-complete.html#_Toc453752360). The option is provided to allow you to overcome limitations in AutoGraphPS's simpler query options. For example the two commands below are equivalent:

```powershell
gls /users -Filter "startsWith(mail, 'p')" -top 20
gls /users -Query  "`$filter=startsWith(mail, 'p')&`top=20"
```

Note that `-Query` requires you to understand how to combine multiple query options via '&' and also how to make correct use of PowerShell escape characters so that OData tokens like `$top` which are preceded by the `$` character which is reserved as a variable prefix in PowerShell are taken literally instead of as the value of a PowerShell variable.

While `-Query` may be more complicated to use, when AutoGraphPS's other query options do not support a particular Graph query feature, you still have a way to use Graph's full capabilities.

For more details on how to construct this parameter, see the [MS Graph REST API documentation for queries](https://developer.microsoft.com/en-us/graph/docs/concepts/query_parameters).

### Invoke-GraphApiRequest -- the universal Graph cmdlet

The `Invoke-GraphApiRequest` cmdlet supports all of the functionality of `Get-GraphResource`, and exceeds it in a key aspect: where `Get-GraphResource` only enables APIs that support the `GET` `http` method, `Invoke-GraphApiRequest` supports all http methods, including `PUT`, `POST`, `PATCH`, and `DELETE`.

This means you can use `Invoke-GraphApiRequest` for not just read operations as with the `Get-Graph*Item` cmdlets, but write operations as well. In fact, *any* behavior supported by Microsoft Graph is accessible through this command. However such invocations are typically far more cumbersome to issue than those of the other dedicated commands which abstract many concepts and automatically generate or interpret complex JSON structure that must be specified explicitly when using `Invoke-GraphApiRequest`.

Still, the generic capability of `Invoke-GraphApiRequest` means that even if `AutoGraphPS` does not expose a specific command for some feature of Microsoft Graph, *you can still use that feature* by doing some research into the REST protocol for the capability and then invoking `Invoke-GraphApiRequest` according to the protocol.

#### Write access through `Invoke-GraphApiRequest`

> Note: The requirements for write operations vary among the different entities exposed by the Graph -- consult the [Microsoft Graph documentation](https://developer.microsoft.com/en-us/graph/docs/concepts/overview) for information on creating, updating, and deleting objects in the Graph.

In this example, we create a new contact. This will require we specify data in a structure that can be serialized into JSON format, and fortunately this is fairly simple as PowerShell has easy-to-use support for JSON:

```powershell
$contactData = @{givenName='Cleopatra Jones';emailAddresses=@(@{name='Work';Address='cleo@soulsonic.org'})}
Invoke-GraphApiRequest me/contacts -Method POST -Body $contactData
```

This will return the newly created contact object (you can inspect it further by accessing `$LASTGRAPHITEMS[0]`).

The `contactData` variable was assigned to a structure that would result in the JSON required for the Graph type `contact` whose JSON representation can be found in the [Graph documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/v1.0/resources/contact). The rules for creating such an object are roughly as follows:

* For key-value pairs of a Javascript object, simply use a PowerShell `HashTable` that contains all the keys and values. You can use the `@{}` syntax for the PowerShell `HashTable`.
* If there are values that are also Javascript objects (i.e. they are not strings, numbers, etc.), those themselves can be PowerShell `HashTable` instances with their own keys and values. Thus, you'll likely end up with one or more levels of nested `HashTable` instances
* If a value is an array, express the array using PowerShell's `Array` type via the `@()` syntax. The elements of the array can be any type as well, including `HashTable` instances that represent Javascript objects, other arrays expressed via `@()` syntax, and of course simple types like numbers and strings.
* If it isn't clear, the `HashTable` instances can contain arrays.

The ability of PowerShell to express mutual nesting of arrays and `HashTable` instances via compact `@()` and `@{}` syntax makes it fairly intuitive and readable to express any object that can be expressed as JSON.

##### Making it easier with New-GraphObject

Simple manual construction of JSON serializable objects is feasible with PowerShell syntax, however the process still requires human understanding of the detailed correspondence between JSON format and PowerShell data types with mistake-free rendering of the object.

Fortunately, AutoGraphPS provides the `New-GraphObject` command which correctly renders the object according to the API schema and removes the source of much of the human error. For example, the, following sequence of commands can be used to create a contact just as in the previous `contact` example:

```powershell
$emailAddress = New-GraphObject -TypeClass Complex emailAddress -Property name, address -Value Work, cleo@soulsonic.org
$contactData = New-GraphObject contact -Property givenName, emailAddresses -Value 'Cleopatra Jones', @($emailAddress)
Invoke-GraphApiRequest me/contacts -Method POST -Body $contactData
```

While this command takes 3 lines instead of 2, its lack of `@()` and `@{}` syntax makes its intent more plain. The `Property` parameter allows you to specify which properties of the object you'd like to include. The optional `Value` property lets you specify the value of the property -- each element of the `Value` parameter corresponds to the desired value of the property named by an element at the same position in the list specified to `Property`. The command will keep you honest by throwing an error if you specify a property that does not exist on the object; this error checking is not available with the shorter 2 line version -- rather than finding out your error sooner with an explicit error message, the failure occurs when making the request to Graph, and the error message may not always be explicit about which property is set incorrectly.

Note that the `Value` parameter is not mandatory, and in fact does not require the same cardinality as `Property` -- any properties without a corresponding value are simply set to a default value.

One difficulty is that Graph defines to kinds of composite types, the `Entity` and `Complex` types of OData. To avoid the potentially incorrect asssumption that type names are unique across `Entity` and `Complex` types, you must specify the `TypeClass` parameter with the value `Complext` to override the default type class of `Entity` that `New-GraphObject` uses to build the object.

##### The PropertyTable alternative
The `PropertyTable` argument combines the approaches above, allowig you to use the `HashTable` `@{}` syntax to specify each property and value as keys and vlaues in a `HashTable` object using the `{}` syntax. Because this expresses properties and values in one pair rather than as part of two separate lists which must be carefully arranged to align the right value to the desired property, it is less error-prone. Since the `HashTable` may be specified with a multi-line syntax, this can be a very readable way to express the object:

```powershell
$emailAddress = New-GraphObject -TypeClass Complex emailAddress -PropertyTable @{
    name = 'Work'
    address = 'cleo@soulsonic.org'
}

$contactData = New-GraphObject contact -PropertyTable @{
    givenName = 'Cleopatra Jones'
    emailAddresses = @($emailAddress)
}

Invoke-GraphApiRequest me/contacts -Method POST -Body $contactData
```

This approach, while certainly using more lines than the others, is even more readable and easier to express correctly than the parallel lists.

### Get-GraphUriInfo -- understanding the Graph's structure

You can use `Get-GraphUriInfo` to get information about whether a given Uri is valid, what entity type it represents, and what Uri segments may follow it. Its functionality is based on data retrieved from the Graph endpoint's `$metadata` response.

Here are some examples:

```powershell
# Get basic type information about the uri '/me/drive/root'
Get-GraphUriInfo /me/drive/root

Info Type      Preview Name
---- ----      ------- ----
n  > driveItem         root

# Use format-list to see all fields
Get-GraphUriInfo /me/drive/root

ParentPath   : /me/drive
Info         : n  >
Relation     : Direct
Collection   : False
Class        : NavigationProperty
Type         : driveItem
Name         : root
Namespace    : microsoft.graph
Uri          : https://graph.microsoft.com/v1.0/me/drive/root
GraphUri     : /me/drive/root
Path         : /v1.0:/me/drive/root
FullTypeName : microsoft.graph.driveItem
Version      : v1.0
Endpoint     : https://graph.microsoft.com/
IsDynamic    : False
Parent       :
Details      : @{ScriptClass=; isDynamic=False; graphUri=/me/drive/root; type=NavigationProperty; parent=;
               isVirtual=False; isInVirtualPath=False; name=root; leadsToVertex=False; graphElement=;
               decoration=; PSTypeName=GraphSegment}
Content      :
Preview      :
PSTypeName   : GraphSegmentDisplayType

# View information about the full uri
Get-GraphUriInfo /me/drive/root | select -expandproperty uri
```

In the above example, `Get-GraphUriInfo` parsed the Uri in order to generate the returned information. If you were to give a Uri that is not valid for the current graph, you'd receive an error like the one below:

```powershell
Get-GraphUriInfo /me/idontexist
Uri '/me/idontexist' not found: no matching child segment 'idontexist' under segment 'me'
At C:\users\myuser\Documents\WindowsPowerShell\modules\autographps\0.14.0\src\metadata\segmentparser.ps1:140 char:21
+ ...             throw "Uri '$($Uri.tostring())' not found: no matching ch ...
+                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : OperationStopped: (Uri '/me/idonte...er segment 'me':String) [], RuntimeExcept
   ion
    + FullyQualifiedErrorId : Uri '/me/idontexist' not found: no matching child segment 'idontexist' under s
   egment 'me'
```

#### Finding the parents and children

The `Get-GraphUriInfo` cmdlet also allows you to determine the set of parent (predecessor) segments of the Uri, as well as all segments immediately following the Uri, that is the children (successors):

```powershell
# These are all the segments that precede /me/drive/root
Get-GraphUriInfo /me/drive/root -Parents

Info Type      Preview Name
---- ----      ------- ----
/  > root              /
s  > user              me
n  > drive             drive
n  > driveItem         root

# And these are all the children
Get-GraphUriInfo /me/drive/root -Children

Info Type             Preview Name
---- ----             ------- ----
n* > driveItem                children
a    scalar                   copy
a    scalar                   createLink
a    scalar                   createUploadSession
f    driveItem                delta
a    scalar                   invite
n  > listItem                 listItem
n* > permission               permissions
f    driveItem                search
n* > thumbnailSet             thumbnails
n* > driveItemVersion         versions
n  > workbook                 workbook
```
The presence of `workbook` in the list of children suggests that the following Uri is valid, which indeed it is:

```powershell
/me/drive/root/workbook
```

As for what it does, the "Type" column indicates that a `GET` for that Uri should return an entity of type `workbook`. The "Info" column consists of four symbols with the following meaning

* **Column 0:** This is the **segment class** from [OData's Entity Data Model (EDM)](www.odata.org/documentation/odata-version-2-0/overvie). It can be one of the following:
  * **'a' - Action:** An action method invoked through a `POST` method that potentially changes the state of the entity
  * **'e' - EntitySet:** A collection of every instance of a particular kind of entity type
  * **'f' - Function:** A function method that does not alter the entity but does return a value related to it
  * **'n' - NavigationProperty:** A link from one entity to one or more entities of a particular type
  * **'s' - Singleton:** A single instance of a particular entity type with a unique name across the entire EDM
  * **'t' - EntityType instance**: An instance of an entity type, i.e. actual data returned from Graph that describes users, computers, etc.
* **Column 1:** The **collection** column -- it contains `*` if the item is a collection and is empty if not
* **Column 2:** The **data** column -- it contains a `+` if the item is one or more entities returned from Graph, is empty otherwise
* **Column 3:** The **locatable** column: this column has a `>` character if it can be followed by an entity and is empty otherwise

**Tip:** Use the command `Get-GraphUriInfo /` to see all of the segments that may legally start a Uri.

#### Don't forget about "virtual" segments

`Get-GraphUriInfo` doesn't just parse static Uris, but any that are syntactically valid, i.e.

```powershell
Get-GraphResource /me/drive/root/children/myfile.txt | fl *
```

returns the following whether or not that Uri (and the OneDrive file this particular path represents) exists in the Graph:

```powershell
ParentPath   : /me/drive/root/children
Info         : t  >
Relation     : Data
Collection   : False
Class        : EntityType
Type         : driveItem
Name         : myfile.txt
Namespace    : microsoft.graph
Uri          : https://graph.microsoft.com/v1.0/me/drive/root/children/myfile.txt
GraphUri     : /me/drive/root/children/myfile.txt
Path         : /v1.0:/me/drive/root/children/myfile.txt
FullTypeName : microsoft.graph.driveItem
Version      : v1.0
Endpoint     : https://graph.microsoft.com/
IsDynamic    : True
Parent       :
Details      : @{ScriptClass=; isDynamic=True; graphUri=/me/drive/root/children/myfile.txt; type=EntityType;
               parent=; isVirtual=False; isInVirtualPath=False; name=myfile.txt; leadsToVertex=False;
               graphElement=; decoration=; PSTypeName=GraphSegment}
Content      :
Preview      :
PSTypeName   : GraphSegmentDisplayType
```

The purpose of this cmdlet is to let you know what's syntactically valid, not what is actually valid.

Note that it will even "make up" hypothetical Uri's for you when `-Children` with the `-IncludeVirtualChildren` option:

```powershell
Get-GraphResourceWithMetadata /me/drive/root/children -children -IncludeVirtualChildren | select uri

Uri
---
https://graph.microsoft.com/v1.0/me/drive/root/children/{driveItem}
```

The `{driveItem}` segment tells you format of a hypothetical segment that could follow `children`, as well as the type (`driveItem`), allowing tools provide developers hints about possible queries and the data they can return.

### Using Get-GraphToken with other Graph tools

When using tools like Postman or Fiddler to troubleshoot or test the Graph, you'll need to acquire a token. Token acquisition continues to be one of the biggest barriers to using Graph, so use AutoGraphPS's `Get-GraphToken` cmdlet to automate it:

```powershell
Get-GraphToken
```

This cmdlet will retrieve a token for the current Graph. Running the command above will write the token to the display so that it can be cut and pasted into tools like Fiddler and Postman. To avoid displaying it, assign it to a variable or better yet just pipe it to the clipboard using the `clip.exe` command built into Windows:

```powerhsell
Get-GraphToken | clip
```

You can then simply paste it into your tool of choice without having to highlight text or click buttons.


