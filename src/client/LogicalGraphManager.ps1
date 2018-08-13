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

throw 'dont use this file'
. (import-script GraphContext)

ScriptClass LogicalGraphManager {
    $contexts = $null

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

        $uniqueName = if ( $name -and $name -ne '' ) {
            $name
        } else {
            $version
        }

        $contextName = if ( $this.contexts.containskey($uniqueName) ) {
            $secondName = "{0}_{1}" -f $uniqueName, $this.contexts.count

            if ( $this.contexts.containskey($secondName) ) {
                $secondName = "{0}_{1}" -f $uniqueName, $this.ScriptClass.idGenerator.Next()
                if ( $this.contexts.containskey($secondName) ) {
                    $secondName = "{0}_{1}" -f $uniqueName, (new-guid).tostring()
                }
            }
            $secondName
        } else {
            $uniqueName
        }

        $context = new-so GraphContext $graphConnection $version $contextName

        $this.contexts.Add($contextName, [PSCustomObject]@{Context=$context})

        $context
    }

    function RemoveContext($name) {
        $contextRecord = $this.contexts[$name]
        if ( ! $contextRecord ) {
            throw "Context '$name' cannot be removed because it does not exist"
        }

        $this.contexts.remove($name)
    }

    function GetContext($name) {
        if ( $name -and $name -ne '' ) {
            $contextRecord = $this.contexts[$name]

            if ($contextRecord) {
                $contextRecord.context
            }
        } else {
            $this.contexts.values | select -expandproperty Context
        }
    }

    function FindContext($endpoint, $version) {
        $this.contexts.values | foreach {
            if ( $_.context.connection.graphEndpoint.Graph.tostring() -eq $endpoint -and $_.context.version -eq $version ) {
                return $_.context
            }
        }
    }


    static {
        function __initialize { if ( ! $this.sessionManager ) { $this.sessionManager = new-so LogicalGraphManager } }
        $sessionManager = $null
        $idGenerator = [Random]::new([int32] ([DateTime]::now.Ticks % 0XFFFFFFFF))
        function Get {
            $this.sessionManager
        }
    }
}

$::.LogicalGraphManager |=> __initialize
