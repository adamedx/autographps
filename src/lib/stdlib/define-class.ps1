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
$existing_classes = @{}
$define_class = {
    function __new {
        new-object $thisTypeName -argumentlist $args
    }

    $thisType = $null
    $thisTypeName = (get-pscallstack)[1].command
    $existingType = $existing_classes[$thisTypeName]
    if ($existingType -eq $null ) {
        $thisType = invoke-expression "[$thisTypeName]"
        $existing_classes[$thisTypeName] = $thisType
    } else {
        $thisType = $existingType
    }

    if ($method -eq $null) {
        if ($args.length -gt 0) {
            throw [ArgumentException]::new("Arguments were specified without a method")
        }
        $thisType
    } else {
        if ($args.length -gt 0 -and $method -ne '__new' -and $args[0].Gettype().name -ne $thisType.name) {
            throw [InvalidCastException]::new("Mismatch type '$($args[0].gettype())' supplied when type '$thisType' was required`n$(get-pscallstack)")
        }
        $scriptblock = (get-item (join-path -path "function:" -child $method)).scriptblock
        $result = try {
            $scriptblock.invokereturnasis($args)
        } catch {
            get-pscallstack | out-host
            throw
        }
        $result
    }
}
