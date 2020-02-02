# Copyright 2020, Adam Edwards
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

set-strictmode -version 2

Describe 'The Get-GraphUri command' {
    Context 'When invoked using v1 metadata with namespace aliases' {
        BeforeAll {
            $progresspreference = 'silentlycontinue'
            Update-GraphMetadata -Path "$psscriptroot/../../test/assets/v1metadata-ns-alias-2020-01-22.xml" -force -wait -warningaction silentlycontinue
        }

        It "Should successfully return child segments of the 'me' singleton of entity type 'user' including actions and functions" {
            $progresspreference = 'silentlycontinue'

            $propertiesToValidate = 'Class', 'Collection', 'Endpoint', 'FullTypeName', 'GraphUri', 'Id', 'Info', 'IsDynamic', 'Namespace', 'ParentPath', 'Path', 'Preview', 'PSTypeName', 'Relation', 'Type', 'Uri', 'Version'

            $children = get-graphuri /me -children | select Class, Collection, Endpoint, FullTypeName, GraphUri, Id, Info, IsDynamic, Namespace, ParentPath, Path, Preview, PSTypeName, Relation, Type, Uri, Version

            $GetGraphUriMeResult = get-content $psscriptroot/../../test/assets/GetGraphUriMe.json

            $expectedChildren = $GetGraphUriMeResult | ConvertFrom-Json

            $children.length | Should Be $expectedChildren.length

            for ( $index = 0; $index -lt $children.length; $index++ ) {
                foreach ( $property in $propertiesToValidate ) {
                    $result = $children[$index] | select -expandproperty $property
                    $expect = $expectedChildren[$index] | select -expandproperty $property

                    $result | Should Be $expect
                }
            }
        }
    }
}
