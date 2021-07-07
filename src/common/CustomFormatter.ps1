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
    }
}

