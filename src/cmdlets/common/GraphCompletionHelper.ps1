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

. (import-script ArgumentCompletionHelper)

enum GraphCompletionType {
    Name
}

ScriptClass GraphCompletionHelper {
    static {
        $base = $::.ArgumentCompletionHelper

        function __initialize() {
            $this.base |=> __RegisterArgumentCompleterScriptBlock $this.GraphNameCompleter ([GraphCompletionType]::Name)
        }

        $GraphNameCompleter = {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            $contextNames = $::.LogicalGraphManager |=> Get |=> GetContext | sort | select -expandproperty name

            $::.GraphCompletionHelper.base |=> FindMatchesStartingWith $wordToComplete $contextNames
        }
    }
}

$::.GraphCompletionHelper |=> __initialize
