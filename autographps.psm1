# Copyright 2020, Adam Edwards
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
    'Add-GraphRelatedItem',
    'Find-GraphPermission',
    'Get-Graph',
    'Get-GraphItem',
    'Get-GraphItemRelationship',
    'Get-GraphRelatedItem',
    'Get-GraphItemUri',
    'Get-GraphChildItem',
    'Get-GraphResourceWithMetadata',
    'Get-GraphLocation',
    'Get-GraphType',
    'Get-GraphUri',
    'Get-GraphUriInfo',
    'Invoke-GraphMethod',
    'New-Graph',
    'New-GraphItem',
    'New-GraphItemRelationship',
    'New-GraphMethodParameterObject',
    'New-GraphObject',
    'Remove-Graph',
    'Remove-GraphItem',
    'Remove-GraphItemRelationship',
    'Set-GraphItem',
    'Set-GraphLocation',
    'Set-GraphPrompt',
    'Show-GraphHelp',
    'Update-GraphMetadata'
)

$aliases = @('gcd', 'gg', 'ggrel', 'ggreli', 'ggu', 'ggci', 'ggi', 'gls', 'gwd', 'gni', 'grm', 'gsi', 'igm', 'ngo', 'ngp')

# Note that in order to make variables from nested modules
# accessible without the user directly invoking them,
# we need to "forward" them by exporting them even
# though they come from a module other than this one.
$variables = @(
    'GraphAutoPromptPreference'
    'GraphMetadataPreference'
    'GraphPromptColorPreference'
    'GraphVerboseOutputPreference' # From AutoGraphPS-=SDK
    'LastGraphItems'               # From AutoGraphPS-=SDK
)

export-modulemember -function $functions -alias $aliases -variable $variables


