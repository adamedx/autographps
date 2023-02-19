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
param($targetDirectory = $null, [switch] $noclean, [switch] $DownloadDependencies)

. "$psscriptroot/common-build-functions.ps1"

if ( $DownloadDependencies.ispresent ) {
    $installScriptPath = join-path (get-sourcerootdirectory) 'build\install.ps1'
    & $installScriptPath | out-null
}

$moduleManifestPath = Get-ModuleManifestPath
$moduleOutputDirectory = new-moduleoutputdirectory $targetDirectory (! $noclean.ispresent)
$moduleOutputRootDirectory = Get-ModuleOutputRootDirectory

Generate-ReferenceModules $moduleManifestPath $moduleOutputRootDirectory

$module = Get-ModuleFromManifest $moduleManifestPath $moduleOutputRootDirectory

$inputs = @(
    $module,
    $moduleOutputDirectory
)

$nocleanArgument = @{noclean=$noclean}
$moduleOutputPath = build-module $inputs[0] $inputs[1] @nocleanArgument -includeInstalledlibraries

write-host "Module placed at '$moduleOutputPath'."

write-host -foregroundcolor green "Build succeeded."

