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

set-strictmode -version 2

$alreadyInitialized = try {
    get-variable -scope $script:IsStdLibInitialized
    $true
} catch {
    $false
}

if ($alreadyInitialized) {
    throw "This script file must only be sourced once from the entry script."
}

function script:ApplicationRoot {
    $psscriptRoot
}

. (join-path "$(ApplicationRoot)" "include.ps1")

$script:IsStdlibInitialized = $true
