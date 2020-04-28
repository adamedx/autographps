#
# Module manifest for module 'AutoGraphPS'
#
# Generated by: adamedx
#
# Generated on: 9/24/2017
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'autographps.psm1'

# Version number of this module.
ModuleVersion = '0.32.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop', 'Core')

# ID used to uniquely identify this module
GUID = '524a2b17-37b1-43c2-aa55-6c19692c6450'

# Author of this module
Author = 'Adam Edwards'

# Company or vendor of this module
CompanyName = 'Modulus Group'

# Copyright statement for this module
Copyright = '(c) 2020 Adam Edwards.'

# Description of the functionality provided by this module
Description = 'CLI for automating and exploring the Microsoft Graph'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @('')

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @('./src/cmdlets/common/AutoGraphFormats.ps1xml')

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @(
    @{ModuleName='autographps-sdk';ModuleVersion='0.20.0';Guid='4d32f054-da30-4af7-b2cc-af53fb6cb1b6'}
    @{ModuleName='scriptclass';ModuleVersion='0.20.1';Guid='9b0f5599-0498-459c-9a47-125787b1af19'}
)

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
    'Add-GraphItemReference',
    'Find-GraphPermission',
    'Get-Graph',
    'Get-GraphChildItem',
    'Get-GraphItem',
    'Get-GraphItemRelationship',
    'Get-GraphResourceWithMetadata',
    'Get-GraphLocation',
    'Get-GraphType',
    'Get-GraphUri',
    'New-Graph',
    'New-GraphItem',
    'New-GraphObject',
    'Remove-Graph',
    'Remove-GraphItem',
    'Remove-GraphItemRelationship',
    'Set-GraphItemProperty',
    'Set-GraphLocation',
    'Set-GraphPrompt',
    'Show-GraphHelp',
    'Update-GraphMetadata'
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @(
    'GraphAutoPromptPreference'
    'GraphMetadataPreference'
    'GraphPromptColorPreference'
    'GraphVerboseOutputPreference' # From AutoGraphPS-SDK
    'LastGraphItems'               # From AutoGraphPS-SDK
)

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @('gcd', 'gg', 'ggci', 'ggi', 'ggu', 'gls', 'gwd')

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @('')

# List of all files packaged with this module
    FileList = @(
        '.\autographps.psd1',
        '.\autographps.psm1',
        '.\src\aliases.ps1',
        '.\src\cmdlets.ps1',
        '.\src\graph.ps1',
        '.\src\client\LocationContext.ps1',
        '.\src\cmdlets\Add-GraphItemReference.ps1',
        '.\src\cmdlets\Find-GraphPermission.ps1',
        '.\src\cmdlets\Get-Graph.ps1',
        '.\src\cmdlets\Get-GraphItem.ps1',
        '.\src\cmdlets\Get-GraphItemRelationship.ps1',
        '.\src\cmdlets\Get-GraphChildItem.ps1',
        '.\src\cmdlets\Get-GraphResourceWithMetadata.ps1',
        '.\src\cmdlets\Get-GraphLocation.ps1',
        '.\src\cmdlets\Get-GraphType.ps1',
        '.\src\cmdlets\Get-GraphUri.ps1',
        '.\src\cmdlets\New-Graph.ps1',
        '.\src\cmdlets\New-GraphItem.ps1',
        '.\src\cmdlets\New-GraphObject.ps1',
        '.\src\cmdlets\Remove-Graph.ps1',
        '.\src\cmdlets\Remove-GraphItem.ps1',
        '.\src\cmdlets\Remove-GraphItemRelationship.ps1',
        '.\src\cmdlets\Set-GraphItemProperty.ps1',
        '.\src\cmdlets\Set-GraphLocation.ps1',
        '.\src\cmdlets\Set-GraphPrompt.ps1',
        '.\src\cmdlets\Show-GraphHelp.ps1',
        '.\src\cmdlets\Update-GraphMetadata.ps1',
        '.\src\cmdlets\common\AutoGraphFormats.ps1xml',
        '.\src\cmdlets\common\ContextHelper.ps1',
        '.\src\cmdlets\common\GraphParameterCompleter.ps1',
        '.\src\cmdlets\common\GraphUriParameterCompleter.ps1',
        '.\src\cmdlets\common\LocationHelper.ps1',
        '.\src\cmdlets\common\PermissionHelper.ps1',
        '.\src\cmdlets\common\QueryTranslationHelper.ps1',
        '.\src\cmdlets\common\SegmentHelper.ps1',
        '.\src\cmdlets\common\TypeHelper.ps1',
        '.\src\cmdlets\common\TypeParameterCompleter.ps1',
        '.\src\cmdlets\common\TypePropertyParameterCompleter.ps1',
        '.\src\cmdlets\common\TypeUriHelper.ps1',
        '.\src\cmdlets\common\TypeUriParameterCompleter.ps1',
        '.\src\common\GraphAccessDeniedException.ps1',
        '.\src\common\PreferenceHelper.ps1',
        '.\src\metadata\metadata.ps1',
        '.\src\metadata\Entity.ps1',
        '.\src\metadata\EntityEdge.ps1',
        '.\src\metadata\EntityGraph.ps1',
        '.\src\metadata\EntityVertex.ps1',
        '.\src\metadata\GraphBuilder.ps1',
        '.\src\metadata\GraphCache.ps1',
        '.\src\metadata\GraphDataModel.ps1',
        '.\src\metadata\GraphManager.ps1',
        '.\src\metadata\GraphSegment.ps1',
        '.\src\metadata\SegmentParser.ps1',
        '.\src\metadata\QualifiedSchema.ps1',
        '.\src\metadata\UriCache.ps1'
        '.\src\typesystem\TypeProperty.ps1',
        '.\src\typesystem\TypeSchema.ps1',
        '.\src\typesystem\TypeDefinition.ps1',
        '.\src\typesystem\TypeProvider.ps1',
        '.\src\typesystem\ScalarTypeProvider.ps1',
        '.\src\typesystem\CompositeTypeProvider.ps1',
        '.\src\typesystem\TypeManager.ps1',
        '.\src\typesystem\GraphObjectBuilder.ps1'
    )

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('MSGraph', 'Graph', 'AADGraph', 'Azure', 'MicrosoftGraph', 'Microsoft-Graph', 'MS-Graph', 'AAD-Graph', 'GraphExplorer', 'REST', 'CRUD', 'GraphAPI', 'autograph', 'poshgraph', 'PSEdition_Core', 'PSEdition_Desktop', 'Windows', 'Linux', 'MacOS')

        # A URL to the license for this module.
        LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/adamedx/autographps'

        # A URL to an icon representing this module.
        IconUri = 'https://raw.githubusercontent.com/adamedx/poshgraph/master/assets/PoshGraphIcon.png'

        # Adds pre-release to the patch version according to the conventions of https://semver.org/spec/v1.0.0.html
        # Requires PowerShellGet 1.6.0 or greater
        # Prerelease = '-preview'

        # ReleaseNotes of this module
        ReleaseNotes = @'
