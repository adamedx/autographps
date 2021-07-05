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

        function GroupType($group) {
            $groupType = @()

            @{SecurityEnabled = 'Security'; MailEnabled = 'Mail'}.GetEnumerator() | foreach {
                if ( ( $group | gm $_.Name -erroraction ignore ) -and
                     $group.($_.Name) ) {
                         $groupType += $_.Value
                     }
            }

            $groupType -join ', '
        }

        function ContactEmail($contact) {
            if ( $contact | gm emailAddresses -erroraction ignore ) {
            }
        }

        function ContactPhone($contact) {
            $type = $null

            $phone = if ( ( $contact | gm mobilePhone -erroraction ignore ) -and $contact.mobilePhone ) {
                $type = 'Mobile'
                $contact.mobilePhone
            } elseif ( ( $contact | gm businessPhones -erroraction ignore ) -and $contact.businessPhones ) {
                $type = 'Work'
                $contact.businessPhones | select -first 1
            } elseif ( ( $contact | gm homePhones -erroraction ignore ) -and $contact.homePhones ) {
                $type = 'Home'
                $contact.homePhones | select -first 1
            }

            if ( $type ) {
                $type + ": " + $phone
            }
        }

        function ContactAddress($contact) {
            $addressTypes = [ordered] @{
                Work = 'businessAddress'
                Home = 'homeAddress'
            }

            foreach ( $addressType in $addressTypes.GetEnumerator() ) {
                if ( ( $contact | gm $addressType.Value -erroraction ignore ) -and $contact.($addressType.Value) ) {
                    $address = $contact.($addressType.Value)
                    if ( ! ( $address.psobject.properties | measure-object ).count ) {
                        continue
                    }

                    $addressDisplay = if ( $address | gm Street ) {
                        $address.Street
                    } elseif ( ( $address | gm City ) -or ( $address | gm State ) ) {
                        $components = @()
                        if ( $address | gm City ) {
                            $components += $address.City
                        }

                        if ( $address | gm State ) {
                            $components += $address.State
                        }

                        $components -join ', '
                    } elseif ( $address | gm countryOrRegion ) {
                        $address.countryOrRegion
                    } elseif ( $address | gm postalCode ) {
                        $address.postalCode
                    }

                    if ($addressDisplay ) {
                        $addressType.Name + ": " + $addressDisplay
                        break
                    }
                }
            }
        }

        function ContactEmailAddress($contact) {
            $email = if ( $contact | gm emailAddresses -erroraction ignore ) {
                $contact.emailAddresses |
                  where { $_ -ne $null -and $_ -ne '' } |
                  select -first 1 |
                  select -expandproperty address
            }

            if ( $email ) {
                $::.ColorString.ToStandardColorString($email, 'Emphasis1', $null, $null, $null)
            }
        }

        function MessageEmailAddress($message) {
            if ( $message | gm 'From' -erroraction ignore ) {
                __MessageAddress $message.From
            }
        }

        function MessageAudience($message) {
            if ( $message | gm 'ToRecipients' -erroraction ignore ) {
                $recipients = $message.toRecipients | foreach {
                    __MessageAddress $_
                }

                $count = ( $recipients | measure-object ).count

                $countDisplay = if ( $count -gt 1 ) {
                    " + $($count - 1)"
                }

                $firstRecipient = $recipients | where { $_ -ne $null } | select -first 1

                if ( $firstRecipient ) {
                    $firstRecipient + $countDisplay
                }
            }
        }

        function MessageSubject($message) {
            if ( $message | gm Subject -erroraction ignore ) {
                $isHighPriority = if ( $message | gm importance -erroraction ignore ) {
                    $message.Importance -eq 'High'
                }

                $isUnread = if ( ( $message | gm importance -erroraction ignore ) -and
                                 ( $message | gm IsRead -erroraction ignore ) ) {
                    ! $message.IsRead
                }

                if ( $isHighPriority ) {
                    $augmentedSubject = "! " + $message.Subject
                    if ( $isUnread ) {
                        $priorityColor = $::.ColorString.GetStandardColors('Scheme', 'Error1', $null, $null)
                        $contrast = $::.ColorString.GetColorContrast($priorityColor[0])
                        $::.ColorString.ToColorString($augmentedSubject, $contrast, $priorityColor[0])
                    } else {
                        $::.ColorString.ToStandardColorString($augmentedSubject, 'Scheme', 'Error1', $null, $null)
                    }
                } elseif ( $isUnread ) {
                    $::.ColorString.ToStandardColorString($message.Subject, 'Emphasis2', $null, $null, $null)
                } else {
                    $message.Subject
                }
            }
        }

        function MessageTime($message, $timeField) {
            if ( $message | gm $timeField -erroraction ignore ) {
                $parsedTime = [DateTime]::new(0)

                if ( [DateTime]::tryparse($message.$timeField, [ref] $parsedTime) ) {
                    $parsedTime.ToString("ddd yyyy-MM-dd HH:mm")
                } else {
                    $message.$timeField
                }
            }
        }

        function __MessageAddress($messageAddress) {
            if ( $messageAddress -and ( $messageAddress | gm emailAddress -erroraction ignore ) ) {
                if ( $messageAddress.emailAddress | gm name -erroraction ignore ) {
                    $messageAddress.emailAddress.Name
                } elseif ( $messageAddress.emailAddress | gm address -erroraction ignore ) {
                    $messageAddress.emailAddress.Address
                }
            }
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
