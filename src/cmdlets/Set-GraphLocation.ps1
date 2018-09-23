# Copyright 2018, Adam Edwards
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
. (import-script common/GraphUriCompletionHelper)

function Set-GraphLocation {
    [cmdletbinding()]
    param(
        [parameter(position=0, valuefrompipeline=$true, mandatory=$true)]
        $UriPath = $null,
        [switch] $Force,
        [switch] $NoAutoMount
    )

    $inputUri = if ( $UriPath -is [String] ) {
        $UriPath
    } elseif ( $UriPath | gm -membertype scriptmethod '__ItemContext' ) {
        ($UriPath |=> __ItemContext | select -expandproperty RequestUri)
    } elseif ( $UriPath | gm Path ) {
        $UriPath.path
    } else {
        throw "UriPath must be a valid location string or object with a path / Uri"
    }

    $ParsedPath = $::.GraphUtilities |=> ParseLocationUriPath $inputUri

    $currentContext = $::.GraphContext |=> GetCurrent

    $automounted = $false
    $context = if ( $ParsedPath.ContextName ) {
        $pathContext = 'LogicalGraphManager' |::> Get |=> GetContext $ParsedPath.ContextName

        if ( ! $pathContext -and ! $NoAutoMount.IsPresent ) {
            $pathContext = try {
                write-verbose "Graph name '$($ParsedPath.ContextName)' was specified but no such graph is mounted"
                write-verbose "Attempting to auto-mount Graph version '$($ParsedPath.ContextName)' using the existing connection"
                $::.LogicalGraphManager |=> Get |=> NewContext $null $currentContext.connection $ParsedPath.ContextName $ParsedPath.ContextName
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
        throw "Cannot set current location using graph '$($ParsedPath.ContextName)' because it is not mounted or there is no current context. Try using the New-Graph cmdlet to mount it."
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
            throw "The path '$UriPath' of class '$locationClass' is a method or other invalid location"
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

$::.ArgumentCompletionHelper |=> RegisterArgumentCompleter Set-GraphLocation UriPath ([GraphUriCompletionType]::LocationUri)

