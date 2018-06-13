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

. (import-script ../GraphContext)
. (import-script Get-Graph)

if ( get-variable __graphOriginalPrompt -erroraction silentlycontinue ) {
    if ( $__GraphOriginalPrompt ) {
        set-item function:prompt -value $__GraphOriginalPrompt
    }
}

$__GraphOriginalPrompt = $null

$__GraphDefaultPrompt = {
    $graph = get-graph ($::.GraphContext |=> GetCurrent).name
    $userToken = $graph.details.connection.identity.token

    $userOutput = $null
    $locationOutput = $null
    $connectionStatus = $null

    if ( $graph ) {
        $userOutput = if ( $userToken ) { "[{0}] " -f $graph.details.connection.identity.token.user.displayableid }
        $locationOutput = "{0}:{1}" -f $graph.name, $graph.currentlocation.graphuri
        $connectionStatus = if ( $graph.ConnectionStatus.tostring() -ne 'Online' ) { "({0}) " -f $graph.ConnectionStatus }
    }

    if ( $userOutput -or $locationOutput ) {
        write-host -foreground darkgreen "$($userOutput)$($connectionStatus)$($locationOutput)"
    }
}

$__GraphCurrentPrompt = $null

$__GraphPrompt = {
    if ( $__GraphCurrentPrompt ) {
        . $__GraphCurrentPrompt | out-null
    }

    if ( $__GraphOriginalPrompt ) {
        . $__GraphOriginalPrompt
    }
}

function Set-GraphPrompt {
    [cmdletbinding(positionalbinding=$false)]
    param (
        [parameter(parametersetname='Enable')]
        [switch] $Enabled,

        [parameter(position=0, parametersetname='Enable')]
        [ScriptBlock] $PromptScript = $null,

        [parameter(parametersetname='Disable')]
        [switch] $Disabled
    )
    if ( $Disabled.IsPresent ) {
        if ( $script:__GraphOriginalPrompt ) {
            set-item function:prompt -value $script:__GraphOriginalPrompt
            $script:__GraphOriginalPrompt = $null
        }
    } elseif ( $Enabled.IsPresent ) {
        $script:__GraphCurrentPrompt = if ( $PromptScript ) {
            $PromptScript
        } else {
            $script:__GraphDefaultPrompt
        }

        if ( ! $script:__GraphOriginalPrompt ) {
            $script:__GraphOriginalPrompt = (get-item function:prompt).ScriptBlock
        }

        set-item function:prompt -value $script:__GraphPrompt
    } else {
        throw [ArgumentException]::new("Neither 'Enabled' or 'Disabled' options was specified for the command")
    }
}
