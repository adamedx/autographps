# Copyright 2021, Adam Edwards
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

. (import-script ../metadata/SegmentParser)
. (import-script common/SegmentHelper)
. (import-script common/GraphUriParameterCompleter)
. (import-script Get-GraphLastOutput)


<#
.SYNOPSIS
Sets the current Graph API URI location used by commands as the default URI for issuing Graph API requests or inspecting Graph API metadata.

.DESCRIPTION
The Set-GraphLocation command sets the current Graph API URI location to a specified value. This current location is used by commands to resolve Uris relative to that location to reduce the data entry overhead of entering long URIs from the console. Maintaining a current location also helps remove the need to remember entire URI paths at every command invocation -- just invoke the command once to set the current location; if subsequent commands use URIs relative to that location, that prefixed location in the URI may be omitted.

Set-GraphLocation provides the alias 'gcd' because the behavior of Set-GraphLocation with regard to Graph API URIs is analgous to the functionalty of the 'cd' command in many shell languages used to 'change directory', i.e. set the current location in the file system.

To see the current location, invoke the Get-GraphLocation command, which is also aliased by 'gwd" since Get-GraphLocation's behavior is analgous to the commonly known utility 'pwd'. The module also updates the PowerShell prompt with the current location if Set-GraphLocation is executed unless prompt integration has been disabled via the Set-GraphPrompt command or related profile settings.

Commands that specify a Graph API URI or explicitly refer to a parameter as being based on the current location use the current location in these ways:

* If a given URI value is specified as the value '.', then its actual value is the same as the current location. This makes '.' have semantics similar to the semantics of '.' for file system paths.
* If the URI does not start with '/', then the current location is appended with the specified value as additional URI segments to generate the actual value.
* If the URI starts with a '/' and the first segment does not end with a ':', the actual URI starts with the first segment of the current location, followed by the specified value.
* Otherwise the current location is not used and the the specified value is the same as the actual value.

For more information on the syntax of Graph API URI paths, see the NOTES section.

.PARAMETER Uri
The Uri parameter is the URI valid in the current Graph or Graph specified by the GraphName parameter for the graph resource on which to invoke the GET method. If the Uri starts with '/', it is interpreted as an absolute path in the graph. If it does not, then it is relative to the current Graph location, which by default is '/'. If the value of the URI is '.' or is not specified it's default value is interpreted as the current Graph location. See the command DESCRIPTION and NOTES section for more details on how the Uri parameter is interpreted for this command and for commands with the same similar inputs as well.

.PARAMETER Index
Specifies an index of an object from the results of the Get-GraphLastItem command; the Graph URI path of the indexed object is then set as the current location. Get-GraphLastItem returns the result of the last Graph API request issued by the Get-GraphResource, Get-GraphResourceWithMetadata, or Invoke-GraphApiRequest commands. This is useful when the displayed results of those commands have identifiers that are cumbersome for data entry or auto-completion as the value of the Path parameter for a subsequent Set-GraphLocation invocation.

.PARAMETER TypeName
Specifies a Graph type whose default Graph URI enumeraiton location should be set as the current location. Many, but not all Graph resource instances of a given type can be enumerated from a specific URI. For example, for the user type, all instances of user can be enumerated from /users. If the type has an identifiale default URI, the current location is set to it. Otherwise, the command results in an error and the current location is unchanged.

.PARAMETER Force
Specifies that the current location must be set to the specified location even if the command cannot validate it. The Set-GraphLocation command relies on API metadata that describes the structure of the API in order to validate that the location specified to it actually exists for the Graph. This data may not be available at the time the command is invoked because the module has not completed downloading the API metadata from the service endpoint or has not completed processing it. By default, if the metadata is not available, the command fails and the current location is unchanged; specify the Force parameter to set the location even when metadata cannot be consulted. The risk is that this location may not be valid and subsequent commands that depend on it will fail.

.PARAMETER NoAutoMount
By default, if the parameter specified by Path starts with a Graph name segment, i.e. one that ends with ':', and there is no currently mounted Graph with that Graph name segment, then the command attempts to mount one. It does this by assuming that the name in the first segment corresponds to that of an API version for a Graph -- it then tries to create a new Graph using the same API service endpoints as the current Graph but with the API version from the specified Graph name. This provides an easy way to switch between versions, e.g. 'Set-GraphLocation /beta:' will automatically mount the beta API version of the service endpoint of the current Graph, removing the need to explicitly invoke the New-Graph command which can accomplish the same capability. The name of such an auto-mounted graph will be the same as the API version (or appended with a disambiguating string if such a graph name is already mounted). If no such API version can be mounted, then the command fails and the current location is changed. Specify the NoAutoMount parameter to suppress this behavior -- in any cause where auto-mount would have been used and NoAutoMount is specified, the command will simply fail.

