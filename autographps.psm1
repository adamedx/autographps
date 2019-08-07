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

. (join-path $psscriptroot src/graph.ps1)

$functions = @(
    'Find-GraphPermissions',
    'Get-Graph',
    'Get-GraphChildItem',
    'Get-GraphLocation',
    'Get-GraphType',
    'Get-GraphUri',
    'New-Graph',
    'Remove-Graph',
    'Set-GraphLocation',
    'Set-GraphPrompt',
    'Show-GraphHelp',
    'Update-GraphMetadata'
)

$aliases = @('gcd', 'gg', 'ggu', 'gls', 'gwd')

export-modulemember -function $functions -alias $aliases
