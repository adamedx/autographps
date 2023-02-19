# Copyright 2023, Adam Edwards
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

. (import-script ../typesystem/TypeManager)
. (import-script common/TypeUriHelper)
. (import-script common/QueryTranslationHelper)
. (import-script common/GraphParameterCompleter)
. (import-script common/TypeParameterCompleter)
. (import-script common/TypePropertyParameterCompleter)
. (import-script common/TypeUriParameterCompleter)
. (import-script Get-GraphItem)


<#
.SYNOPSIS
Deletes a resource instance from the Graph.

.DESCRIPTION
Remove-GraphItem deletes resources from the Graph. It does this by issuing an HTTP DELETE method request against the resource's Graph URI. If the graph connection is signed-in with sufficient privileges to delete the resource, the command should succeed. Remove-GraphItem supports three ways of specifying the resource to delete:
    * Type name and Id: specify the resource's type and its id property. For many resources such as users, groups, and applications, this is sufficient to locate the URI for the object and then issue the DELETE method and provides a concise and convenient way to address resources. But for many resource types there is no canonical URI given that information and an error will result when the type name and id are specified for those resources. Use the command's TypeName and Id parameters for this scenario.
    * Explicit URI: Explicitly specifying the resource's URI will work for any resource instance. The URI may be specified by the command's Uri parameter.
    * Object: Specify a graph object retrieved with either the Get-GraphResource or Get-GraphResourceWithMetadata command. The GraphItem parameter is used in this case, and it may also be specified using the object pipeline to pipe objects into the command as input.

.PARAMETER Uri
The graph URI of the resource or resources to be deleted. The value for Uri must either be a the URI of a specific graph resource or a URI for a collection of resources. If it's the latter, then all of the resources in the collection are deleted. The set of deleted resources can be reduced using the Filter parameter. The Uri parameter follows the same rules as in other commands -- see the Get-GraphResourceWithMetadata command's documentation for Uri for details.

.PARAMETER TypeName
The type of the resource to delete. For example, if the target resource is of type user (more explicitly microsoft.graph.user), this parameter should be specified as 'user'. When this parameter is specified, either the Id parameter or Filter parameter must also be specified to identify the specific resources to delete. The command will attempt to identify a canonical URI for the resource with that type and identifier -- not all resources have such a unique URI, use of the TypeName and Id parameters is not supported for all resource types and will result in an error. For types that do not support htis pattern of addressing resources, determine the URI for the resource and specify it to the Uri parameter instead; the Uri parameter is supported for all resource types.

.PARAMETER Id
The id of the resource of a given type to delete. This parameter is specified only when the TypeName is specified. See the TypeName parameter documentation for more details.

.PARAMETER GraphItem
An object returned by Get-GraphResourceWithMetadata command or any command that outputs a deserialized object returned from a Graph API response. When GraphItem is specified, instead of the URI parameter being used to issue a request to the Graph API for the given command, the request URI is based on the URI that created the object represented by GraphItem.

.PARAMETER GraphName
Specifies the unique name of the graph on which the command should operate. This controls both the connection (e.g. identity and service endpoint) used to access the Graph API and also the API version used to interpret the Uri and TypeName parameters. When this parameter is unspecified, the current graph is used as a default.

.PARAMETER Filter
Specifies an optional OData query filter to narrow the set of resources to delete when the Uri parameter specifies a collection. Only the resources that satisfy the filter's criteria will be deleted. Visit https://docs.microsoft.com/en-us/graph/query-parameters?context=graph%2Fapi%2F1.0&view=graph-rest-1.0#filter-parameter or https://docs.oasis-open.org/odata/odata/v4.0/errata03/os/complete/part2-url-conventions/odata-v4.0-errata03-os-part2-url-conventions-complete.html#_Toc453752356 for details on the OData query syntax.

.PARAMETER FullyQualifiedTypeName
Controls how the TypeName parameter is interpreted. By default, the TypeName is treated as being optionally qualified, i.e. specifying 'user' or 'microsoft.graph.user' are treated as equivalent type names; when you specify 'user' the command will attempt to resolve the type by adding the appropriate default type namespace 'microsoft.graph' to the type name. If you specify the FullyQualifiedTypeName parameter, then specifying 'user' will result in an unresolved type name failure; the parameter in this case MUST be specified with the full type name 'microsoft.graph.user'.

.OUTPUTS
This command produces no output.

.EXAMPLE
Remove-GraphItem /users/

   Graph Location: /users/2b75ccf5-3214-4b5d-84c3-6492083c69b6

In this example the path to a user resource is specified and deleted by the command. By default, when positional parameters are used the first parameter is assumed to be the Uri of the resource to delete.

.EXAMPLE
Remove-GraphItem -TypeName user -Id 2b75ccf5-3214-4b5d-84c3-6492083c69b6

