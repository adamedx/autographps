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

param($targetRepository = 'psgallery', $targetDirectory = $null, [switch] $noclean, [switch] $force)

. "$psscriptroot/common-build-functions.ps1"

$moduleOutputPath = Get-ModuleOutputDirectory

write-host "Publishing module at '$moduleOutputPath' to PS module repository '$targetRepository'..."

$forceArgument = @{force=$force}

publish-modulebuild $moduleOutputPath $targetRepository @forceArgument

write-host -foregroundcolor green "Publish succeeded."
