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

. (import-script ../metadata/SegmentParser)
. (import-script common/LocationHelper)

<#
.SYNOPSIS
Outputs the current Graph API URI location used by commands as the default URI for issuing Graph API requests or inspecting Graph API metadata.

.DESCRIPTION
The Get-GraphLocation command gets the current Graph API URI location to a specified value. This current location is used by commands to resolve Uris relative to that location to reduce the data entry overhead of entering long URIs from the console. Maintaining a current location also helps remove the need to remember entire URI paths at every command invocation -- just invoke the command once to set the current location; if subsequent commands use URIs relative to that location, that prefixed location in the URI may be omitted.

See the documentation for the Set-GraphLocation for more information about the current location concept.

Get-GraphLocation provides the alias 'gwd' because the behavior of Get-GraphLocation with regard to Graph API URIs is analgous to the functionalty of the 'pwd' command in many shell languages used to get the current 'working directory', i.e. set the current location in the file system.

The current location may also be displayed in the PowerShell prompt if prompt integration has not been disabled using the Set-GraphPrompt command or related profile settings.

.OUTPUTS
This command outputs an object with a property Path that has the value of the current location. This location is fully qualified, meaning its first segment is of the form /<graphname>:, where graphname is the name of a currently mounted graph. See the documentation Set-GraphLocation for more information on the format of graph URIs.

.EXAMPLE
gwd

Path
----
/v1.0:/me/drive/root/children

In this example, Get-GraphLocation was invoked using its alias 'gwd' to output the current location, /v1.0:/me/drive/root/children.

.EXAMPLE
gcd -TypeName user
gwd

Path
----
/beta:/users

Here the Set-GraphLocation command is invoked via its 'gcd' alias to change the current location to the default URI for the 'user' type. Get-GraphLocation, in this case invoked by its 'gwd' alias, can then be used to inspect the current location which shows the path to be /beta:/users.

.LINK
Set-GraphLocation
Get-GraphResourceWithMetadata
Get-GraphResource
Get-GraphLastOutput
Set-GraphPrompt
Get-GraphType
#>
function Get-GraphLocation {
    [cmdletbinding()]
    param()

    Enable-ScriptClassVerbosePreference

    $context = $::.GraphContext |=> GetCurrent

    if ( ! $context ) {
        throw "Cannot get location in the current context because no current context exists"
    }

    $parser = new-so SegmentParser $context $null $true

    $::.LocationHelper |=> ToPublicLocation $parser $context.location
}
