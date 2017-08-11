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

function ValidateIncludePath($includePath) {
    if ( $includePath.StartsWith("/") -or $includePath.StartsWith("\\") ) {
        throw "Path specified to include-source '$includePath' started with a path separator which is not allowed -- only relative paths may be specified"
    }

    if ( $includePath.StartsWith(".") ) {
        throw "Path specified to include-source '$includePath' started with the forbidden character '.'"
    }

    if ( $includePath.Contains("..") ) {
        throw "Path specified to include-source '$includePath' may not contain '..' in the path"
    }
}

function include-source($appRelativePath)
{
    ValidateIncludePath($appRelativePath)
    $relativePath = "$($appRelativePath).ps1"
    $relativeNormal = $relativePath.ToLower()
    $fullPath = (join-path $global:ApplicationRoot $relativePath | get-item).Fullname
    $canonical = $fullPath.ToLower()
    if ( $global:included[$canonical] -eq $null )
    {
        $global:included[$canonical] = @($global:ApplicationRoot, $relativeNormal)
        $global:includes[$canonical] = $false
    }
}

