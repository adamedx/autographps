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

<#
.SYNOPSIS
Sets the behavior of the Graph information added to the PowerShell prompt.

.DESCRIPTION
Use Set-GraphPrompt to enable or disable the addition of information about the current Graph location added to the PowerShell prompt. By default, when the Set-GraphLocation command (alias gcd) is invoked, or when the Get-GraphResourceWithMetadata command (alias gls) enumerates relationships, the PowerShell prompt is modified to include information about the current location, including its full path with graph name, the API version of the graph, and the connection used to access the graph. This information is prepended to the existing prompt. See the NOTES section for details on how the data are presented in the prompt.

Set-GraphPrompt provides a Behavior parameter that can enable or disable the prompt behavior, as well as the default 'Auto' setting that adds prompt information only under the specific conditions described earlier.

.PARAMETER Behavior
Specify the Behavior parameter to enable or disable the addition of Graph information to the PowerShell prompt. By default, the parameter is set to 'Auto', which means the prompt information will only be added as needed, specifically if the current location is changed or if the Get-GraphResourceWithMetadata command is invoked. If the value is 'Enabled', then prompt information is always displayed. If the value is 'Disabled', there is no graph information added to the prompt.

.PARAMETER PromptScript
Specify PromptScript to customize the Graph information shown by the prompt. By default, the prompt displays a specific set of information such as the name of the graph, the version, the application used to access it, and the organization id. To display arbitrary information, specify a ScriptBlock for the PromptScript parameter.

.OUTPUTS
This command produces no output.

.NOTES

Connection information is presented differently for delegated sign-ins vs. app-only. For delegated sign-ins, the connection information will include the user principal name of the signed in user (from which the organization can usually be inferred) and the application into which the user is signed in. Here is an example prompt for the delegated case:

[marvin@unity.org, app=a6c5245c-f383-4547-9fa4-a3b841a6e839]
ver=v1.0: /v1.0:/me/drive/root/children

For app-only sign-in, there is no user, so instead of a user principal name only the tenant id guid is shown:

[tid=d3e2e58d-e126-467e-bc9b-55a9f9ae74a2, app=df402ab7-6ad0-4602-aab3-fd813bfd6b6c]
ver=v1.0: /beta:/groups

.EXAMPLE
Set-GraphPrompt -Behavior Disabled

In this example, the prompt Graph prompt information added to the script is removed.

.LINK
Set-GraphLocation
Get-GraphLocation
Get-GraphResourceWithMetadata
#>
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
