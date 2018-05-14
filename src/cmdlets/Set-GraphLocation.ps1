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
        [parameter(position=0, valuefrompipeline=$true)]
        $UriPath = $null
    )

    $inputUri = if ($UriPath -is [PSCustomObject]) {
        $UriPath | select -expandproperty path
    } else {
        $UriPath
    }

    $ParsedPath = $::.GraphUtilities |=> ParseLocationUriPath $inputUri

    $currentContext = $false
    $context = if ( $ParsedPath.Context ) {
        'LogicalGraphManager' |::> Get |=> GetContext $ParsedPath.Context
    } else {
        $currentContext = $true
        $::.GraphContext |=> GetCurrent
    }

    if ( ! $context ) {
        throw "Cannot set location in the current context because no current context exists"
    }

    $parser = new-so SegmentParser $context

    $location = $::.SegmentHelper |=> UriToSegments $parser $ParsedPath.GraphRelativeUri | select -last 1

    if ( $currentContext ) {
        $context |=> SetLocation $location
    }
}
