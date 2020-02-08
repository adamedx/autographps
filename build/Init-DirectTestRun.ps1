# Copyright 2019, Adam Edwards
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
param()

. "$psscriptroot/common-build-functions.ps1"

$testDir = join-path (Get-SourceRootDirectory) test/CI
$testInitPath = join-path $testDir PesterDirectRunInit.ps1

$devDirectory = Get-DevModuleDirectory
$newpsmodulepath = $devDirectory + $OSPathSeparator + (gi env:PSModulePath).value
si env:PSModulePath $newpsmodulepath
write-verbose "Updated PSModulePath environment variable to '$newpsmodulepath'"

if ( test-path $testInitPath ) {
    write-verbose "Found init script '$testInitPath', will execute it"
    . $testInitPath
} else {
    write-verbose "No init script found at '$testInitPath', skipping direct test run init"
}

