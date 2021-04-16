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
        function ResultIndex($result) {
            if ( $result | gm __ResultIndex -erroraction ignore ) {
                $result.__ResultIndex()
            }
        }

        function SegmentInfo($segment) {
            if ( $segment.pstypenames -contains 'GraphSegmentDisplayType' ) {
                $segment.Info
            }
        }

        function SegmentType($segment) {
            if ( $segment.pstypenames -contains 'GraphSegmentDisplayType' ) {
                $segment.Type
            }
        }

        function SegmentPreview($segment) {
            $preview = if ( $segment.pstypenames -contains 'GraphSegmentDisplayType' ) {
                $segment.Preview
            } else {
                $::.SegmentHelper.__GetPreview($segment, '')
            }

            $::.ColorString.ToStandardColorString($preview, 'Emphasis1', $null, $null, $null)
        }

        function SegmentId($segment) {
            $highlightValues = $null
            $coloring = $null
            $criterion = $null

            if ( $segment.pstypenames -contains 'GraphSegmentDisplayType' ) {
                $segmentType = [string] $segment.Info[0]
                $coloring = if ( $segmentType -eq 'f' -or $segmentType -eq 'a' ) {
                    $highlightValues = @('none', 'a', 'f')
                    $criterion = $segmentType
                    'Contrast'
                } else {
                    if ( $segment.Collection ) {
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
            $color = switch ( $memberType ) {
                'Property' { 11 }
                'Relationship' { 10 }
                'Method' { 14 }
            }

            $::.ColorString.ToColorString($memberName, $color, $null)
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

                $coloring = if ( $isExact ) {
                    'Emphasis1'
                } else {
                    'Emphasis2'
                }

                $value = if ( $field ) {
                    $match.$field
                } else {
                    $matchedTerms
                }

                $::.ColorString.ToStandardColorString($value, $coloring, $null, $null, $null)
            }
        }
    }
}
