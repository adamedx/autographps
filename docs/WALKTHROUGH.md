AutoGraphPS Walkthrough
=======================

This walkthrough will expose you to the key capabilities of AutoGraphPS and the Microsoft Graph. It is certainly not exhaustive, but should be enough for you understand how to use AutoGraphPS in your work, where it falls short, and how you might remedy any omissions with your own contributions to the project.

The walkthrough assumes you are familiar with PowerShell and basic usage of the object pipeline, and that you are familiar with REST concepts.

## How to explore with AutoGraphPS
After you've installed the module, invoke AutoGraphPS cmdlets from any PowerShell session.

### Get started -- simple commands

**AutoGraphPS** cmdlets allow you to explore the graph. Before using the cmdlets, you must establish a connection to the graph by signing in. If you have not already done this using `Connect-Graph`, that's ok -- any commands that need a connection will request one before communicating with the graph. After that, any subsequent commands will re-use that same connection, so you won't have to sign in again.

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

The commands above are trivial demonstrations of Graph. In particular, they only require the Graph permission known as `User.Read`. More interesting explorations of the Graph require that you request additional [permissions](https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference) when you connect to the Graph.

Here's how you can request the `Files.Read,` `Mail.Read`, and `Contacts.Read` permissions in addition to `User.Read` -- the additional permissions enable you to access those parts of the Graph for reading information about user files from *OneDrive* and your list of personal contacts:

```powershell
Connect-Graph User.Read, Files.Read, Mail.Read, Contacts.Read
```

This will prompt you to authenticate again and consent to allow the application to acquire these permissions. Note that it is generally not obvious what permissions are required to access different functionality in the Graph; future updates to AutoGraphPS will attempt to address this. For now, consult the [Graph permissions documentation](https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference) whenever you're accessing a new part of the Graph.

In addition to the `Get-GraphResource` cmdlet which returns data as a series of flat lists, you can use `Get-GraphResourceWithMetadata` or its alias `gls` to retrieve your personal contacts:

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

#### Easier content through `-ContentColumns`

An alternative to explicitly `select`ing content is to simply add the desired properties from content into returned objects. You can do just that with the `-ContentColumns` option of `Get-GraphResourceWithMetadata`. Note that while this changes the fields available in the object, the default display output will still only show the four default columns. You can use PowerShell's `select` alias when the display of the value is what matters.

For example, the following two commands are equivalent:
```powershell
# Retrieves contacts and the last time they were modified
# Preview and info columns are already there by default
gls me/contacts -ContentColumns LastModifiedDateTime, emailaddresses | select Info, Preview, LastModifiedDateTime, emailaddresses

# This more convoluted command does the same thing
gls me/contacts | foreach { [PSCustomObject] @{Info=$_.Info; Preview=$_.Preview;LastModifiedDateTime=$_.content.LastModifiedDateTime; EmailAddresses=$_.content.EmailAddresses} }
```

If one of the fields in `Content` has the same name as a field in the containing object, it will be prepended with a `_` character when added to it in order to resolve the conflict.

#### The `$LASTGRAPHITEMS` variable

As with any PowerShell cmdlet that returns a value, the `Get-GraphResource`, `Get-GraphResourceWithMetadata`, `Get-GraphChildItem` cmdlets can be assigned to a variable for use with other commands or simply to allow you to dump properties of objects and their child objects:

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

**IMPORTANT NOTE:** The example above illustrates an import aspect behavior of `Get-GraphResourceWithMetadata`:
1. When the Uri argument for the cmdlet references a collection, the result is simply the items in the collection. This is actual data from Graph.
2. But when the Uri references a single entity AND the URI is not empty AND is not the value `.`, only that entity is returned.
3. If the URI references a single entity and is either not specified or is the value `.`, the returned elements are the allowed segments (if any) that can immediately follow the entity in a valid Uri for Graph. This is metadata about Graph that reveals its structure.
4. This contrasts with `Get-GraphResource` which only exhibits the behavior in (1).

Note that `Get-GraphChildItem` is similar to `Get-GraphResourceWithMetadata`, except it does not exhibit the behavior in (2) above, it always exhibits both (1) and (3) at the same time.

This makes the `Get-GraphResourceWithMetadata` / `gls` and `Get-GraphChildItem` commands effective ways to recursively discover the Uris for both Graph data and structure (metadata).

### Explore new locations

You may have noticed that after the first time you invoked `gls`, your PowerShell prompt displayed some additional information:

```
[starchild@mothership.io] /v1.0:/
PS>
```

