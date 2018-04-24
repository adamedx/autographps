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

ScriptClass ProgressWriter {
    static {
        function WriteProgress($activity, $status, $percentComplete, $currentOperation, $id, [switch] $completed) {
            $progressArguments = @{
                Activity = $activity
            }

            $statusMessage = if ( $status ) {
                $progressArguments['Status'] = $status
                ": $status"
            }

            $percentMessage = if ( $percentComplete ) {
                $progressArguments['PercentComplete'] = $percentComplete
                " - {0:d}% Complete" -f [int] $percentComplete
            }

            $operationMessage = if ( $currentOperation ) {
                $progressArguments['CurrentOperation'] = $currentOperation
                ", $currentOperation"
            }

            $messageId = if ( $id ) {
                $progressArguments['id'] = $id
                $id
            }

            $originalProgressPreference = $progressPreference
            $progressPreference = 'SilentlyContinue'
            write-progress @progressArguments
            $progressPreference = $originalProgressPreference

            if ( $originalProgressPreference -eq 'Continue' ) {
                $progressMessage = "{0}{1}{2}{3}" -f $activity, $statusMessage, $percentMessage, $operationMessage
                $outputMessage = if ( ! $completed.IsPresent ) {
                    $progressMessage
                } else {
                    ''
                }

                $width = try {
                    ((get-host).UI.RawUI.WindowSize).width
                } catch {
                }

                $trimmedMessage = if ( $width -and $outputMessage.length -gt $width ) {
                    $outputMessage.substring(0, $width - 4) + '...'
                } else {
                    $outputMessage
                }

                write-host -nonewline -backgroundcolor darkcyan -foregroundcolor yellow "`r$($trimmedMessage)"
                $padding = ''.padright($width - $trimmedMessage.length)
                write-host -nonewline $padding
                if ($completed.ispresent) {
                    write-host -nonewline "`r"
                }
            }
        }
    }
}
