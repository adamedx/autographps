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


Describe 'The New-GraphItem command parameterbinding behavior' -tag parameterbinding {
    Context 'When binding parameters with validation that is only possible if powershell is launched as non-interactive' {
        BeforeAll {
            GetParameterTestFunction New-GraphItem | new-item function:New-GraphItemTest
            $contentObject = [PSCustomObject] @{Id='objectid'}
            $standardObject = [PSCustomObject] @{
                Id = 'objectid'
                Content = $contentObject
                FullTypeName = 'sometypename'
                GraphName = 'somegraph'
            }
        }

        It "Should bind to the bytypeoptionallyqualified parameter set when type, property, and value are specified as named" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                New-GraphItemTest -typename type1 -property propname -value valname | select -expandproperty ParameterSetName | should be 'bytypeoptionallyqualified'
            }
        }

        It "Should bind to the byuri parameterset when the first parameter is named and the property and value parameters are specified" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = New-GraphItemTest -uri me -property propname -value valname

                $bindingInfo.ParameterSetName | Should Be 'byuri'
                $bindingInfo.BoundParameters['Uri'] | Should Be 'me'
            }
        }


        It "Should bind to the bytypeoptionallyqualifiedfromobject parameterset when an unwrapped object is specified to the pipeline and the type is specified by position" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = $contentObject | New-GraphItemTest user

                $bindingInfo.parametersetname | Should Be 'bytypeoptionallyqualifiedfromobject'
                $bindingInfo.BoundParameters['TemplateObject'].Id | Should Be $contentObject.Id
            }
        }

        It "Should bind to the bytypeoptionallyqualifiedfromobject parameterset when a wrapped object is specified to the pipeline and the type is specified by position" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = $standardObject | New-GraphItemTest user

                $bindingInfo.parametersetname | Should Be 'bytypeoptionallyqualifiedfromobject'
                $bindingInfo.BoundParameters['TemplateObject'].Id | Should Be $standardObject.Id
            }
        }

        It "Should bind to the bytypeoptionallyqualified parameterset when the type property, and value prameters are all positional" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = New-GraphItemTest user propname valdata

                $bindingInfo.parametersetname | Should Be 'bytypeoptionallyqualified'

                $bindingInfo.BoundParameters['TypeName'] | Should Be 'user'
                $bindingInfo.BoundParameters['Property'] | Should Be 'propname'
                $bindingInfo.BoundParameters['Value'] | Should Be 'valdata'
            }
        }
    }

    Context 'When invoking New-GraphItem' {
        BeforeAll {
            $progresspreference = 'silentlycontinue'
            Update-GraphMetadata -Path "$psscriptroot/../../test/assets/microsoft-directoryservices-fragment.xml" -force -wait -warningaction silentlycontinue
        }

        It "Should throw an exception when value is specified but property is not specified" {
            { New-GraphItem microsoft.graph.user -value valnoprop | select -expandproperty ParameterSetName } | Should Throw "the Property parameter must also be specified"
        }

        It "Should throw an exception when Value is specified but has a larger size than Property" {
            { New-GraphItem microsoft.graph.user -property propname -value val1, val2 | select -expandproperty ParameterSetName } | Should Throw "must be less than the specified"
        }
    }
}



