# Copyright 2017, Adam Edwards
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

param($targetDirectory = $null)

set-strictmode -version 2
$erroractionpreference = 'stop'

$basedirectory = get-item (split-path -parent $psscriptroot)
$basepath = $basedirectory.fullname
$moduleName = $basedirectory.name
$packageManifest = join-path $basepath "$moduleName.nuspec"
$moduleManifestPath = join-path $basepath "$moduleName.psd1"
$localRepositoryName = ((split-path $moduleManifestPath -parent) -split '\\' -join '_').replace(':', '_')

write-host "Validating Manifest '$moduleManifestPath'"
$moduleVersion = (test-modulemanifest $moduleManifestPath -verbose).version

write-host "Using .nuspec file '$packageManifest'..."

$outputDirectory = if ( $targetDirectory -ne $null ) {
    $targetDirectory
} else {
    join-path $basepath pkg
}

if ( ! (test-path $outputDirectory) ) {
    mkdir $outputDirectory | out-null
} else {
    ls $outputDirectory | rm -r -force
}

$moduleOutputDirectory = join-path $outputDirectory 'modules'
$intermediateOutputDirectory = join-path $outputDirectory 'intermediate'

if ( (get-psrepository $localRepositoryName 2>$null) -ne $null ) {
    write-host "Found local ps repository '$localRepositoryName', unregistering..."
    unregister-psrepository $localrepositoryName
}

$existingSource = try {
    get-packagesource $localRepositoryName 2>$null
} catch {
    $null
}

if ( $existingSource -ne $null ) {
    write-host "Found local nuget package source '$localRepositoryName', unregistering..."
    $existingSource | unregister-packagesource
}

if ( test-path $moduleOutputDirectory ) {
    rm -r -force $moduleOutputDirectory
}

mkdir $moduleOutputDirectory | out-null

if ( test-path $intermediateOutputDirectory ) {
    rm -r -force $intermediateOutputDirectory
}

mkdir $intermediateOutputDirectory | out-null

$output = iex "$psscriptroot\install.ps1 -clean" | out-host

write-host "Building nuget package from manifest '$packageManifest'..."
write-host "Output directory = '$outputDirectory'..."

$nugetbuildcmd = "& nuget pack '$packageManifest' -outputdirectory '$outputdirectory' -nopackageanalysis -version $moduleVersion"
write-host "Executing command: ", $nugetbuildcmd

$output = iex $nugetbuildcmd | out-host
$buildResult = $lastexitcode

if ( $buildResult -ne 0 ) {
    write-host -f red "Build failed with status code $buildResult."
    throw "Command `"$nugetbuildcmd`" failed with exit status $buildResult"
}

register-packagesource -name $localRepositoryName -location $outputDirectory -providername nuget | out-host

$modulePackagePath = (ls $outputDirectory *.nupkg)[0].fullname

#$nugetInstallCommand = "nuget.exe install '$moduleName' -source '$localrepositoryname' -outputdirectory '$intermediateOutputDirectory' -excludeversion -nocache"
# write-host "Executing command $nugetInstallCommand"
# invoke-expression $nugetInstallCommand | out-null
# $installResult = $lastexitcode

# if ( $installResult -ne 0 ) {
#     write-host -f red "Intermediate package install failed with status code $installResult."
#     throw "Command `"$nugetinstallcommand`" failed with exit status $installResult"
# }

write-host "Intermediate installation succeeded."
register-psrepository $localRepositoryName $moduleOutputDirectory

 $packageData = find-package -source $localrepositoryname $modulename
 $packageData.dependencies | foreach {
    $moduleNameAndVersion = $_.split(':')[1].split('/')
    $moduleDependencyName = $moduleNameAndVersion[0]
    $moduleDependencyVersion = $moduleNameAndVersion[1]
    $dependencyDirectory = join-path $intermediateOutputDirectory $moduleDependencyName
    mkdir $dependencyDirectory | out-null
    $dependencyModulePath = join-path $dependencyDirectory "$($moduleDependencyName).psd1"
    new-modulemanifest -path $dependencyModulePath -moduleversion $moduleDependencyVersion -description 'Placeholder module' -author 'build' -filelist @('stdposh.psd1', 'stdposh.psm1') -rootmodule 'stdposh.psm1'
    '### Root module' | out-file -encoding utf8 -filepath (join-path $dependencyDirectory "$($moduleDependencyName).psm1")
    publish-module -path $dependencyDirectory -repository $localrepositoryname
}

unregister-packagesource $localrepositoryname -provider nuget

$modulePath = join-path $intermediateoutputDirectory $moduleName
$packageZipPath = "$($modulePath).zip"

write-host "Renaming '$modulePackagePath' to '$packageZipPath' for zip extraction"
mv $modulePackagePath $packageZipPath

write-host "Expanding zipped package '$packageZipPath' to '$moduleOutputDirectory'"
expand-archive -path $packageZipPath -destination $modulePath -force

$installedModulePath = (ls $intermediateOutputDirectory)[0].fullname

$modulePath = join-path $intermediateOutputDirectory $moduleName
ls $modulePath -filter '*content_types*.xml' | rm -force
ls $modulePath -filter '_rels' | rm -r -force
ls $modulePath -filter 'package' | rm -r -force
ls $modulePath -filter "$moduleName.nuspec" | rm -force

write-host "Publishing installed module package at '$modulePath' as powershell module..."
write-host "Using local path '$moduleOutputDirectory'..."

write-host "publish-module -path '$modulePath' -repository '$localRepositoryName' -verbose"
publish-module -path $modulePath -repository $localRepositoryName -verbose

# unregister-psrepository $localRepositoryName

write-host -f green "Build succeeded."

