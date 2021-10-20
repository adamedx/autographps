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

ScriptClass CustomFormatter {
    static {
        const DAY_TICKS ([TimeSpan]::new(1,0,0,0).Ticks)

        $typesWithHeterogeneousFormatter = @{
            'Autograph.Entity.microsoft.graph.message' = 'Autograph.Entity.microsoft.graph.message'
            'Autograph.Entity.microsoft.graph.eventMessage' = 'Autograph.Entity.microsoft.graph.message'
            'Autograph.Entity.microsoft.graph.eventMessageResponse' = 'Autograph.Entity.microsoft.graph.message'
            'Autograph.Entity.microsoft.graph.eventMessageRequest' = 'Autograph.Entity.microsoft.graph.message'
        }

        function SupportsHeterogeneousFormatter([string] $typeName) {
            $this.typesWithHeterogeneousFormatter[$typeName] -ne $null
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
            $result = if ( $message | gm 'ToRecipients' -erroraction ignore ) {
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

            $::.ColorString.ToColorString('', 0, 0) + $result
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

                $truncatedSubject = __Truncate $message.Subject 48

                if ( $isHighPriority ) {
                    $augmentedSubject = "! " + $truncatedSubject
                    if ( $isUnread ) {
                        __GetInvertedStandardColorString $augmentedSubject 'Scheme' 'Message-HighPriority'
                    } else {
                        $::.ColorString.ToStandardColorString($augmentedSubject, 'Scheme', 'Message-HighPriority', $null, $null)
                    }
                } elseif ( $isUnread ) {
                    $::.ColorString.ToStandardColorString($truncatedSubject, 'Scheme', 'Message-Unread', $null, $null)
                } else {
                    $::.ColorString.ToStandardColorString($truncatedSubject, 'Scheme', 'Message-Read', $null, $null)
                }
            }
        }

        function MessageTime($message, $timeField) {
            $dayIndex = $null

            $timeOutput = if ( $message | gm $timeField -erroraction ignore ) {
                $parsedTime = [DateTime]::new(0)

                if ( [DateTime]::tryparse($message.$timeField, [ref] $parsedTime) ) {
                    $parsedTime.ToString("yyyy-MM-dd HH:mm ddd")
                    $dayIndex = [Math]::Floor( $parsedTime.Ticks / $DAY_TICKS )
                } else {
                    $message.$timeField
                }
            }

            $colorValue = if ( $dayIndex ) {
                if ( $dayIndex % 2 ) {
                    'Emphasis2'
                } else {
                    'Emphasis1'
                }
            }

            $::.ColorString.ToStandardColorString($timeOutput, $colorValue, $null, $null, $null)
        }


        function DriveItemTime($driveItem, $timeField) {
            if ( $driveItem | gm $timeField -erroraction ignore ) {
                $parsedTime = [DateTime]::new(0)

                $time = if ( [DateTime]::tryparse($driveItem.$timeField, [ref] $parsedTime) ) {
                    $parsedTime.ToString("yyyy-MM-dd HH:mm")
                } else {
                    $driveItem.$timeField
                }

                $fileAge = [DateTime]::now - $parsedTime

                $colorValue = if ( $fileAge.TotalDays -gt 730 ) {
                    'DriveItem-OldItem'
                } elseif ( $fileAge.TotalDays -gt 90 ) {
                    'DriveItem-MediumAgeItem'
                } elseif ( $fileAge.TotalDays -gt 30 ) {
                    'DriveItem-RecentItem'
                } else {
                    'DriveItem-VeryRecentItem'
                }

                $::.ColorString.ToStandardColorString($time, 'Scheme', $colorValue, $null, $null)
            }
        }

        function DriveItemAuthor($driveItem, $authorField) {
            $result = if ( $driveItem | gm $authorField ) {
                $author = $driveItem.$authorField

                $authorName = if ( $author | gm -erroraction ignore user ) {
                    $userFields = 'email', 'displayName', 'id'

                    foreach ( $field in $userFields ) {
                        if ( ( $author.user | gm $field -erroraction ignore ) -and $author.user.$field ) {
                            $author.user.$field
                            break
                        }
                    }
                }

                if ( $authorName ) {
                    $authorName
                } else {
                    $author.ToString()
                }
            }

            if ( $result ) {
                __Truncate $result 30
            }
        }

        function DriveItemSize($driveItem) {
            if ( $driveItem | gm size ) {
                $colorValue = if ( $driveItem.size -ge 100000000 ) {
                    'DriveItem-Gigantic'
                } elseif ( $driveItem.size -ge 10000000 ) {
                    'DriveItem-Large'
                } elseif ( $driveItem.size -eq 0 ) {
                    'DriveItem-Empty'
                }

                $::.ColorString.ToStandardColorString($driveItem.size, 'Scheme', $colorValue, $null, $null)
            }
        }

        function DriveItemName($driveItem) {
            if ( $driveItem | gm Name ) {
                $isContainer = ( $driveItem | gm folder -erroraction ignore ) -ne $null

                $name = __Truncate $driveItem.name 40 6

                if ( $isContainer ) {
                    $::.ColorString.ToSTandardColorString($name, 'Containment', $null, $null)
                } else {
                    $::.ColorString.ToSTandardColorString($name, 'Emphasis2', $null, $null)
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

        function __Truncate([string] $text, [int32] $length, [int32] $suffixLength = 0) {
            if ( $text.length -le $length ) {
                $text
            } else {
                $textSegmentLength = $length - $suffixLength - 3

                $textSegment = $text.substring(0, $textSegmentLength) + '...'

                $suffix = if ( $suffixLength ) {
                    $text.substring($text.length - $suffixLength, $suffixLength)
                } else {
                    ''
                }

                $textSegment + $suffix
            }
        }

        function __GetInvertedStandardColorString([string] $text, [string] $coloring, $criterion, [object[]] $highlightedValues, $disabledValue) {
            $mainColor = $::.ColorString.GetStandardColors($coloring, $criterion, $highlightedValues, $disabledValue)
            $contrast = $::.ColorString.GetColorContrast($mainColor[0])
            $::.ColorString.ToColorString($text, $contrast, $mainColor[0])
        }
    }
}