By default, AutoGraphPS automatically adds this to your path on your first use of the exploration-oriented cmdlets `Get-GraphResourceWithMetadata`, `Get-GraphChildItem` and `Set-GraphLocation` (alias `gcd`). The text in square brackets denotes the user identity with which you've logged in. The next part before the `:` tells you what Graph API version you're using, in this case the default of `v1.0`. The part following this is your *location* within that API version. Any Uris specified to `Get-GraphResourceWithMetadata`, `Get-GraphChildItem`, `Get-GraphResource`, or `Set-GraphLocation` are interpreted as relative to the current location, in very much the same way that file-system oriented shells like `bash` and PowerShell interpret paths specified to commands as relative to the current working directory. In this case, your current location in the Graph is `/`, the root of the graph.

With AutoGraphPS, you can traverse the Graph using `gls` and `gcd` just the way you'd traverse your file system using `ls` to "see" what's in and under the current location and "move" to a new location. Here's an example of exploring the `/drive` entity, i.e. the entity that represents your `OneDrive` files:

```
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

```

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

```
gls /me/contacts
```

which returns the same result regardless of your current location, for which you can also query using `get-graphlocation`, aka `gwd` (like `pwd` in the file system):

```
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

### Projecting fields with `-Select`

By default, Graph does not return all properties of an object -- it returns those deemed most likely to be useful without retrieving every field to avoid excessive network traffic. For example, the query below for a given user is missing the `department` property in the response:

```
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

To fix this, use `-select` to project the exact set of fields you're interested in. This has the benefit of allowing you to reduce network consumption as well, which is most useful when handling large result sets:

```
ggr me -select displayName, department, mail, officeLocation

@odata.context : https://graph.microsoft.com/v1.0/$metadata#users(displayName,department,mail,officeLocation)
                 /$entity
department     : Ministry of Funk
displayName    : Starchild Okorafor
officeLocation : 7/3191
mail           : starchild@mothership.io
```

