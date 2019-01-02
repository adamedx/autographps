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

write-host -foregroundcolor cyan "`nWelcome to Posh Graph!`n"
write-host "To get started, try executing any of the following commands:"
@(
    [PSCustomObject]@{Command="    Test-Graph";Purpose="# Retrieves diagnostic information from a Microsoft Graph Service endpoint"}
    [PSCustomObject]@{Command="    Connect-Graph";Purpose="# Establishes a convenient connection context; no need to re-auth for each command"}
    [PSCustomObject]@{Command="    Get-GraphItem me";Purpose="# Gets the user profile of the authenticated user"}
    [PSCustomObject]@{Command="    Get-GraphVersion v1.0";Purpose="# Gets information about Graph API versions such as v1.0, beta, etc."}
) | format-table -wrap -hidetableheaders | out-host
write-host ''
