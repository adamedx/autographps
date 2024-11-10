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

    write-host -foregroundcolor cyan "Installing dependencies to '$appRoot'"

    Clean-PackageTempDirectory
    psmkdir $packagesTempSource | out-null

    $projectContent = [xml] ( get-content $projectFilePath | out-string )
    $targetPlatforms = $projectContent.Project.PropertyGroup.TargetFrameworks -split ';'

    if ( ! $targetPlatforms ) {
        throw "No platforms found for the TargetFrameWorks element of '$projectfilePath'; at least one platform must be specified"
    }

    $restoreCommand = "dotnet restore '$projectFilePath' --packages '$packagesTempSource' /verbosity:normal --no-cache"

    write-host -foregroundcolor cyan "Executing command: $restoreCommand"

    # This will download and install libraries and transitive dependencies under packages destination
    Invoke-Expression $restoreCommand | out-host

    # Group the libraries by platform and place all libraries for the same platform
    # into the same platform-specific directory. Native libraries for all supported architctures
    # are copied into both platform directories. Example layout is below -- note that
    # this does not allow for the same library to have different versions in the same
    # platform (which is a good thing to avoid conflicting or non-deterministic
    # versionining issues):
    #
    #     lib/
    #        <platformspec1>/
    #                        library1.dll
    #                        library2.dll
    #                        library3.dll
    #                        native-library-x64.dll
    #                        native-library.dll
    #                        native-library-arm64.dll
    #        <platformspec2>/
    #                        library1.dll
    #                        library2.dll
    #                        library3.dll
    #                        native-library-x64.dll
    #                        native-library.dll
    #                        native-library-arm64.dll

    if ( ! (test-path $packagesDestination) ) {
        psmkdir $packagesDestination | out-null
    }

    # So apparently some packages we need for say .net60 are targeted at netstandard2.0 :(
    # We're just going to pretend those files support the platform we need
    $compatiblePlatforms = @{
        'net472' = @('net462', 'net461')
        'net6.0' = @('netstandard2.0')
    }

    foreach ( $platform in $targetPlatforms ) {
        # We enumerate all dll's that meet one of the following criteria regarding the
        # directory in which they are located:
        #
        #   * Directory named for one of the target platforms
        #   * Or named for one of the platforms compatible with the current target platform
        #   * Or named 'native" for native libraries. This last point means that native
        #     libraries will thus be included under all target platforms because they are not
        #     filtered in any way by the current target platform unlike the two cases above.
        #
        #   NOTE: A key assumption here is that *native libraries have unique file names* such
        #   that they can all be placed in the same directory without overwriting a file.
        #   Typically these files have a name that includes a specific native architecture
        #   such as x64, arm64, x86, etc.
        $platformSourceLibraries = Get-ChildItem -r $packagesTempSource |
          where name -like *.dll |
          where { $_.Directory.Name -eq $platform -or
                  $_.Directory.Name -eq 'native' -or
                  ( $_.Directory.Name -in $compatiblePlatforms[$platform] )
                }

        if ( $platformSourceLibraries ) {
            $platformDirectory = join-path $packagesDestination $platform

            if ( ! ( test-path $platformDirectory ) ) {
                new-directory $platformDirectory -force | out-null
            }

            $libraryToDestination = @{}

            foreach ( $sourceLibrary in $platformSourceLibraries ) {
                write-verbose "Processing library $($sourceLibrary.FullName)"
                # So now there are some new '/ref/' directories in .net6 and later releases that include various superfluous
                # binaries, so we explicitly filter these out. :(
                if ( ( split-path -leaf ( split-path -parent ( split-path -Parent $sourceLibrary.FullName ) ) ) -eq 'ref' ) {
                    continue
                }

                $targetLibraryPath = join-path $platformDirectory $sourceLibrary.Name

                $libraryPlatform = $sourceLibrary.Directory.Name
                $alternatePlatforms = $compatiblePlatforms[$platform]

                $compatibilityIndex = if ( $libraryPlatform -eq $platform ) {
                    -1
                } elseif ( $alternatePlatforms ) {
                    # Consider any alternate platforms
                    if ( $alternatePlatforms[$libraryPlatform] ) {
                        $foundIndex = $alternatePlatforms.IndexOf($libraryPlatform)
                        if ( $foundIndex -ne -1 ) {
                            $foundIndex
                        } else {
                            throw "A library was chosen that should exist under allowed compatible platforms but was not found in the compatible platforms list"
                        }
                    }
                } else {
                    continue
                }

                $libraryKey = "$($platform):$($sourceLibrary.Name)"
                $compatibleLibrary = $libraryToDestination[$libraryKey]

                if ( $compatibleLibrary ) {
                    # If a different version of this library has already been selected, then check to see if the version currently
                    # under consideration is a better match based on compability precedence. Otherwise, no change is needed and
                    # the previously chosen library can remain as the best option
                    if ( $compatibilityIndex -lt $compatibleLibrary.CompatibilityIndex ) {
                        $compatibleLibrary.OriginalPlatform = $platform
                        $compatibleLibrary.CompatibilityIndex = $compatibilityIndex
                        $compatibleLibrary.SourceLibraryPath = $sourceLibrary.FullName
                    }
                } else {
                    $libraryToDestination.Add(
                        $libraryKey,
                        [PSCustomObject] @{
                            OriginalPlatform = $platform
                            CompatibilityIndex = $compatibilityIndex
                            SourceLibraryPath = $sourceLibrary.FullName
                        }
                    )
                }
            }

            foreach ( $library in $libraryToDestination.Keys ) {
                $targetPath = join-path $platformDirectory ( split-path -leaf $libraryToDestination[$library].SourceLibraryPath )
                if ( test-path $targetPath ) {
                    throw "The file '$targetPath' already exists"
                }
                write-verbose "Copying $($libraryToDestination[$library].SourceLibraryPath) to $($targetPath)"
                copy-item $libraryToDestination[$library].SourceLibraryPath $targetPath
            }
        }
    }

    Clean-PackageTempDirectory
}

InstallDependencies $clean
