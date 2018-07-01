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

. (import-script RESTResponse)

ScriptClass GraphErrorRecorder {
    static {
        $errorObjectCheckpoint = $null
        $recordingTimeUtc = $null
        $recordingTimeLocal = $null

        function StartRecording() {
            $this.errorObjectCheckpoint = if ( $error.count -gt 0 ) {
                $error[0].gethashcode()
            } else {
                $error.gethashcode()
            }

            write-verbose "Setting error checkpoint to object hash $($this.errorObjectCheckpoint)"

            $this.recordingTimeUtc = [DateTime]::UtcNow
            $this.recordingTimeLocal = [DateTime]::Now
        }

        function GetLastRecordedErrors() {
            $result = @{
                AfterTimeUtc = $this.recordingTimeUtc
                AfterTimeLocal = $this.recordingTimeLocal
                ErrorRecords = @()
            }

            if ( $this.errorObjectCheckpoint -eq 0 ) {
                return @()
            }

            write-verbose "Searching for errors until checkpoint $($this.errorObjectCheckpoint)"

            $errorCount = $error.count
            $currentError = 0
            $errorsProcessed = 0

            while ( $currentError -lt $errorCount ) {
                $errorValue = $error[$currentError]
                $errorsProcessed++
                if ( $errorValue.Gethashcode() -eq $this.errorObjectCheckpoint ) {
                    write-verbose  "Found error checkpoint -- terminating error search at error index $currentError"
                    break
                }

                if ( ($errorValue | select exception).psobject.properties.value -ne $null ) {
                    if ( $errorValue.targetobject -is [PSCustomObject]) {
                        $typeName = ($errorValue.targetObject | select CustomTypeName).psobject.properties.value
                        if ( $typeName -ne $null -and $errorValue.targetObject.CustomTypeName -eq 'RESTException' ) {
                            $responseStream = $errorValue.TargetObject.ResponseStream
                            $result.ErrorRecords += @{ErrorRecord=$errorValue.TargetObject.PSErrorRecord;ResponseStream=$responseStream}
                        }
                    }
                }
                $currentError++
            }



            write-verbose "Processed $errorsProcessed errors out of $errorCount total errors."
            $result
        }
    }


}
