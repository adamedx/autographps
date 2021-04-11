# Copyright 2019, Adam Edwards
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

function Set-GraphLocation {
    [cmdletbinding(defaultparametersetname='path')]
    param(
        [parameter(position=0, parametersetname = 'path', valuefrompipelinebypropertyname=$true, mandatory=$true)]
        [Alias('Path')]
        $Uri = $null,

        [parameter(parametersetname='index', mandatory=$true)]
        [int] $Index,

        [switch] $Force,

        [parameter(parametersetname='path')]
        [switch] $NoAutoMount,

        [string] $GraphName
    )

    Enable-ScriptClassVerbosePreference

    $inputUri = if ( $Uri ) {
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

