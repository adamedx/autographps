# Copyright 2017, Adam Edwards
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

ScriptClass RESTResponse {
    $statusCode = strict-val [int]
    $statusDescription = strict-val [string]
    $content = $null
    $headers = strict-val [HashTable]
    $images = strict-val [HashTable]
    $inputFields = strict-val [HashTable]
    $links = strict-val [HashTable]
    $rawContent = $null
    $rawContentLength = strict-val [int]

    function __initialize ( $webResponse ) {
        $this.statusCode = $webResponse.statusCode
        $this.statusDescription = $webResponse.statusDescription
        $this.rawContent = $webResponse.rawContent
        $this.rawContentLength = $webResponse.rawContentLength
        $this.headers = $webResponse.headers
        $this.content = $webResponse.content | convertfrom-json
        $this.images = $webResponse.images | convertfrom-json
        $this.inputFields = $webResponse.inputFields | convertfrom-json
        $this.links = $webResponse.links | convertfrom-json
    }
}