.PARAMETER GraphName
Specifies that the Uri for parameter path must be interpreted as relative the graph with the name specified to GraphName.

.PARAMETER StrictOutput
Specify StrictOutput to override the default behavior of returning segments that contain only metadata only when no parameter is passed to the command to enumerate the current directory and it is an entity. With StrictOutput, both data and metadata are emitted for every value of the Uri parameter where the Uri resolves to an entity.

.OUTPUTS
This command does not produce any output. To check the current location after the command completes, invoke the Get-GraphLocation command or its alias gwd.

.NOTES
A Graph URI has the following structure:

([/<graphname>:]( [/[<relativeUri>]) | (<relativeUri> | '.')

where relativeUri is one or more sequences of segments that could be considered the valid segments of a Uniform Resource Identifier.

* The <graphname> element MUST correspond to the name of a mounted graph (or one most be mounted to it to make it valid) as mounted by the New-Graph command
* When <graphname> is present, the entire path is interpreted as-is and must be a valid API URI in the graph named by <graphname> as described in the DESCRIPTION section.
* When a <relativeUri> element is specified without an immediately preceding '/', this path is interpreted as relative to the current location as described in the DESCRIPTION section
* When a <relativeUri> element is preceded immediately by '/' but without a previous <graphname> segment, it is interpreted as being a path in the graph of the current location as described in the DESCRIPTION section.
* The specification of '.' has the semantics described in DESCRIPTION.

.EXAMPLE
gcd /users
gwd

Path
----
/v1.0:/users

This example refers to Set-GraphLocation using its alias, gcd to set the current location to /users in the current graph.

.EXAMPLE
gcd /beta:
WARNING: -Force option specified or automount not disallowed and metadata is not ready, will force location change to root ('/')
gwd

Path
----
/beta:/

In this example, a graph name is specified as the first segment since it ends with a ':' character; because no graph named 'beta' is mounted and the NoAutoMount parameter is not specified, the command tries to find an API version named 'beta' and then mounts that as the Graph. The location is changed to the root of the newly mounted graph, but a warning is displayed because the new API version metadata background processing must be completed before commands are able to resolve Uris relative to the new location; this may result in some commands waiting until the processing is complete.

.EXAMPLE
gcd -TypeName group
gwd

Path
----
/v1.0:/groups

Here the TypeName parameter instruction Set-GraphLocation to change the current location to the default API URI for the group type. This happens to be /groups, and the subsequent use of gwd shows that this is indeed the new location.

.EXAMPLE
gcd /me/contacts
gls
Get-GraphLastOutput

Index Info Type Preview           Id
----- ---- ---- -------           --
    0 t +> contact Cosmo Jones    AQMkADAwATExADlhNy00YzRmLWFjNDItMDACLTAwCgB...
    1 t +> contact Akeelah Smith  AQMkADAwATExADlhNy00YzRmLWFjNDItMDACLTAwCgB...
    2 t +> contact John Henry     AQMkADAwATExADlhNy00YzRmLWFjNDItMDACLTAwCgB...
    3 t +> contact Deandre George AQMkADAwATExADlhNV00YzRmLWFjNDItMDACLTAwCgB...

gcd -Index 2
gwd

Path
----
/v1.0:/users/AQMkADAwATExADlhNV00YzRmLWFjNDItMDAXLTAwCgBGAAAD_hc-sQbvekqyZIq_2GYBtgcAXNU0wBIpIEOF_w3WEyCuxAAAAgEkAABAA2hR9BI1qEuUOnyaM9xK8QAEM4Mv8wAAAA==

In this example, Set-GraphLocation is used via the gcd alias to set the current location to /me/contacts. Executing 'gls' queries the Graph using the current location, returning all the contacts for the signed-in user. The output of gls is not shown here, but the output of Get-GraphLastOutput (alias 'glo') is shown since it provides a useful 'index' shortcut. The problem here is that if the goal is to 'gcd' into a particular contact, the id must be specified, and for contacts identifiers may be 100 characters in length, and when displayed on the console may be truncated. Get-GraphLastObject shows an identifier and a heuristically derived friendly name; in the list above, if "John Henry" is the desired contact, the index is '2'. Thus `gcd -Index 2' will set the current location to that contact without the need to specify its cumbersome identifier.

.LINK
Get-GraphLocation
Get-GraphResourceWithMetadata
Get-GraphResource
Get-GraphLastOutput
Set-GraphPrompt
Get-GraphType
#>
function Set-GraphLocation {
    [cmdletbinding(defaultparametersetname='path')]
    param(
        [parameter(position=0, parametersetname = 'path', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Alias('Path')]
        $Uri = $null,

        [parameter(parametersetname='index', mandatory=$true)]
        [int] $Index,

        [parameter(parametersetname='totype', mandatory=$true)]
        [Alias('ToType')]
        [string] $TypeName,

        [switch] $Force,

        [parameter(parametersetname='path')]
        [switch] $NoAutoMount,

        [string] $GraphName
    )

    Enable-ScriptClassVerbosePreference

    $inputUri = if ( $TypeName ) {
        $typeInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $false $null $null $null
        if ( ! $typeInfo.Uri ) {
            throw "Unable to find a default location for the specified type '$TypeName'"
        }
        $typeInfo.Uri
    } elseif( $Uri ) {
        if ( $Uri -is [String] ) {
            $Uri
        } elseif ( $Uri | gm -membertype scriptmethod '__ItemContext' ) {
            ($Uri |=> __ItemContext | select -expandproperty RequestUri)
        } elseif ( $Uri | gm Path ) {
            $Uri.path
        } else {
            throw "Uri must be a valid location string or object with a path / Uri"
        }
    } else {
        $graphItem = Get-GraphLastOutput -Index $Index
        $itemId = if ( $graphItem | gm id -erroraction ignore ) {
            $graphItem.Id
        }

        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $null $false $Uri $itemId $graphItem

        if ( $requestInfo.TypeInfo | gm UriInfo -erroraction ignore ) {
            $requestInfo.TypeInfo.UriInfo.Path
        } else {
            throw 'Unable to determine the location of the specified object'
        }
    }

    $ParsedPath = $::.GraphUtilities |=> ParseLocationUriPath $inputUri

    $currentContext = $::.GraphContext |=> GetCurrent

    $contextName = if ( $GraphName ) {
        $GraphName
    } else {
        $ParsedPath.ContextName
    }

    $automounted = $false
    $context = if ( $contextName ) {
        $pathContext = 'LogicalGraphManager' |::> Get |=> GetContext $contextName

        if ( ! $pathContext -and ! $NoAutoMount.IsPresent ) {
            $pathContext = try {
                write-verbose "Graph name '$($contextName)' was specified but no such graph is mounted"
                write-verbose "Attempting to auto-mount Graph version '$($ContextName)' using the existing connection"
                $::.LogicalGraphManager |=> Get |=> NewContext $null $currentContext.connection $contextName $contextName $true
            } catch {
                write-verbose "Auto-mount attempt failed with error '$($_.exception.message)'"
            }

            if ( $pathContext ) {
                $::.GraphManager |=> UpdateGraph $pathContext
            }
            $automounted = $true
        }

        $pathContext
    } else {
        $currentContext
    }

    if ( ! $context ) {
        throw "Cannot set current location using graph '$($contextName)' because it is not mounted or there is no current context. Try using the New-Graph cmdlet to mount it."
    }

    $parser = new-so SegmentParser $context $null $true

    $absolutePath = if ( $parsedPath.IsAbsoluteUri ) {
        $parsedPath.RelativeUri
    } else {
        $::.LocationHelper |=> ToGraphRelativeUriPathQualified $parsedPath.RelativeUri $context
    }

    $contextReady = ($::.GraphManager |=> GetMetadataStatus $context) -eq [MetadataStatus]::Ready

    $location = if ( $contextReady -or ( ! $automounted -and ! $Force.IsPresent ) ) {
        $lastUriSegment = $::.SegmentHelper |=> UriToSegments $parser $absolutePath | select -last 1
        $locationClass = ($lastUriSegment.graphElement |=> GetEntity).Type
        if ( ! $::.SegmentHelper.IsValidLocationClass($locationClass) ) {
            throw "The path '$Uri' of class '$locationClass' is a method or other invalid location"
        }
        $lastUriSegment
    } else {
        write-warning "-Force option specified or automount not disallowed and metadata is not ready, will force location change to root ('/')"
        new-so GraphSegment $::.EntityVertex.RootVertex
    }

    $context |=> SetLocation $location
    $::.GraphContext |=> SetCurrentByName $context.name

    __AutoConfigurePrompt $context
}

$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphLocation Uri (new-so GraphUriParameterCompleter ([GraphUriCompletionType]::LocationUri))
$::.ParameterCompleter |=> RegisterParameterCompleter Set-GraphLocation TypeName (new-so TypeUriParameterCompleter TypeName)

