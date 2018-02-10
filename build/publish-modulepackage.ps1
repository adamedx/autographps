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

[cmdletbinding()]
param($targetRepository = 'psgallery', $repositoryKeyFile = $null, [switch] $noclean, [switch] $force)

. "$psscriptroot/common-build-functions.ps1"

$moduleManifestPath = Get-ModuleManifestPath
$moduleOutputRootDirectory = Get-ModuleOutputRootDirectory

Generate-ReferenceModules $moduleManifestPath $moduleOutputRootDirectory

$module = Get-ModuleFromManifest $moduleManifestPath $moduleOutputRootDirectory

$moduleOutputPath = join-path (Get-OutputDirectory) "$moduleOutputSubdirectory/$($module.name)/$($module.version)"

write-host "Publishing module at '$moduleOutputPath' to PS module repository '$targetRepository'..."

$repositoryKey = if ( $repositoryKeyFile -ne $null ) {
    Get-RepositoryKeyFromFile $repositoryKeyFile
}

$forceArgument = @{force=$force}

publish-modulebuild $moduleOutputPath $targetRepository $repositoryKey @forceArgument | out-null

write-host "Module '$($module.name)' successfully published to repository $targetRepository."
write-host -foregroundcolor green "Publish module succeeded."
