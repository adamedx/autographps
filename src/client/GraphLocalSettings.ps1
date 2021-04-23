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

function __SettingVariableHelper([string] $variableName, $value) {
    if ( ! ( Get-Variable -scope:script $variableName ) ) {
        throw "Preference variable '$variableName' could not be found"
    }

    set-variable -scope:script $variableName $value
}

ScriptClass GraphLocalSettings {
    static {

        $setPreferenceScript = $null

        function __initialize([ScriptBlock] $setPreferenceScript) {
            $this.setPreferenceScript = $setPreferenceScript
            $::.LocalSettings |=> RegisterSettingProperties $::.LocalProfileSpec.ProfilesCollection $this.propertyReaders
        }

        $propertyReaders = @{
            PromptBehavior = @{
                Validator = 'StringValidator'
                Required = $false
                Updater = {
                    $currentProfile = $::.LocalProfile |=> GetCurrentProfile
                    $settingValue = $currentProfile.GetSetting('PromptBehavior')
                    if ( $settingValue -in 'Auto', 'Enable', 'Disable' ) {
                        . $::.GraphLocalSettings.setPreferenceScript __GraphPromptBehaviorSetting $settingValue
                    }
                }
            }

            PromptColor = @{
                Validator = 'StringValidator'
                Required = $false
                Updater = {
                    $currentProfile = $::.LocalProfile |=> GetCurrentProfile
                    $settingValue = $currentProfile.GetSetting('PromptColor')
                    if ( $settingValue -in [System.ConsoleColor].GetEnumNames() ) {
                        . $::.GraphLocalSettings.setPreferenceScript __GraphPromptColorSetting $settingValue
                    }
                }
            }
        }
    }
}

$::.GraphLocalSettings |=> __initialize ( get-command __SettingVariableHelper ).ScriptBlock
