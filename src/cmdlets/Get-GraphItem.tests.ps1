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

set-strictmode -version 2

. (join-path $psscriptroot ../../test/common/GetParameterTestFunction.ps1)

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


Describe 'The Get-GraphItem command parameterbinding behavior' -tag parameterbinding {
    Context 'When binding parameters with validation that is only possible if powershell is launched as non-interactive' {
        BeforeAll {
            GetParameterTestFunction Get-GraphItem | new-item function:Get-GraphItemTest
            $contentObject = [PSCustomObject] @{Id='objectid'}
            $standardObject = [PSCustomObject] @{
                Id = 'objectid'
                Content = $contentObject
                FullTypeName = 'sometypename'
                GraphName = 'somegraph'
            }
        }

        It "Should bind to the typeandid parameter set when type, id, and property are specified as named" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                Get-GraphItemTest -typename type1 -id id -property propname | select -expandproperty ParameterSetName | should be 'bytypeandid'
            }
        }

        It "Should bind to the typeandid parameter set when type, id, and property are specified as named" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                Get-GraphItemTest -typename type1 -id id -property propname | select -expandproperty ParameterSetName | should be 'bytypeandid'
            }
        }

        It "Should bind to the byuri parameter set when the first parameter is positional and no id parameter is specified" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = Get-GraphItemTest me -property propname

                $bindingInfo.ParameterSetName | Should Be 'byuri'
                $bindingInfo.BoundParameters['Uri'] | Should Be 'me'
            }
        }


        It "Should bind to the byobject parameterset when an unwrapped object is specified to the pipeline and the property parameter s specified by name" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = $contentObject | Get-GraphItemTest -property propname

                $bindingInfo.parametersetname | Should Be 'byobject'
                $bindingInfo.BoundParameters['GraphItem'].Id | Should Be $contentObject.Id
            }
        }

        It "Should bind to the byobject parameterset when a wrapped object is specified to the pipeline and the property parameter is specified by name" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = $standardObject | Get-GraphItemTest -property propname

                $bindingInfo.parametersetname | Should Be 'byobject'
                $bindingInfo.BoundParameters['GraphItem'].Id | Should Be $standardObject.Id
            }
        }

        It "Should bind to the bytypeandid parameterset when a type is specified as positional and id, and property are named" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = Get-GraphItemTest user -id userid -property propname

                $bindingInfo.parametersetname | Should Be 'bytypeandid'

                $bindingInfo.BoundParameters['Id'] | Should Be 'userid'
                $bindingInfo.BoundParameters['TypeName'] | Should Be 'user'
                $bindingInfo.BoundParameters['Property'] | Should Be 'propname'
            }
        }
    }
}



