# Copyright 2020, Adam Edwards
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

$shell = if ( $PSEdition -eq 'Desktop' ) {
    'powershell'
} else {
    'pwsh'
}

$parameterSetTestsFinished = $null


# This strange behavior is required because these tests try to trigger cases where mandatory parameters are not specified,
# which would normally hange the test. To avoid this, we relaunch just these tests in a non-interactive powershell.
# As long as all tests in this new powershell succeed, we record all of the tests in the instance that launched the
# sub-instance as successful. If one or more tests fails in the sub-instance, all those tests in this instance
# are marked as failed.
# TODO: get the detailed status from the instance and mark it only those tests that failed.
if ( ! ( get-variable ThisTestStarted -erroraction ignore ) ) {
    $command = "`$global:ThisTestStarted = `$true; invoke-pester -enableexit -tag parameterbinding -script '$($myinvocation.mycommand.source)'"
    & $shell -noninteractive -noprofile -command $command | out-host
    if ( $LASTEXITCODE -ne 0 ) {
        throw "Failed with exit code '$LASTEXITCODE'"
    }
    $parameterSetTestsFinished = $true
} else {
    $parameterSetTestsFinished = $false
}
