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


# Some .psd1 modules fail to load on Linux only when loaded for tests
# executed outside of the import-devmodule environment
# during CI runs (no repro on dev workstations :)). This
# mode of execution is itself a workaround for a Linux-only
# hang when the pester tests are run with import-devmodule.
# So until that's fixed, the workaround is to import the psm1
# directly. Once import-devmodule is fixed, this workaround
# shoudl be removed.

import-module scriptclass
import-module (Get-ModulePSMPath AutoGraphPS-SDK)
import-module (Get-ModulePSMPath AutoGraphPS)
