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

            $::.ColorString.ToColorString($preview, 11, $null)
        }

        function SegmentId($segment) {
            $background = $null
            $foreground = $null

            if ( $segment.pstypenames -contains 'GraphSegmentDisplayType' ) {
                $segmentType = $segment.Info[0]
                $foreground = if ( $segmentType -eq 'f' ) {
                    11
                } elseif ( $segmentType -eq 'a' ) {
                    6
                } else {
                    if ( $segment.Collection ) {
                        0
                        if ( $segmentType -eq 'n' ) {
                            $background = 10
                        } else {
                            $background = 6
                        }
                    } else {
                        10
                    }
                }
            }

            $::.ColorString.ToColorString($segment.Id, $foreground, $background)
        }
    }
}
