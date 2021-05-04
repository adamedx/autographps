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

$__GraphMetadataPreferenceValues = @(
    'Ignore',
    'Wait',
    'SilentlyWait'
)

$GraphMetadataPreference = 'Wait'

function __Preference__ShowNotReadyMetadataWarning {
    if ( $GraphMetadataPreference -ne 'SilentlyWait' ) {
        Write-Warning "Waiting for metadata processing, press CTRL-C to abort"
    }
}

function __Preference__MustWaitForMetadata {
    $GraphMetadataPreference -eq 'Wait' -or $GraphMetadataPreference -eq 'SilentlyWait'
}

$__GraphAutoPromptPreferenceValues = @(
    'Auto',
    'Enable',
    'Disable'
)

$GraphAutoPromptPreference = $null

function __AutoConfigurePrompt($context) {
    $originalPrompt = try {
        $script:__GraphOriginalPrompt
    } catch {
    }

    $currentSetting = if ( $GraphAutoPromptPreference ) {
        $GraphAutoPromptPreference
    } elseif ( $__GraphPromptBehaviorSetting ) {
        $__GraphPromptBehaviorSetting
    } else {
        'Auto'
    }

    if ( $currentSetting -eq 'Auto' ) {
        if ( ( $context.connection |=> IsConnected ) -or ! ( $context.location |=> IsRoot ) ) {
            if ( ! $originalPrompt ) {
                __ConfigurePrompt Enable
            }
        } else {
            if ( $originalPrompt ) {
                __ConfigurePrompt Disable
            }
        }
    } elseif ( $currentSetting -eq 'Enable' ) {
        __ConfigurePrompt Enable
    } elseif ( $currentSetting -eq 'Disable' ) {
        __ConfigurePrompt Disable
    }
}

