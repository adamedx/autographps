# Copyright 2023, Adam Edwards
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
param([switch] $clean)

. "$psscriptroot/common-build-functions.ps1"

function InstallDependencies($clean) {
    $appRoot = join-path $psscriptroot '..'
    $packagesDestination = join-path $appRoot lib
    $packagesTempSource = Get-PackageTempDirectory

    if ( $clean -and (test-path $packagesDestination) ) {
        write-host -foregroundcolor cyan "Clean install specified -- deleting '$packagesDestination'"
        remove-item -r -force $packagesDestination
    }

    # Always create this directory since subsequent scripts
    # rely on its presence to know that it is safe to
    # proceed with a build because this step has been carried out.
    if ( ! (test-path $packagesDestination) ) {
        psmkdir $packagesDestination | out-null
    }

    $projectFilePath = Get-ProjectFilePath

    if ( ! ( test-path $projectFilePath ) ) {
        write-verbose "Project file '$projectFilePath' not found, skipping library dependency installation"
        return
    }

    write-host "Installing dependencies to '$appRoot'"

    Clean-PackageTempDirectory
    psmkdir $packagesTempSource | out-null

    $projectContent = [xml] ( get-content $projectFilePath | out-string )
    $targetPlatforms = $projectContent.Project.PropertyGroup.TargetFrameworks -split ';'

    if ( ! $targetPlatforms ) {
        throw "No platforms found for the TargetFrameWorks element of '$projectfilePath'; at least one platform must be specified"
    }

    $restoreCommand = "dotnet restore '$projectFilePath' --packages '$packagesTempSource' /verbosity:normal --no-cache"

    write-host "Executing command: $restoreCommand"

    # This will download and install libraries and transitive dependencies under packages destination
    Invoke-Expression $restoreCommand | out-host

    # Group the libraries by platform and place all libraries for the same platform
    # into the same platform-specific directory. Example layout is below -- note that
    # this does not allow for the same library to have different versions in the same
    # platform (which is a good thing to avoid conflicting or non-deterministic
    # versionining issues):
    #
    #     lib/
    #        <platformspec1>/
    #                        library1.dll
    #                        library2.dll
    #                        library3.dll
    #        <platformspec2>/
    #                        library1.dll
    #                        library2.dll
    #                        library3.dll

    if ( ! (test-path $packagesDestination) ) {
        psmkdir $packagesDestination | out-null
    }

    foreach ( $platform in $targetPlatforms ) {
        $platformSourceLibraries = Get-ChildItem -r $packagesTempSource |
          where name -like *.dll |
          where { $_.Directory.Name -eq $platform }

        if ( $platformSourceLibraries ) {
            $platformDirectory = join-path $packagesDestination $platform

            if ( ! ( test-path $platformDirectory ) ) {
                new-directory $platformDirectory -force | out-null
            }

            foreach ( $sourceLibrary in $platformSourceLibraries ) {
                # So now there are some new '/ref/' directories in .net6 and later releases that include various superfluous
                # binaries, so we explicitly filter these out. :(
                if ( ( split-path -leaf ( split-path -parent ( split-path -Parent $sourceLibrary.FullName ) ) ) -eq 'ref' ) {
                    continue
                }

                move-item $sourceLibrary.FullName $platformDirectory
            }
        }
    }

    Clean-PackageTempDirectory
}

InstallDependencies $clean
