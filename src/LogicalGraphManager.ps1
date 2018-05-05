# Copyright 2018, Adam Edwards
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

. (import-script GraphContext)

ScriptClass LogicalGraphManager {
    $contexts = $null
    $lowestIndex = 0
    $highestIndex = 0

    function __initialize {
        if ( $this.scriptclass.sessionmanager -ne $null ) {
            throw "Singleton LogicalGraphManager instance already exists"
        }
        $this.contexts = @{}
    }

    function NewContext($parentContext = $null, $connection, $apiversion, $name = $null) {
        if ( ! $apiVersion -and ! $parentContext) {
            throw "An api version or parent context must be specified"
        }

        if ( ! $connection -and ! $parentContext ) {
            throw "A connection or parent context must be specified"
        }

        $version = if ( $apiVersion ) {
            $apiVersion
        } else {
            $parentContext.version
        }

        $graphConnection = if ( $connection ) {
            $connection
        } else {
            $parentContext.connection
        }

        $addIndex = -1
        $uniqueName = if ( $name -and $name -ne '' ) {
            $name
        } else {
            "{0}:{1}" -f $graphConnection.GraphEndpoint.Graph, $version
        }

        $contextName = if ( $this.contexts.containskey($uniqueName) ) {
            $addIndex = $this.lowestIndex
            "{0}{1}" -f $uniqueName, $addIndex
        } else {
            $uniqueName
        }

        $context = new-so GraphContext $graphConnection $version $contextName

        $this.contexts.Add($contextName, [PSCustomObject]@{Context=$context;Index=$addIndex})

        if ( $addIndex -eq -1 ) {
            $this.lowestIndex = ( $this.highestIndex + 1 ) % 0xFFFFFF
            $this.highestIndex = $this.lowestIndex
        }

        $context
    }

    function RemoveContext($name) {
        $contextRecord = $this.contexts[$name]
        if ( ! $contextRecord ) {
            throw "Context '$name' cannot be removed because it does not exist"
        }

        $this.contexts.remove($name)

        if ($contextRecord.Index -lt $this.lowestIndex) {
            $this.lowestIndex = $contextRecord.index
        }

        if ($contextRecord.Index -gt $this.highestIndex) {
            $this.highestIndex = $this.highestIndex - 1
        }
    }

    function GetContext($name) {
        $contextRecord = $this.contexts[$name]

        if ($contextRecord) {
            $contextRecord.context
        }
    }

    static {
        function __initialize { if ( ! $this.sessionManager ) { $this.sessionManager = new-so LogicalGraphManager } }
        $sessionManager = $null
        function Get {
            $this.sessionManager
        }
    }
}

$::.LogicalGraphManager |=> __initialize