## AutoGraphPS 0.32.0 Release Notes

This release includes major breaking changes in command names, fixes significant defects in type-related functionality, and adds several features to existing commands. Some commands, such as `Get-GraphChildItem`, gain completely new behaviors.

### New dependencies

* AutoGraphPS-SDK 0.20.0

### Breaking changes

* Includes breaking changes from [AutoGraphPS-SDK 0.19.0](https://github.com/adamedx/autographps-sdk/releases/tag/v0.19.0) -- `Get-GraphItem` and `Remove-GraphItem` from `AutoGraphPS-SDK` have been renamed to `Get-GraphResource` and `Remove-GraphResource`
* `Get-GraphItemWithMetadata` has been renamed to `Get-GraphResourceWithMetadata`
* New implementations of `Get-GraphItem` and `Remove-GraphItem` are introduced in this module -- previously they were part of `AutoGraphPS-SDK` and had different functionality than the new version in this module

### New features

* `Get-GraphType` now supports tab-completion for output, so commands like select can be used interactively when building commands in the shell
* New `Get-GraphItem` command: a command with this name was in previous versions of the dependency module `AutoGraphPS-SDK`; this new command supports type-aware access of objects by `id` and other type-related facilities.
* New `Remove-GraphItem` command: a command with this name was in previous versions of the dependency module `AutoGraphPS-SDK`; this new command supports type-aware removal of objects by `id` and other type-related facilities.
* `Get-Graph` now returns an object with additional fields providing more information about the context of the Graph:
  * `Id`: The `Id` field is a guid that uniquely identifies the mounted Graph. If the same graph endpoint is mounted again, it will have a different `Id`. The property can be used for cases such as hashing.
  * `CreationTime`: The time, in the local time zone, at which the graph was mounted
  * `LastUpdateTime`: The time, in the local time zone, at which the graph was last updated by the `Update-GraphMetadata` command. If no such update occurred, the time is the same as the `CreationTime` property
  * `LastTypeMetadataSource`: The source of the type metadata used to define the graph when it was first mounted or last updated, which ever is ost recent. The source is either a URI to an http metadata source like https://graph.microsoft.com/v1.0/$metadata or the path to a local file containing the same format of data as that hosted at the http URI.
* The `ContentColumns` parameter of `Get-GraphChildItem` and `Get-GraphResourceWithMetadata` has been replaced by the `ContentOnly` parameter which has the following behavior: Instead of returning a uniform `PSCustomObject` with standard members including a `Content` member to access the actual content returned by Graph, the command just returns the actual content, just like the `Get-GraphResource` command.
* The `Get-GraphChildItem` command now also returns children of a type's entityset if applicable
* The `Get-GraphChildItem`, `Get-GraphItem`, and `Get-GraphResourceWithMetadata` commands now support the following parameters (with parameter-completion where applicable):
  * Paging parameter support: `First`, `Skip`, `IncludeTotalCount` parameters are now supported (as they are for the `Invoke-GraphRequest` and `Get-GraphResource` commands of `AutoGraphPS-SDK`).
  * `Expand`: Navigation properties may now be expanded (with parameter completion)
  * `Search`: For supported entities, an API-defined search query may be specified
  * `Sort`, `Descending`: Sorting by specified property (with parameter completion) may be specified
* Parameter completion is also supported for the `Expand` and `Sort` commands of `Invoke-GraphRequest` and `Get-GraphResource` when this module is installed.

### Fixed defects

* Graph API versions including `v1.0` and `beta` included multiple namespaces for API metadata after March 2020. Types outside of the `graph.microsoft` namespace were invisible to AutoGraphPS commands -- this has been fixed with support for multiple namespaces.
* Test execution in CI requires special module-specific logic to rename the AutoGraphPS-SDK modules installed for testing to lower case
* The `ContentColumns` parameter of `Get-GraphChildItem` and `Get-GraphResourceWithMetadata` has been regressed for several releases due to a syntax error which is now fixed.
* Inherited properties were absent from objects generated by `New-GraphObject`
* Inherited properties may be selected for the `Property` argument of `New-GraphObject`
* Fixed race condition in `Update-GraphMetadata` where some commands like `New-GraphObject` and `Get-GraphType` would not reflect the update
* Numerous parameter set fixes to `*-GraphItem*` commands including addressing consistency issues with the parameter sets
* Numerous fixes from commands included from the `AutoGraphPS-SDK` module

'@
    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}
