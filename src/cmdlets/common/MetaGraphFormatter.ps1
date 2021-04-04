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
        function SegmentInfo($segment) {
            $segment.Info
        }

        function SegmentType($segment) {
            $segment.Type
        }

        function SegmentPreview($segment) {
            $::.ColorString.ToColorString($segment.Preview, 11, $null)
        }

        function SegmentId($segment) {
            $segmentType = $segment.Info[0]
            $background = $null

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

            $::.ColorString.ToColorString($segment.Id, $foreground, $background)
        }
    }
}
