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

$__CompletionInProgress = $false

function Set-GraphLocation {
    [cmdletbinding()]
    param(
        <#
        [parameter(position=0, valuefrompipeline=$true, mandatory=$true)]
        $UriPath = $null,
        #>
        [switch] $Force
    )

    DynamicParam {
        # Note -- you can think of this as getting called every time you hit tab.
        # Unfortunately, there is no parameter to tell you what has been completed.
        # The assumption between PowerShell's DynamicParam design seems to be that
        # you can return *all* possible values efficiently. In our case, the best
        # we can do is get the immediate children of the current context -- even
        # one additional nested level results in an excessive delay.
        # Until we've optimized generation of all possible paths, we'll restrict
        # this to the first level
        $uribound = $psBoundParameters['UriPath']
        $boundParam = if ( ! $uribound ) {
            '/'
        } else {
            $psBoundParameters['UriPath']
        }
        if ( $boundParam -and $boundParam.length -gt 1 ) {
            throw 'yes'
        }
        $script:dyncounter | out-host
        $script:dyncounter++
        $script:argstack += $null
        $script:argstack[$script:argstack.length - 1] = $args

        $uris = $::.GraphUriCompletionHelper |=> GetChildUris $boundParam
#        $uris = @('me', 'drive', 'contacts', 'me/root', 'me/root/fun')
        Get-DynamicValidateSetParameter UriPath $uris -ParameterType ([object]) -SkipValidation:$Force.IsPresent -ParameterSets @(
            @{
                Position  = 0
                Mandatory = $true
            }
        )
    }

    begin {
        write-host 'finally: ', $script:dyncounter
        $script:dyncounter = 0
        $script:begincounter++
        <# Make a friendly local variable name for the parameter
        [parameter(position=0, valuefrompipeline=$true, mandatory=$true)]
        $UriPath = $null,
        #>
        $UriPath = $PsBoundParameters['UriPath']
    }

    process {
        $inputUri = if ( $UriPath -is [String] ) {
            $UriPath
        } elseif ( $UriPath | gm -membertype scriptmethod '__ItemContext' ) {
            ($UriPath |=> __ItemContext | select -expandproperty RequestUri)
        } elseif ( $UriPath | gm Path ) {
            $UriPath.path
        } else {
            throw "UriPath must be a valid location string or object with a path string or Uri"
        }

        $ParsedPath = $::.GraphUtilities |=> ParseLocationUriPath $inputUri

        $context = if ( $ParsedPath.ContextName ) {
            'LogicalGraphManager' |::> Get |=> GetContext $ParsedPath.ContextName
        } else {
            $::.GraphContext |=> GetCurrent
        }

        if ( ! $context ) {
            throw "Cannot set location in the current context because no current context exists"
        }

        $parser = new-so SegmentParser $context $null $true

        $absolutePath = if ( $parsedPath.IsAbsoluteUri ) {
            $parsedPath.RelativeUri
        } else {
            $::.LocationHelper |=> ToGraphRelativeUriPathQualified $parsedPath.RelativeUri $context
        }

        $contextReady = ($::.GraphManager |=> GetMetadataStatus $context) -eq [MetadataStatus]::Ready

        $location = if ( $contextReady -or ! $Force.IsPresent ) {
            $lastUriSegment = $::.SegmentHelper |=> UriToSegments $parser $absolutePath | select -last 1
            $locationClass = ($lastUriSegment.graphElement |=> GetEntity).Type
            if ( ! $::.SegmentHelper.IsValidLocationClass($locationClass) ) {
                throw "The path '$UriPath' of class '$locationClass' is a method or other invalid location"
            }
            $lastUriSegment
        } else {
            write-warning "-Force option specified and metadata is not ready, will force location change to root"
            new-so GraphSegment $::.EntityVertex.RootVertex
        }

        $context |=> SetLocation $location
        $::.GraphContext |=> SetCurrentByName $context.name

        __AutoConfigurePrompt $context
    }
}
