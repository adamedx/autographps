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

. (import-script GraphErrorRecorder)

function Get-GraphError {
    [cmdletbinding()]
    param()
    $graphErrors = $::.GraphErrorRecorder |=> GetLastRecordedErrors

    $afterTimeUtc = $graphErrors.AfterTimeUtc
    $afterTimeLocal = $graphErrors.AfterTimeLocal

    $graphErrors.ErrorRecords | foreach {
        $headerOutput = @{}
        $errorValue = $_.ErrorRecord
        $responseStream = $_.ResponseStream
        $headers = $errorValue.exception.response.headers

        if ( $headers -ne $null ) {
            $headers.keys | foreach {
                $headerOutput[$_] = $headers[$_]
            }
        }

        [PSCustomObject] (
            [ordered] @{
                AfterTimeLocal = $afterTimeLocal
                AfterTimeUtc = $afterTimeUtc
                PSErrorRecord = $errorValue
                Response = [PSCustomObject] $errorValue.Exception.Response
                ResponseHeaders = [PSCustomObject] $headerOutput
                ResponseStream = $_.ResponseStream
                StatusCode = $errorValue.Exception.Response.StatusCode
                StatusDescription = $errorValue.Exception.Response.StatusDescription
            }
        )
    }
}
