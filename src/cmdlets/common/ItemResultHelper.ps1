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

$__DefaultResultVariableName = 'LastGraphItems'
$__DefaultResultVariable = new-variable $__DefaultResultVariableName -scope script -passthru -force

function __GetResultVariable( $customVariableName ) {
    if ( ! $customVariableName ) {
        $__DefaultResultVariable.value = $null
        $__DefaultResultVariable
    } else {
        $existingVariable = get-variable -scope 2 $customVariableName -erroraction silentlycontinue

        if ( $existingVariable ) {
            $existingVariable
        } else {
            new-variable -scope 2 $customVariableName -passthru
        }
    }
}
