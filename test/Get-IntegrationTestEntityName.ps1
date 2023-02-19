# Copyright 2022, Adam Edwards
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

[cmdletbinding()]
param (
    [parameter(parametersetname='entityname', mandatory=$true)]
    [string] $Name,

    [parameter(parametersetname='entityname')]
    [string] $TestId,

    [parameter(parametersetname='entityname')]
    [ValidateNotNullOrEmpty()]
    [string] $TestSuite,

    [parameter(parametersetname='entityname')]
    [ValidateNotNullOrEmpty()]
    [string] $Prefix,

    [parameter(parametersetname='prefixonly')]
    [switch] $PrefixOnly
)

$targetTestId = if ( $TestId ) {
    $TestId
} elseif ( $__IntegrationTest_TestId ) {
    $__IntegrationTest_TestId
} else {
    'Global'
}

$targetTestSuite = if ( $TestSuite ) {
    $TestSuite
} elseif ( $__IntegrationTest_TestId ) {
    $__IntegrationTest_TestSuite
} else {
    'Default'
}

$targetPrefix = if ( $Prefix ) {
    $Prefix
} elseif ( $__IntegrationTest_Prefix ) {
    $__IntegerationTest_Prefix
} else {
    '__INT_TEST'
}

if ( $PrefixOnly.IsPresent ) {
    $targetPrefix
} else {
    "targetPrefix-$targetTestSuite-$targetTestId-$Name"
}


