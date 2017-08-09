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
$global:includes = @{}
$global:included = @{}

function include-source($scriptRelativePath)
{
    $relativePath = "$($scriptRelativePath).ps1"
    $relativeNormal = $scriptRelativePath.ToLower()
    $fullPath = (join-path $psscriptRoot $relativePath | get-item).Fullname
    $canonical = $fullPath.ToLower()
    if ( $global:included[$canonical] -eq $null )
    {
        $global:included[$canonical] = @($psscriptRoot, $relativeNormal)
        $global:includes[$canonical] = $false
    }
}

