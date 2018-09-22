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

# This breaks without the import line below, but I don't think it should.
# It appears to be related to the scriptclass module and whether it has
# already been loaded as a nested module of a module being imported here

write-warning "***DEPRECATION!!!***"
write-warning "PoshGraph has been renamed to *AutoGraphPS*."
write-warning "The module package for PoshGraph will no longer be updated!"
write-warning "Visit the link below for more details regarding the rename:"
write-warning "`n`n         https://github.com/adamedx/autographps/blob/poshgraph_rename/README.md#this-module-has-been-renamed`n`n"
write-warning "Please replace this module with AutoGraphPS to get the latest"
write-warning "version of all your favorite PoshGraph cmdlets:"
write-warning "`n`n         Uninstall-Module poshgraph -Scope CurrentUser`n         Install-Module AutoGraphPS -Scope CurrentUser"

import-module autographps-sdk

. (import-script cmdlets)
. (import-script aliases)

