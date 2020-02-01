# Copyright 2020, Adam Edwards
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

function CompareCustomObject($object1, $object2) {
    if ( $object1 -eq $null -and $object2 -eq $null ) {
        return $true
    } elseif ( $object1 -eq $null -or $object2 -eq $null ) {
        write-verbose "Mismatch: one object is null, one is not"
        return $false
    }

    $type1 = $object1.gettype()
    $type2 = $object2.gettype()

    if ( $type1 -ne $type2 ) {
        write-verbose "The objects have different types"
        return $false
    }

    # We choose a "duck-typing" approach to detect "HashTable-like" objects so
    # the contents can be compared
    if ( ( $object1 | gm -membertype property keys -erroraction ignore) -and
         ( $object1 | gm -membertype property values -erroraction ignore) -and
         ( $object1 | gm -membertype method add -erroraction ignore) -and
         ( $object1 | gm -membertype method remove -erroraction ignore) -and
         ( $object1 | gm -membertype property count -erroraction ignore) -and
         ( $object1 | gm item -erroraction ignore) ) {
             if ( $object1.count -ne $object2.count ) {
                 write-verbose "Objects are hash tables with a different count of values"
                 return $false
             }

             foreach ( $key in $object1.keys ) {
                 if ( ! $object1.containskey($key) ) {
                     write-verbose "The key '$key' in the first object is not present in the second object"
                     return $false
                 }

                 $value1 = $object1[$key]
                 $value2 = $object2[$key]

                 $result = CompareCustomObject $value1 $value2

                 if ( ! $result ) {
                     write-verbose "The objects are both hash tables and for a given key their values compare as different"
                     return $false
                 }
             }

             return $true
         }

    if ( $type1.isarray ) {
        for ( $current = 0; $current -lt $object1.count; $current++ ) {
            if ( ! ( CompareCustomObject $object1[$current] $object2[$current] ) ) {
                write-verbose "The object is an array and one of the elements in the array does not match the element at the same index in the other array"
                return $false
            }
        }

        return $true
    }

    # TODO: Check for collections that are not arrays or hash table and compare them
    if ( $object1 | gm GetEnumerator -erroraction ignore ) {
#        throw [NotImplementedException]::new('Comparisons for objects that are not collections not yet implemented')
    }

    if ( $object2 | gm GetEnumerator -erroraction ignore ) {
#        throw [NotImplementedException]::new('Comparisons for objects that are not collections not yet implemented')
    }

    $member1 = $object1 | gm -membertype noteproperty
    $member2 = $object2 | gm -membertype noteproperty

    $member1IsNull = $member1 -eq $null
    $member2IsNull = $member2 -eq $null

    if ( $member1IsNull -ne $member2IsNull ) {
        write-verbose 'Query for members on one object returned null, but did not do so for the other object'
        return $false
    }

    if ( $member1IsNull ) {
        $result = $object1 -eq $object2

        if ( ! $result ) {
            write-verbose 'The object were compared directly with an equality operator and equality failed'
        }

        return $result
    }

    $member1Length = 0
    $member2Length = 0

    if ( ( $member1 | gm length -erroraction ignore ) ) {
        $member1Length = $member1.Length
    }

    if ( ( $member2 | gm length -erroraction ignore ) ) {
        $member2Length = $member2.Length
    }

    if ( $member1length -ne $member2length ) {
        write-verbose 'The objects have a different number of members'
        return $false
    }

    foreach ( $member in $member1 ) {
        if ( ! ( $object2 | gm -membertype noteproperty $member.name -erroraction ignore ) ) {
            write-verbose "The second object is missing the member '$($member.name)' which is present in the first object"
            return $false
        }
    }

    foreach ( $member in $member1 ) {
        $value1 = $object1 | select -expandproperty $member.name
        $value2 = $object2 | select -expandproperty $member.name
        if ( ! ( CompareCustomObject $value1 $value2 ) ) {
            write-verbose "The named non-scalar member '$($member.name)' for each object was compared recursively and were found to be different"
            return $false
        }
    }

    return $true
}
