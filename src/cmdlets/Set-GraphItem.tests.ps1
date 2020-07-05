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
. (join-path $psscriptroot ../../test/common/NoninteractiveSubtestHelper.ps1)

Describe 'The Set-GraphItem command parameterbinding behavior' -tag parameterbinding {
    Context 'When binding parameters with validation that is only possible if powershell is launched as non-interactive' {
        BeforeAll {
            GetParameterTestFunction Set-GraphItem | new-item function:Set-GraphItemTest
            $contentObject = [PSCustomObject] @{Id='objectid'}
            $standardObject = [PSCustomObject] @{
                Id = 'objectid'
                Content = $contentObject
                FullTypeName = 'sometypename'
                GraphName = 'somegraph'
            }
        }

        It "Should bind to the typeandid parameter set when type, id, property, and value are specified as named" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                Set-GraphItemTest -typename type1 -id id -property propname -value valname| select -expandproperty ParameterSetName | should be 'bytypeandid'
            }
        }

        It "Should bind to the typeandid parameter set when type, id, property, and value are specified as named" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                Set-GraphItemTest -typename type1 -id id -property propname -value valname| select -expandproperty ParameterSetName | should be 'bytypeandid'
            }
        }

        It "Should bind to the byuri parameter set when the first parameter is positional and no id parameter is specified" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = Set-GraphItemTest me -property propname -value valname

                $bindingInfo.ParameterSetName | Should Be 'byuri'
                $bindingInfo.BoundParameters['Uri'] | Should Be 'me'
            }
        }


        It "Should bind to the byobject parameterset when an unwrapped object is specified to the pipeline and value and property parameters are specified by name" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = $contentObject | Set-GraphItemTest -property propname -value valname

                $bindingInfo.parametersetname | Should Be 'byobject'
                $bindingInfo.BoundParameters['GraphItem'].Id | Should Be $contentObject.Id
            }
        }

        It "Should bind to the byobject parameterset when a wrapped object is specified to the pipeline and value and property parameters are specified by name" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = $standardObject | Set-GraphItemTest -property propname -value valname

                $bindingInfo.parametersetname | Should Be 'byobject'
                $bindingInfo.BoundParameters['GraphItem'].Id | Should Be $standardObject.Id
            }
        }

        It "Should bind to the byobject parameterset when a wrapped object is specified to the pipeline and no other parameters are specified" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = $standardObject | Set-GraphItemTest

                $bindingInfo.parametersetname | Should Be 'byobject'
                $bindingInfo.BoundParameters['GraphItem'].Id | Should Be $standardObject.Id
            }
        }

        It "Should bind to the byobject parameterset when a wrapped object is specified to the pipeline and the MergeGraphItemWithPropertyTable and PropertyTable parameters are specified" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = $standardObject | Set-GraphItemTest -MergeGraphItemWithPropertyTable -PropertyTable @{prop3='propval3'}

                $bindingInfo.parametersetname | Should Be 'byobject'
                $bindingInfo.BoundParameters['GraphItem'].Id | Should Be $standardObject.Id
                $bindingInfo.BoundParameters['MergeGraphItemWithPropertyTable'].IsPresent | Should Be $true
                $bindingInfo.BoundParameters['PropertyTable']['prop3'] | Should Be 'propval3'
            }
        }

        It "Should bind to the bytypeandid parameterset when a type is specified as positional and id, property, and value are named" {
            $parameterSetTestsFinished | Should Not Be $null
            if ( ! $parameterSetTestsFinished ) {
                $bindingInfo = Set-GraphItemTest user -id userid -property propname -value valdata

                $bindingInfo.parametersetname | Should Be 'bytypeandid'

                $bindingInfo.BoundParameters['Id'] | Should Be 'userid'
                $bindingInfo.BoundParameters['TypeName'] | Should Be 'user'
                $bindingInfo.BoundParameters['Property'] | Should Be 'propname'
                $bindingInfo.BoundParameters['Value'] | Should Be 'valdata'
            }
        }
    }

    Context 'When invoking Set-GraphItem' {
        BeforeAll {
            $progresspreference = 'silentlycontinue'
            Update-GraphMetadata -Path "$psscriptroot/../../test/assets/microsoft-directoryservices-fragment.xml" -force -wait -warningaction silentlycontinue
        }

        It "Should throw an exception when value is specified but property is not specified" {
            { Set-GraphItem microsoft.graph.user -id id -value valnoprop | select -expandproperty ParameterSetName } | Should Throw "the Property parameter must also be specified"
        }

        It "Should throw an exception when Value is specified but has a larger size than Property" {
            { Set-GraphItem microsoft.graph.user -id id -property propname -value val1, val2 | select -expandproperty ParameterSetName } | Should Throw "must be less than the specified"
        }
    }
}

