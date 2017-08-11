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

function GetAssemblyRoot {
    $scriptRoot = $global:ApplicationRoot
    join-path -path $scriptRoot -childpath pkg
}

function FindAssembly($assemblyRoot, $assemblyName) {
    write-verbose "Looking for matching assembly for '$assemblyName' under path '$assemblyRoot'"
    $matchingAssemblyPaths = ls -r $assemblyRoot -Filter $assemblyName | sort -descending lastwritetime | where {$components = $_.fullname -split "\\"; $components[$components.length - 2] -eq 'net45' }

    if ($matchingAssemblyPaths -eq $null -or $matchingAssemblyPaths.length -lt 1) {
        throw "Unable to find assembly '$assemblyName' under root directory '$assemblyRoot'. Please re-run the installation command for this application and retry."
    }

    $matchingAssemblyPaths | foreach { write-verbose "Found possible assembly match for '$assemblyName' in '$_'" }

    $matchingAssemblyPaths[0].fullname
}

function LoadAssemblyFromRoot($assemblyRoot, $assemblyName) {
    $assemblyPath = FindAssembly $assemblyRoot $assemblyName
    write-verbose "Requested assembly '$assemblyName', loading assembly '$assemblyPath'"
    [System.Reflection.Assembly]::LoadFrom($assemblyPath) | Out-Null
}

function LoadLatestVersionOfAssembly($assemblyName) {
    LoadAssemblyFromRoot (GetAssemblyRoot) $assemblyName
}
