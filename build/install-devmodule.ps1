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

[cmdletbinding()]
param($scope = 'CurrentUser')

. "$psscriptroot/common-build-functions.ps1"

$moduleName = Get-ModuleName
$repository = get-temporarymodulepsrepository $moduleName (Get-DevRepoDirectory)

try {
    install-module $moduleName -repository $repository -scope $scope -verbose -force
} finally {
    unregister-psrepository $repository
}

write-host "Successfully installed module '$moduleName' with scope '$scope'."
write-host -foregroundcolor yellow "You may need to restart PowerShell for changes to take effect."
write-host -foregroundcolor green "Installation succeeded."

