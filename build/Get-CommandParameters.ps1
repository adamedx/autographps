# Copyright 2021, Adam Edwards
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
param(
    [parameter(valuefrompipeline=$true)]
    [string] $commandName
)
begin {
    $targetModuleName = (join-path $psscriptroot .. | gi).name
    $module = Get-Module $targetModuleName -listavailable

    if ( ! $module ) {
        throw "This command must be executed from a PowerShell session that has successfully imported the module '$targetModuleName'"
    }
}

process {
    Set-StrictMode -Version 2

    $commandList = if ( ! $commandName ) {
        $module.exportedfunctions.keys
    } else {
        @($commandName)
    }

    foreach ( $command in $commandList ) {
        $commandData = Get-Command $command
        $parameters = $commandData.parameters.keys
        [PSCustomobject] @{
            Command = $command
            ParameterCount = ( $parameters | measure-object ).count
            Parameters = $parameters
        }
    }
}

end {
}
