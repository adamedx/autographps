## How to explore with PoshGraph
After you've installed the module, invoke PoshGraph cmdlets from any PowerShell session.

### Get started -- simple commands

**PoshGraph** cmdlets allow you to explore the graph. Before using the cmdlets, you must establish a connection to the graph. The easiest approach is to use the `Connect-Graph` cmdlet, after which you can execute other cmdlets such as `Get-GraphItem` which operate on the graph:

```powershell
Get-GraphItem me
```

After you respond to authentication prompts, `GetGraphItem` returns a PowerShell object representing MS Graph's view of the `me` entity, i.e. the entity that represents your user object. The output will be as described in an earlier section.

Since the first execution of `Get-GraphItem` establishes a logical "session," you can continue to execute cmdlets without being asked to re-authenticate, e.g. a subsequent invocation like

```powershell
PS> get-graphitem organization
```

will not prompt for credentials but immediately return details about your organization:

    id              : fb6df3ba-c5f5-43dd-b108-a921f1a7e759
    businessPhones  : {206 881 8080}
    city            : Seattle
    displayName     : Akana
    postalCode      : 98144
    state           : Washington
    street          : 101 23rd Avenue Suite X

### Expanding your scope

The commands above are trivial demonstrations of Graph. In particular, they only require the authorization scope known as `User.Read`. More interesting explorations of the Graph require that you request additional [scopes](https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference) when you connect to the Graph.

Here's how you can request the `Files.Read,` `Mail.Read`, and `Contacts.Read` scopes in addition to `User.Read` -- the additional scopes enable you to access those parts of the Graph for reading information about user files from *OneDrive* and your list of personal contacts:

```powershell
Connect-Graph User.Read, Files.Read, Mail.Read, Contacts.Read
```

This will prompt you to authenticate again and consent to allow the application to acquire these permissions. Note that it is generally not obvious what scopes are required to access different functionality in the Graph; future updates to PoshGraph will attempt to address this. For now, consult the [Graph permissions documentation](https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference) whenever you're accessing a new part of the Graph.

In addition to the `get-graphitem` cmdlet which returns data as a series of flat lists, you can use `get-graphchilditem` or its alias `gls` to retrieve your personal contacts:

```powershell
PS> get-graphitemchilditem me/contacts

Info Type    Preview        Name
---- ----    -------        ----
t +> contact Cosmo Jones    XMKDFX1
t +> contact Akeelah Smith  XMKDFX2
t +> contact John Henry     XMKDFX4
t +> contact Deandre George XMKDFX8
```

The `Preview` column shows data returned from Graph that `get-graphchilditem` deems to be most human-readable -- in this case, the `displayName` of the `contact` entity.

Items with a `+` in the `Info` field returned by `get-graphchilditem` contain content. The actual content, i.e. data that would be returned by `Get-GraphItem` is not displayed by default, but you can use the `Select` alias of PowerShell to retrieve the `Content` property of each row. In this way `Get-GraphChildItem` returns a superset of the data returned from `Get-GraphItem`. The use of `Get-GraphItem` below

```powershell
Get-Graphitem me/contacts/XMKDFX1
```

which returns the contact with `id` `XMKDFX1` may also be retrieved through the sequence below through `Get-GraphChildItem` (alais `gls`) with a `Select` for the `Content` prpoerty on the first result:

```
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

#### The `$LASTGRAPHITEMS variable

As with any PowerShell cmdlet that returns a value, the `Get-GraphItem` and `Get-GraphhChildItem` cmdlets can be assigned to a variable for use with other commands or simply to allow you to dump properties of objects and their child objects:

```powershell
$mycontacts = gls me/contacts
```

However, even if you neglect to make such an assignment, the results of the last invoked `Get-*Item` cmdlet is available in the `$LASTGRAPHITEMS` variable:

```
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

**IMPORTANT NOTE:** The example above illustrates an import aspect behavior of `Get-GraphChildItem`:
1. When the Uri argument for the cmdlet references a collection, the result is simply the items in the collection. This is actual data from Graph.
2. But when the Uri references a single entity, the first element returned is the entity itself, and any additional elements are the allowed segments (if any) that can immediately follow the entity in a valid Uri for Graph. This is metadata about Graph that reveals its structure.
3. This contrasts with `Get-GraphItem` which only exhibits the behavior in (1).

This makes `Get-GraphChildItem` an effective way to recursively discover the Uris for both Graph data and structure (metadata).

#### Explore new locations

You may have noticed that after the first time you invoked `Get-GraphChildItem`, your PowerShell prompt displayed some additional information:

```
[starchild@mothership.io] v1.0:/
PS>
```

By default, PoshGraph automatically adds this to your path on your first use of the exploration-oriented cmdlets `Get-GraphChildItem` and `Set-GraphLocation` (alias `gcd`). The text in square brackets denotes the user identity with which you've logged in. The next part before the `:` tells you what Graph API version you're using, in this case the default of `v1.0`. The part following this is your *location* within that API version. Any Uris specified to `Get-GraphChildItem`, `Get-GraphItem`, or `Set-GraphLocation` are interpreted as relative to the current location, in very much the same way that file-system oriented shells like `bash` and PowerShell interpret paths specified to commands as relative to the current working directory. In this case, your current location in the Graph is `/`, the root of the graph.

With PoshGraph, you can traverse the Graph using `gls` and `gcd` just the way you'd traverse your file system using `ls` to "see" what's in and under the current location and "move" to a new location. Here's an example of exploring the `/drive` entity, i.e. the entity that represents your `OneDrive` files:

```
gcd me/drive/root/children
[starchild@mothership.io] v1.0:/me/drive/root/children
PS> gls

Info Type      Preview       Name
---- ----      -------       ----
t +> driveItem Recipes       13J3XD#
t +> driveItem Pyramid.js    13J3KD2
t +> driveItem Panther.md    13J3SDJ
t +> driveItem Spacetime     13J3DDF
```

If you'd like to know what's "inside" of Recipes, you can `gcd` and `gls` again:

```

[starchild@mothership.io] v1.0:/me/drive/root/children
PS> gcd me/drive/root/children/Recipes
[starchild@mothership.io] v1.0:/me/drive/root/children/Recipes
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

[starchild@mothership.io] v1.0:/me/drive/root/children/Recipes
PS> gls

Info Type      Preview           Name
---- ----      -------           ----
t +> driveItem SweetPotatePie.md 13K559
t +> driveItem Gumbo.md          13K299

[starchild@mothership.io] v1.0:/me/drive/root/children/Recipes
PS> gls
```

Note that as in the file system case, you can save yourself a lot of typing of long Uri's by using `gcd` and taking advantage of the ability to use shorter Uri's relative to the current location.

Of course, you can always use absolute Uri's that are independent of your current location, just start the Uri with `/`, e.g.

```
gls /me/contacts
```

which returns the same result regardless of your current location, for which you can also query using `get-graphlocation`, aka `gwd` (like `pwd` in the file system):

```
gwd

Path
----
v1.0:/me/drive/root/children/candidates/children
```

#### Understanding errors

Whether it's due to coding defects in scripts or typos during your exploration of the Graph, you'll inevitably encounter errors.

#### Authorization errors

#### Advanced commands and concepts
