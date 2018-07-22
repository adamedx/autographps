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

function __GetGraphAccessDeniedExceptionMessage( [System.Net.WebException] $webException ) {
    $response = $webException.Response
    $graphUri = $response.ResponseUri.ToString()
    $statusCode = if ( $response | gm statuscode -erroraction silentlycontinue ) {
        $response.statuscode
    }

    "Graph endpoint returned http status '$statusCode' accessing '$graphUri'. Retry after re-authenticating via the 'Connect-Graph' cmdlet and requesting appropriate permission scopes for this application. See the following location for documentation on scopes that may apply to this part of the Graph: 'https://developer.microsoft.com/en-us/graph/docs/concepts/permissions_reference'."
}

class GraphAccessDeniedException : Exception {
    GraphAccessDeniedException( [System.Net.WebException] $originalException ) : base((__GetGraphAccessDeniedExceptionMessage $originalException), $originalException) { }
}
