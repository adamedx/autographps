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

. (import-script Get-Graph)

if ( get-variable __graphOriginalPrompt -erroraction ignore ) {
    if ( $__GraphOriginalPrompt ) {
        set-item function:prompt -value $__GraphOriginalPrompt
    }
}

$__GraphOriginalPrompt = $null

$GraphPromptColorPreference = $null

$__GraphPromptColorSetting = $null
$__GraphPromptBehaviorSetting = $null

function __GetGraphDefaultPrompt {
    {
        $graph = get-graph ($::.GraphContext |=> GetCurrent).name -erroraction ignore
        $userToken = if ( $graph ) { $graph.details.connection.identity.token }

        $userOutput = $null
        $locationOutput = $null
        $connectionStatus = $null

        if ( $graph ) {
            $identity = $graph.details.connection.identity
            $identityOutput = if ( $graph.details.connection.identity.app.authtype -eq 'Delegated' ) {
                if ($userToken) {
                    $graph.userId
                }
            } else {
                $tid = if ( $identity.TenantDisplayName ) {
                    $identity.TenantDisplayName
                } else {
                    $identity.TenantDisplayId
                }

                $tenantData = if ( $tid ) {
                    'tid=' + $tid
                }

                $tenantData
            }

            $promptOutput = @()

            if ( $identityOutput ) {
                $promptOutput += $identityOutput
            }

            $appOutput = 'app=' + $identity.app.appid
            $promptOutput += $appOutput
            $connectionOutput = '[{0}] ' -f ($promptOutput -join ', ')

            $versionOutput = 'ver=' + $graph.version
            $locationOutput = $versionOutput + (": /{0}:{1}" -f $graph.name, $graph.currentlocation.graphuri)
            $connectionStatus = if ( $graph.ConnectionStatus.tostring() -ne 'Online' ) { "({0}) " -f $graph.ConnectionStatus }

        }

        if ( $connectionOutput -or $locationOutput ) {

            $promptColor = if ( $GraphPromptColorPreference ) {
                $GraphPromptColorPreference }
            elseif ( $__GraphPromptColorSetting ) {
                $__GraphPromptColorSetting
            } else {
                'darkgreen'
            }

            write-host -foreground $promptColor "$($connectionOutput)$($connectionStatus)`n$($locationOutput)"
        }
    }
}

$__GraphCurrentPrompt = $null

function __GetGraphPrompt {
    {
        if ( $__GraphCurrentPrompt ) {
            . $__GraphCurrentPrompt | out-null
        }

        if ( $__GraphOriginalPrompt ) {
            . $__GraphOriginalPrompt
        }

    }
}

function __ConfigurePrompt($behavior, $promptScript) {
    $originalPromptValue = try {
        $script:__GraphOriginalPrompt
    } catch {
    }

    if ( $behavior -eq 'Disable' ) {
        if ( $originalPromptValue ) {
            set-item function:prompt -value $script:__GraphOriginalPrompt
            $script:__GraphOriginalPrompt = $null
        }
    } elseif ( $behavior -eq 'Enable' ) {
        $script:__GraphCurrentPrompt = if ( $promptScript ) {
            $promptScript
        } else {
            __GetGraphDefaultPrompt
        }

        if ( ! $originalPromptValue ) {
            $script:__GraphOriginalPrompt = (get-item function:prompt).ScriptBlock
        }

        set-item function:prompt -value (__GetGraphPrompt)
    }
}

function Set-GraphPrompt {
    [cmdletbinding(positionalbinding=$false)]
    param (
        [parameter(position=0, mandatory=$true)]
        [ValidateSet('Auto', 'Enable', 'Disable')]
        [string] $Behavior,

        [ScriptBlock] $PromptScript = $null
    )

    Enable-ScriptClassVerbosePreference

    $script:__GraphPromptBehaviorSetting = $Behavior

    __ConfigurePrompt $Behavior $PromptScript
}
