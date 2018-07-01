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

$cmdlets = @(
    'Disconnect-Graph',
    'Connect-Graph',
    'Get-Graph',
    'Get-GraphChildItem',
    'Get-GraphConnectionStatus',
    'Get-GraphError',
    'Get-GraphItem',
    'Get-GraphLocation',
    'Get-GraphSchema',
    'Get-GraphToken',
    'Get-GraphUri',
    'Get-GraphVersion',
    'Invoke-GraphRequest',
    'New-Graph',
    'New-GraphConnection',
    'Remove-Graph',
    'Set-GraphConnectionStatus',
    'Set-GraphLocation',
    'Set-GraphPrompt',
    'Test-Graph',
    'Update-GraphMetadata'
)

export-modulemember -cmdlet $cmdlets
