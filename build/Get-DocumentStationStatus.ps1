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

[cmdletbinding()]
param()
Set-StrictMode -Version 2
$commandRoot = join-path $psscriptroot './src/cmdlets'

$commandFiles = ls ./src/cmdlets -filter *.ps1 |
  where name -notlike '*.tests.*' |
  where name -notlike '*~*' |
  where name -notlike '*#*'

$missingDocCommandFiles = $commandFiles |
  where { ! ( $_ | select-string -CaseSensitive '\.SYNOPSIS' ) }
  sort-object Length

$commandCount = ( $commandFiles | measure-object ).count
$missingDocCommandCount = ($missingDocCommandFiles |measure-object).count

$completionPercent = if ( $commandCount ) {
    ( 1 - $missingDocCommandCount / $commandCount ) * 100
}

$statusTime = [DateTime]::Now
$commandNames = $missingDocCommandFiles | select-object -expandproperty Name |
  foreach {
      ($_ -split '\.')[0]
  }

[PSCustomObject] @{
    ReportTime = $statusTime
    DocCompletionPercent = $completionPercent
    MissingDocCommandCount = $missingDocCommandCount
    TotalCommandCount = $commandCount
    CommandsMissingDocs = $commandNames
}