For a better understanding of how and when OData services like Graph can project properties, see the [Microsoft Graph documentation for `$select`](https://developer.microsoft.com/en-us/graph/docs/concepts/query_parameters#select-parameter).

### Sorting with `-OrderBy` and `-Descending`

Particularly when retrieving large result sets, it is important to be able to specify the order in which items are returned. For an e-mail inbox with 1000 messages for instance, you may only want to retreive the first 50 or so after sorting by descending date (the most recent messages). In other cases you may want to sort on multiple fields.

The following example uses the `-OrderBy` option to retrieve the 10 oldest messages -- note that we use PowerShell's client-side select cmdlet to limit the displayed fields:

```
ggr /me/messages -first 10 -OrderBy receivedDateTime | select ReceivedDateTime, Importance, Subject
```

However, to retrieve the 10 newest high-importance items, you should specify the `-Descending` option, which means that all fields specified through `OrderBy` will have a descending order by default:

```
ggr /me/messages -first 10 -OrderBy receivedDateTime, importance -Descending | select ReceivedDateTime, Importance, Subject
```

What if you want to sort using ascending order for one field, and descending for another? You can specify a PowerShell `HashTable` to identify sort directions for specific fields. This lets you find the oldest high-importance items:

```
ggr /me/messages -first 10 -OrderBy @{receivedDateTime=$false;importance=$true} | select ReceivedDateTime, Importance, Subject
```


The `$false` assignment in the hash table means that the field will use *ascending* sort order, and `$true` means *descending* order.

### Advanced queries with `-Query`

The `-Query` option lets you directly specify the Uri query parameters for the Graph call made by AutoGraphPS. It must conform to [OData specifications](http://docs.oasis-open.org/odata/odata/v4.0/errata03/os/complete/part2-url-conventions/odata-v4.0-errata03-os-part2-url-conventions-complete.html#_Toc453752360). The option is provided to allow you to overcome limitations in AutoGraphPS's simpler query options. For example the two commands below are equivalent:

```
gls /users -Filter "startsWith(mail, 'p')" -top 20
gls /users -Query       "`$filter=startsWith(mail, 'p')&`top=20"
```

Note that `-Query` requires you to understand how to combine multiple query options via '&' and also how to make correct use of PowerShell escape characters so that OData tokens like `$top` which are preceded by the `$` character which is reserved as a variable prefix in PowerShell are taken literally instead of as the value of a PowerShell variable.

While `-Query` may be more complicated to use, when AutoGraphPS's other query options do not support a particular Graph query feature, you still have a way to use Graph's full capabilities.

For more details on how to construct this parameter, see the [MS Graph REST API documentation for queries](https://developer.microsoft.com/en-us/graph/docs/concepts/query_parameters).

## Troubleshooting and debugging

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

### Diagnostic output via `-verbose`
All AutoGraphPS cmdlets support the PowerShell standard option `-verbose` and the associated `$VerbosePreference` preference variable. When using cmdlets such as `Get-GraphResource` and `Get-GraphChildItem`, specifying `-verbose` will output not only the `http` verb and `uri` used to access the Graph, but also the request headers and for responses the response body and headers.

By default, the response body is truncated after a certain length, though the behavior can be overridden by setting `GraphVerboseOutputPreference` to `High`.

### Authorization errors
Microsoft Graph requires callers to obtain specific authorization for applications like AutoGraphPS to access particular capabilities of the Graph. Because the mapping of required permissions to functionality is currently only available through human-readable [documentation](https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference), it's easy for developers and other human users of applications including AutoGraphPS to encounter errors due to insufficient permissions.

Often, users and developers remedy the error by reading the documentation, and updating the application to request the missing permissions. AutoGraphPS tries to hasten such fixes by surfacing authorization failures with a warning encouring the user to request additional permissions as in the example below where the caller tries to access `me/people` to get information about the people with whom she has been interacting:

```
PS> gls me/people
WARNING: Graph endpoint returned 'Unauthorized' accessing 'me/people'. Retry after re-authenticating via the
'Connect-Graph' cmdlet and requesting appropriate permissions. See this location for documentation on
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

The warning message in the AutoGraphPS output includes a link to the permissions documentation and suggestion to use `Connect-Graph` to grant AutoGraphPS additional permissions. Consultation of the documentation may lead the user to conclude that AutoGraphPS is missing the 'People.Read' scope, and a retry of the original attempt after using `Connect-Graph` to request `People.Read` will succeed:

```powershell
# This will prompt the user to re-authenticate and grant People.Read
# to AutoGraphPS
Connect-Graph People.Read

gls me/people

Info Type   Preview       Name
---- ----   -------       ----
t +> person Cosmo Jones   X8FF834
t +> person Minerva Smith X8FF835
t +> person Rufus Chang   X*FF332
```

## Advanced commands and concepts

The commands below are described briefly as their usage is (currently) less common. In cases where they prove to cover important scenarios, simpler cmdlets will most likely be added for those uses.

### Invoke-GraphRequest -- the universal Graph cmdlet

The `Invoke-GraphRequest` cmdlet supports all of the functionality of `Get-GraphResource`, and exceeds it in a key aspect: where `Get-GraphResource` only enables APIs that support the `GET` `http` method, `Invoke-GraphRequest` supports all http methods, including `PUT`, `POST`, `PATCH`, and `DELETE`.

This means you can use `Invoke-GraphRequest` for not just read operations as with the `Get-Graph*Item` cmdlets, but write operations as well. Note that the syntax and parameter specification for such cases is cumbersome, so in the future dedicated cmdlets with a simpler syntax will be provided to handle the most common cases where `Invoke-GraphRequest` is today's only solution.

#### Write access through `Invoke-GraphRequest`

> Note: The requirements for write operations vary among the different entities exposed by the Graph -- consult the [Microsoft Graph documentation](https://developer.microsoft.com/en-us/graph/docs/concepts/overview) for information on creating, updating, and deleting objects in the Graph.

In this example, we create a new contact. This will require we specify data in a structure that can be serialized into JSON format, and fortunately this is fairly simple as PowerShell has easy-to-use support for JSON:

```powershell
$contactData = @{givenName='Cleopatra Jones';emailAddresses=@(@{name='Work';Address='cleo@soulsonic.org'})}
Invoke-GraphRequest me/contacts -Method POST -Body $contactData
```

This will return the newly created contact object (you can inspect it further by accessing `$LASTGRAPHITEMS[0]`).

The `contactData` variable was assigned to a structure that would result in the JSON required for the Graph type `contact` whose JSON representation can be found in the [Graph documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/v1.0/resources/contact). The rules for creating such an object are roughly as follows:

* For key-value pairs of a Javascript object, simply use a PowerShell `HashTable` that contains all the keys and values. You can use the `@{}` syntax for the PowerShell `HashTable`.
* If there are values that are also Javascript objects (i.e. they are not strings, numbers, etc.), those themselves can be PowerShell `HashTable` instances with their own keys and values. Thus, you'll likely end up with one or more levels of nested `HashTable` instances
* If a value is an array, express the array using PowerShell's `Array` type via the `@()` syntax. The elements of the array can be any type as well, including `HashTable` instances that represent Javascript objects, other arrays expressed via `@()` syntax, and of course simple types like numbers and strings.
* If it isn't clear, the `HashTable` instances can contain arrays.

The ability of PowerShell to express mutual nesting of arrays and `HashTable` instances via compact `@()` and `@{}` syntax makes it fairly intuitive and readable to express any object that can be expressed as JSON.

##### Making it easier with New-GraphObject

While relatively simple manual construction of JSON serializable objects is feasible with PowerShell syntax, the process still requires human understanding of the detailed correspondence between JSON format and PowerShell data types with mistake-free rendering of the object.

Fortunately, AutoGraphPS provides the `New-GraphObject` command which correctly renders the object according to the API schema and removes the source of much of the human error. For example, the, following sequence of commands can be used to create a contact just as in the previous `contact` example:

```powershell
$emailAddress = New-GraphObject -TypeClass Complex emailAddress -Property name, address -Value Work, cleo@soulsonic.org
$contactData = New-GraphObject contact -Property givenName, emailAddresses -Value 'Cleopatra Jones', @($emailAddress)
Invoke-GraphRequest me/contacts -Method POST -Body $contactData
```

While this command takes 3 lines instead of 2, its lack of `@()` and `@{}` syntax makes its intent more plain. The `Property` parameter allows you to specify which properties of the object you'd like to include. The optional `Value` property lets you specify the value of the property -- each element of the `Value` parameter corresponds to the desired value of the property named by an element at the same position in the list specified to `Property`. The command will keep you honest by throwing an error if you specify a property that does not exist on the object; this error checking is not available with the shorter 2 line version -- rather than finding out your error sooner with an explicit error message, the failure occurs when making the request to Graph, and the error message may not always be explicit about which property is set incorrectly.

Note that the `Value` parameter is not mandatory, and in fact does not require the same cardinality as `Property` -- any properties without a corresponding value are simply set to a default value.

One difficulty is that Graph defines to kinds of composite types, the `Entity` and `Complex` types of OData. To avoid the potentially incorrect asssumption that type names are unique across `Entity` and `Complex` types, you must specify the `TypeClass` parameter with the value `Complext` to override the default type class of `Entity` that `New-GraphObject` uses to build the object.

##### The PropertyMap alternative
The `PropertyMap` argument combines the approaches above, allowig you to use the `HashTable` `@{}` syntax to specify each property and value as keys and vlaues in a `HashTable` object using the `{}` syntax. Because this expresses properties and values in one pair rather than as part of two separate lists which must be carefully arranged to align the right value to the desired property, it is less error-prone. Since the `HashTable` may be specified with a multi-line syntax, this can be a very readable way to express the object:

```powershell
$emailAddress = New-GraphObject -TypeClass Complex emailAddress -PropertyMap @{
    name = 'Work'
    address = 'cleo@soulsonic.org'
}

$contactData = New-GraphObject contact -PropertyMap @{
    givenName = 'Cleopatra Jones'
    emailAddresses = @($emailAddress)
}

Invoke-GraphRequest me/contacts -Method POST -Body $contactData
```

This approach, while certainly using more lines than the others, is even more readable and easier to express correctly than the parallel lists.

### Get-GraphUri -- understanding the Graph's structure

You can use `Get-GraphUri` to get information about whether a given Uri is valid, what entity type it represents, and what Uri segments may follow it. Its functionality is based on data retrieved from the Graph endpoint's `$metadata` response.

Here are some examples:

```
# Get basic type information about the uri '/me/drive/root'
Get-GraphUri /me/drive/root

Info Type      Preview Name
---- ----      ------- ----
n  > driveItem         root

# Use format-list to see all fields
Get-GraphUri /me/drive/root

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
Get-GraphUri /me/drive/root | select -expandproperty uri
```

In the above example, `Get-GraphUri` parsed the Uri in order to generate the returned information. If you were to give a Uri that is not valid for the current graph, you'd receive an error like the one below:

```
Get-GraphUri /me/idontexist
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

The `Get-GraphUri` cmdlet also allows you to determine the set of parent (predecessor) segments of the Uri, as well as all segments immediately following the Uri, that is the children (successors):

```
# These are all the segments that precede /me/drive/root
Get-GraphUri /me/drive/root -Parents

Info Type      Preview Name
---- ----      ------- ----
/  > root              /
s  > user              me
n  > drive             drive
n  > driveItem         root

# And these are all the children
Get-GraphUri /me/drive/root -Children

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

```
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

**Tip:** Use the command `Get-GraphUri /` to see all of the segments that may legally start a Uri.

#### Don't forget about "virtual" segments

`Get-GraphUri` doesn't just parse static Uris, but any that are syntactically valid, i.e.

```
Get-GraphResource /me/drive/root/children/myfile.txt | fl *
```

returns the following whether or not that Uri (and the OneDrive file this particular path represents) exists in the Graph:

```
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

The point of this cmdlet is to let you know what's syntactically valid, not what is actually valid.

Note that it will even "make up" hypothetical Uri's for you when `-Children` with the `-IncludeVirtualChildren` option:

```
Get-GraphChildItem /me/drive/root/children -children -IncludeVirtualChildren | select uri

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

