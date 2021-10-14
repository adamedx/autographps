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

ScriptClass MetaGraphFormatter {
    static {
        function __initialize {
            $::.ColorScheme.RegisterColorNames(
                @(
                    'TypeClass-Entity'
                    'TypeClass-Complex'
                    'TypeClass-Enumeration'
                    'TypeClass-Primitive'
                    'MemberType-Property'
                    'MemberType-Relationship'
                    'MemberType-Method'
                    'PrimitiveTypeScalar'
                    'PrimitiveTypeCollection'
                    'Consent-Admin'
                    'Consent-User'
                ),
                'autographps'
            )

            $colorInfo = [PSCustomObject] @{
                colorMode = '4bit'
                Colors = [PSCustomObject] @{
                    'TypeClass-Entity' = 10
                    'TypeClass-Complex' = 9
                    'TypeClass-Enumeration' = 13
                    'TypeClass-Primitive' = 8
                    'MemberType-Property' = 6
                    'MemberType-Relationship' = 10
                    'MemberType-Method' = 12
                    'PrimitiveTypeScalar' = 8
                    'PrimitiveTypeCollection' = 8
                    'Consent-Admin' = 9
                    'Consent-User' = 10
                }
            }

            $::.ColorString.UpdateColorScheme(@($colorInfo))
        }

        function SegmentInfo($segment) {
            $metadata = __GetMetadataFromObject $segment

            if ( $metadata ) {
                $metadata.Info
            }
        }

        function SegmentType($segment) {
            $metadata = __GetMetadataFromObject $segment

            if ( $metadata ) {
                $metadata.Type
            }
        }

        function SegmentPreview($segment) {
            $metadata = __GetMetadataFromObject $segment

            $preview = if ( $metadata ) {
                $metadata.Preview
            } else {
                $::.SegmentHelper.__GetPreview($segment, '')
            }

            $::.ColorString.ToStandardColorString($preview, 'Emphasis1', $null, $null, $null)
        }

        function SegmentId($segment) {
            $metadata = __GetMetadataFromObject $segment

            $highlightValues = $null
            $coloring = $null
            $criterion = $null

            if ( $metadata ) {
                $segmentType = [string] $metadata.Info[0]
                $coloring = if ( $segmentType -eq 'f' -or $segmentType -eq 'a' ) {
                    $highlightValues = @('none', 'a', 'f')
                    $criterion = $segmentType
                    'Contrast'
                } else {
                    if ( $metadata.Collection ) {
                        'Containment'
                    } else {
                        if ( $segmentType -eq 'n' -or $segmentType -eq 's' ) {
                            'Emphasis1'
                        } else {
                            'Emphasis2'
                        }
                    }
                }
            }

            $::.ColorString.ToStandardColorString($segment.Id, $coloring, $criterion, $highlightValues, $null)
        }

        function MetadataStatus($status) {
            $criterion = switch ( $status ) {
                'Pending' { 'Warning' }
                'Failed' { 'Error2' }
                'Ready' { 'Success' }
            }

            $::.ColorString.ToStandardColorString($status, 'Scheme', $criterion, $null, 'NotStarted')
        }

        function TypeClass($typeClass, $value) {
            $targetValue = if ( $value ) {
                $value
            } else {
                $typeClass
            }

            $foreColor = switch ($typeClass) {
                'Entity' { 10 }
                'Complex' { 9 }
                'Enumeration' { 13 }
                'Primitive' { 8 }
            }

            $::.ColorString.ToColorString($targetValue, $foreColor, $null)
        }

        function MemberTypeId([string] $typeId, [boolean] $isCollection) {
            $colors = if ( ! $typeId.StartsWith('Edm.') ) {
                $::.ColorString.GetStandardColors('Emphasis2', $null, $null, $null)
            }

            $backColor = $null
            $foreColor = if ( $colors ) {
                $colors[0]
            } else {
                7
            }

            if ( $isCollection ) {
                $backColor = if ( $foreColor ) {
                    $foreColor
                } else {
                    7
                }

                $foreColor = 0
            }

            $::.ColorString.ToColorString($typeId, $foreColor, $backColor)
        }

        function MemberName([string] $memberName, [string] $memberType) {
            $colorName = switch ( $memberType ) {
                'Property' { 'MemberType-Property' }
                'Relationship' { 'MemberType-Relationship' }
                'Method' { 'MemberType-Method' }
            }

            $::.ColorString.ToStandardColorString($memberName, 'Scheme', $colorName, $null, $null)
        }

        function CollectionByProperty($collection, $property) {
            if ( $collection ) {
                $collection.$property
            }
        }

        function EnumerationValues($enumeration) {
            if ( $enumeration ) {
                $enumeration.name.name
            }
        }

        function MatchedSearchTerms($match, $field) {
            if ( $match.MatchedTerms ) {
                $matchedTerms = $match.MatchedTerms | select -first 1
                $isExact = $match.SearchTerm -in $matchedTerms
                if ( ! $isExact ) {
                    foreach ( $typeName in $matchedTerms ) {
                        if ( $match.SearchTerm -eq ( $typeName -split '\.' | select -last 1 ) ) {
                            $isExact = $true
                            break
                        }
                    }
                }

                $colors = $::.ColorString.GetStandardColors('Emphasis2', $null, $null, $null)

                if ( $isExact ) {
                    $colors[1] = $colors[0]
                    $colors[0] = $::.ColorString.GetColorContrast($colors[1])
                }

                $value = if ( $field ) {
                    $match.$field
                } else {
                    $matchedTerms
                }

                $::.ColorString.ToColorString($value, $colors[0], $colors[1])
            }
        }

        function AuthType($authType) {
            $coloring = if ( $authType -eq 'Delegated' ) {
                'Emphasis2'
            } else {
                'Emphasis1'
            }

            $::.ColorString.ToStandardColorString($authType, $coloring, $null, $null, $null)
        }

        function PermissionName($permission, $consentType) {
            $foreColor = if ( $consentType -eq 'Admin' ) {
                13
            } else {
                $null
            }

            $::.ColorString.ToColorString($permission, $foreColor, $null)
        }

        function ColorNameText($colorName, $text) {
            $backColor = $::.ColorString.GetColorFromName($colorName)
            $foreColor = $::.ColorString.GetColorContrast($backColor)
            $::.ColorString.ToColorString($text, $foreColor, $backColor)
        }

        function __GetMetadataFromObject($graphObject) {
            if ( $graphObject | gm __ItemMetadata -MemberType Method -erroraction ignore ) {
                $graphObject.__ItemMetadata()
            } elseif ( $graphObject.pstypenames -contains 'GraphSegmentDisplayType' ) {
                $graphObject
            }
        }
    }
}

$::.MetaGraphFormatter |=> __initialize