This case demonstrates deletion of the same resource as in the previous example, this time the TypeName 'user' is specified along with the id property of the object to delete. Because the type user has a canonical URI, the command is able to determine the resource URI from the parameters and delete the resource.

.EXAMPLE
gls /users/2b75ccf5-3214-4b5d-84c3-6492083c69b6 | Remove-GraphItem

In this example, the same user resource is deleted as in the above example, this time the pipeline is the source of the resource to delete. The Get-GraphResourceWithMetadata command is invoked via the gls alias to get the object to delete, and it is piped to Remove-GraphItem for deletion.

.EXAMPLE
Remove-GraphItem -TypeName group -Filter "startsWith(mailNickName, 'ProjectBeta-')"

In this example, all resources of type group that have a mailNickName property that starts with the prefix 'ProjectBeta-' are deleted.

.LINK
Get-GraphResourceWithMetadata
Get-GraphResource
Get-GraphItem
Get-GraphChilditem
#>
function Remove-GraphItem {
    [cmdletbinding(positionalbinding=$false, defaultparametersetname='byuri')]
    param(
        [parameter(parametersetname='byuri', mandatory=$true)]
        [Alias('GraphUri')]
        [Uri] $Uri,

        [parameter(position=0, parametersetname='bytypeandid', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [parameter(parametersetname='bytypeandfilter', mandatory=$true)]
        $TypeName,

        [parameter(position=1, parametersetname='bytypeandid', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        $Id,

        [parameter(parametersetname='byobject', valuefrompipeline=$true, mandatory=$true)]
        [parameter(parametersetname='byobjectandfilter', valuefrompipeline=$true, mandatory=$true)]
        [PSTypeName('GraphResponseObject')] $GraphItem,

        [parameter(parametersetname='byobject')]
        [parameter(parametersetname='byobjectandfilter')]
        [parameter(parametersetname='bytypeandid')]
        [parameter(parametersetname='bytypeandfilter')]
        $GraphName,

        [parameter(parametersetname='bytypeandfilter', mandatory=$true)]
        [parameter(parametersetname='byuri')]
        [parameter(parametersetname='byobjectandfilter', mandatory=$true)]
        $Filter,

        [HashTable] $Headers = $null,

        [switch] $FullyQualifiedTypeName
    )

    begin {
        Enable-ScriptClassVerbosePreference

        if ( $TypeName -and ( ! $Id -and ! $Filter ) ) {
            throw [ArgumentException]::new('The TypeName parameter was spcecified but no Filter or Id parameter was specified')
        }

        $filterParameter = @{}
        $filterValue = $::.QueryTranslationHelper |=> ToFilterParameter $null $Filter
        if ( $filterValue ) {
            $filterParameter['Filter'] = $filterValue
        }

        $coreParameters = @{}
        if ( $Headers ) {
            $coreParameters['Headers'] = $Headers
        }
    }

    process {
        $targetId = if ( $Id ) {
            $Id
        } elseif ( $GraphItem -and ( $GraphItem | get-member id -erroraction ignore ) ) {
            $GraphItem.Id
        }

        $requestInfo = $::.TypeUriHelper |=> GetTypeAwareRequestInfo $GraphName $TypeName $FullyQualifiedTypeName.IsPresent $Uri $targetId $GraphItem

        $objects = if ( $GraphItem ) {
            if ( $GraphItem | gm __ItemMetadata -erroraction ignore ) {
                $GraphItem.__ItemMetadata()
            } else {
                $GraphItem
            }
        } elseif ( $Filter ) {
            Get-GraphResource $requestInfo.Uri @filterParameter -erroraction stop
        }

        $targetUris = if ( $objects ) {
            foreach ( $targetObject in $objects ) {
                if ( ! ( $targetObject | gm id -erroraction ignore ) ) {
                    break
                }

                $::.TypeUriHelper |=> GetUriFromDecoratedObject $requestInfo.Context $targetObject
            }
        } elseif ( $Uri )  {
            $Uri
        } else {
            $requestInfo.Uri
        }

        if ( ! $targetUris -and ( ! $Filter -and ( $TypeName -or $Uri ) ) ) {
            throw "No resources could be found matching the specified resources"
        }

        foreach ( $targetUri in $targetUris ) {
            Invoke-GraphApiRequest $targetUri -Method DELETE @coreParameters -erroraction stop -connection $requestInfo.Context.Connection | out-null
        }
    }

    end {}
}

$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItem TypeName (new-so TypeUriParameterCompleter TypeName)
$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItem GraphName (new-so GraphParameterCompleter)
$::.ParameterCompleter |=> RegisterParameterCompleter Remove-GraphItem Uri (new-so GraphUriParameterCompleter LocationUri)

