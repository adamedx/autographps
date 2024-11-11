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

write-host -foregroundcolor cyan "`nWelcome to AutoGraphPS!`n"
write-host "To get started, try executing any of the following commands:"
@(
    [PSCustomObject]@{Command="    Test-Graph";Purpose="# Retrieves diagnostic information from a Microsoft Graph Service endpoint"}
    [PSCustomObject]@{Command="    Connect-Graph";Purpose="# Establishes a convenient connection context; no need to re-auth for each command"}
    [PSCustomObject]@{Command="    Get-GraphToken";Purpose="# Gets information about Graph API versions such as v1.0, beta, etc."}
    [PSCustomObject]@{Command="    gls";Purpose="# Enumerates child uri graph segments of the current location."}
    [PSCustomObject]@{Command="    gcd me";Purpose="# Changes the current location to the 'me' segment of the graph."}
    [PSCustomObject]@{Command="    gwd";Purpose="# Output the current location."}
    [PSCustomObject]@{Command="    gls";Purpose="# Enumerates the children of the (new) current location."}
    [PSCustomObject]@{Command="    gls messages";Purpose="# Enumerates email messages ('me/messages')."}
    [PSCustomObject]@{Command="    Get-GraphItem /organization";Purpose="# For Entra ID accounts, gets organization information using an absolute path"}
    [PSCustomObject]@{Command="    Get-Graph";Purpose="# Outputs information about all the current graphs and their API versions"}
    [PSCustomObject]@{Command="    gcd /beta:";Purpose="# Mount an entirely new graph of API version 'beta' and change the current location to it."}
    [PSCustomObject]@{Command="    gls me";Purpose="# Enumerate the 'me' segment itself."}
    [PSCustomObject]@{Command="    Get-Graph";Purpose="# Output the currently mounted graphs."}
) | format-table -wrap -hidetableheaders | out-host
write-host ''
