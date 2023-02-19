# Copyright 2022, Adam Edwards
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

[cmdletbinding()]
param(
    [string] $pfxBase64Secret
)

Set-StrictMode -Version 2

if ( $pfxBase64Secret ) {
    $secretBytes = [System.Convert]::FromBase64String($pfxBase64Secret)
    [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($secretBytes)
#    $certCollection = [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
#    $certCollection.Import($secretBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
}
