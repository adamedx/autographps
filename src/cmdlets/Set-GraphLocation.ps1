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

. (import-script ../LogicalGraphManager)
. (import-script ../common/GraphUtilities)
. (import-script ../metadata/SegmentParser)
. (import-script common/SegmentHelper)

function Set-GraphLocation {
    [cmdletbinding()]
    param(
        [parameter(position=0, valuefrompipeline=$true, mandatory=$true)]
        $UriPath = $null
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

    $context = if ( $ParsedPath.Context ) {
        'LogicalGraphManager' |::> Get |=> GetContext $ParsedPath.Context
    } else {
        $::.GraphContext |=> GetCurrent
    }

    if ( ! $context ) {
        throw "Cannot set location in the current context because no current context exists"
    }

    $parser = new-so SegmentParser $context

    $absolutePath = if ( $parsedPath.IsAbsoluteUri ) {
        $parsedPath.GraphRelativeUri
    } else {
        $::.GraphUtilities |=> ToGraphRelativeUriPath $parsedPath.GraphRelativeUri $context
    }

    $location = $::.SegmentHelper |=> UriToSegments $parser $absolutePath | select -last 1

    $locationClass = $location.graphElement.GetEntity().Type
    if ( ! $::.SegmentHelper.IsValidLocationClass($locationClass) ) {
        throw "The path '$UriPath' of class '$locationClass' is a method or other invalid location"
    }

    $context |=> SetLocation $location
    $::.GraphContext |=> SetCurrentByName $context.name
}
