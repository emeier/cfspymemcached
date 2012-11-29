<cfcomponent hint="ColdFusion component for spymemcached java client." output="false">

    <cfset variables.LOG_FILE = "memcachedClient" />

    <!--- constructor --->
    <cffunction name="init" access="public" returntype="any" output="false">
        <cfargument name="servers" type="string" required="true" />
        <cfargument name="operationTimeout" type="numeric" required="false" default="2500" />
        <cfargument name="protocol" type="string" required="false" default="TEXT" hint="TEXT or BINARY"/>
        <cfargument name="locator" type="string" required="false" default="ARRAY_MOD" hint="ARRAY_MOD, CONSISTENT or VBUCKET" />

        <cfset var useJavaLoader = true />

        <cflog type="information" file="#variables.LOG_FILE#" text="Starting up MemcachedClient." />

        <cfset arguments.servers = Replace(arguments.servers,","," ","all") />

        <cfset variables.timeoutUnit = CreateObject("java","java.util.concurrent.TimeUnit").MILLISECONDS />
        <cfset variables.operationTimeout = arguments.operationTimeout />

        <cfif useJavaLoader>
            <cfset setMemcachedClient(createClientJavaLoader(argumentCollection=arguments)) />
        <cfelse>
            <cfset setMemcachedClient(createClientJava(argumentCollection=arguments)) />
        </cfif>

        <cfreturn this />
    </cffunction>

    <cffunction name="createClientJava" access="public" returntype="any" output="false">
        <cfargument name="servers" type="string" required="true" />
        <cfargument name="operationTimeout" type="numeric" required="false" default="2500" />
        <cfargument name="protocol" type="string" required="false" default="TEXT" hint="TEXT or BINARY"/>
        <cfargument name="locator" type="string" required="false" default="ARRAY_MOD" hint="ARRAY_MOD, CONSISTENT or VBUCKET" />

        <cfset var connectionFactory = "" />
        <cfset var addresses = "" />
        <cfset var protocolType = "" />
        <cfset var locatorType = "" />

        <cfset protocolType = CreateObject("java","net.spy.memcached.ConnectionFactoryBuilder$Protocol") />
        <cfset locatorType = CreateObject("java","net.spy.memcached.ConnectionFactoryBuilder$Locator") />
        <cfset connectionFactory = CreateObject("java","net.spy.memcached.ConnectionFactoryBuilder")
            .setProtocol(protocolType[arguments.protocol])
            .setLocatorType(locatorType[arguments.locator])
            .setOpTimeout(arguments.operationTimeout)
            .build() />

        <cflog type="information" file="#variables.LOG_FILE#" text="#connectionFactory.toString()#" />

        <cfset addresses = CreateObject("java","net.spy.memcached.AddrUtil").getAddresses(arguments.servers) />

        <cfreturn CreateObject("java","net.spy.memcached.MemcachedClient").init(connectionFactory,addresses) />
    </cffunction>

    <cffunction name="createClientJavaLoader" access="public" returntype="any" output="false">
        <cfargument name="servers" type="string" required="true" />
        <cfargument name="operationTimeout" type="numeric" required="false" default="2500" />
        <cfargument name="protocol" type="string" required="false" default="TEXT" hint="TEXT or BINARY"/>
        <cfargument name="locator" type="string" required="false" default="ARRAY_MOD" hint="ARRAY_MOD, CONSISTENT or VBUCKET" />

        <cfset var scopeKey = "spymemcached.f824e7a0-39dd-11e2-81c1-0800200c9a66" />
        <cfset var libDirectory = GetDirectoryFromPath(GetCurrentTemplatePath()) & "lib/" />
        <cfset var paths = ArrayNew(1) />
        <cfset var javaLoader = "" />
        <cfset var connectionFactory = "" />
        <cfset var addresses = "" />
        <cfset var protocolType = "" />
        <cfset var locatorType = "" />

        <cfset paths[1] = libDirectory & "spymemcached-2.8.4.jar" />

        <cfif NOT StructKeyExists(server,scopeKey)>
            <cflock name="spymemcached.MemcachedClient.init" throwontimeout="true" timeout="60">
                <cfif NOT StructKeyExists(server,scopeKey)>
                    <cfset server[scopeKey] = CreateObject("component","spymemcached.util.javaloader.JavaLoader").init(paths) />
                </cfif>
            </cflock>
        </cfif>

        <cfset javaLoader = server[scopeKey] />

        <cfset protocolType = javaLoader.create("net.spy.memcached.ConnectionFactoryBuilder$Protocol") />
        <cfset locatorType = javaLoader.create("net.spy.memcached.ConnectionFactoryBuilder$Locator") />
        <cfset connectionFactory = javaLoader.create("net.spy.memcached.ConnectionFactoryBuilder")
            .setProtocol(protocolType[arguments.protocol])
            .setLocatorType(locatorType[arguments.locator])
            .setOpTimeout(arguments.operationTimeout)
            .build() />

        <cflog type="information" file="#variables.LOG_FILE#" text="#connectionFactory.toString()#" />

        <cfset addresses = javaLoader.create("net.spy.memcached.AddrUtil").getAddresses(arguments.servers) />

        <cfreturn javaLoader.create("net.spy.memcached.MemcachedClient").init(connectionFactory,addresses) />
    </cffunction>

    <!--- public methods --->
    <cffunction name="add" returntype="boolean" output="false"
        hint="Add an object to the cache (using the default transcoder) if it does not exist already.">
        <cfargument name="key" type="string" required="true" />
        <cfargument name="value" type="any" required="true" />
        <cfargument name="expiry" type="numeric" default="0" />

        <cfset var local = {} />
        <cfset var success = true />

        <cftry>
            <cfset local.futureTask = getMemcachedClient().add(arguments.key,arguments.expiry,serializeObject(arguments.value)) />
            <cfset success = local.futureTask.get() />
            <cfcatch>
                <cfset success = false />
                <cfset handleException("add",arguments.key,cfcatch) />
            </cfcatch>
        </cftry>

        <cfreturn success />
    </cffunction>

    <cffunction name="asyncGet" access="public" returntype="any" output="false"
        hint="Get the given key asynchronously and decode with the default transcoder.">
        <cfargument name="key" type="string" required="true" />
        <cfargument name="timeout" type="numeric" required="false" default="400" hint="Number in milliseconds to timeout and cancel this operation.">

        <cfset var local = {} />

        <cfset local.value = "" />

        <cfset local.futureTask = getMemcachedClient().asyncGet(arguments.key) />

        <cftry>
            <cfset local.value = local.futureTask.get(variables.operationTimeout,variables.timeoutUnit) />

            <!--- catch nulls --->
            <cfif NOT StructKeyExists(local,"value")>
                <cfset local.value = "" />
            </cfif>

            <cfset local.value = deserializeObject(local.value) />

            <cfcatch>
                <cfset local.futureTask.cancel(true) />
                <cfset local.value = "" />
                <cfset handleException("asyncGet",arguments.key,cfcatch) />
            </cfcatch>
        </cftry>

        <cfreturn local.value />
    </cffunction>

    <cffunction name="decr" access="public" returntype="numeric" output="false"
        hint="Decrement the given counter, returning the new value.">
        <cfargument name="key" type="string" required="true" />
        <cfargument name="by" type="numeric" required="false" default="1" />
        <cfargument name="def" type="numeric" required="false" default="1" />
        <cfargument name="expiry" type="numeric" required="false" default="0" />

        <cfset var value = 0 />

        <cftry>
            <cfset value = getMemcachedClient().decr(arguments.key,arguments.by,arguments.def,arguments.expiry) />
            <cfcatch>
                <cfset handleException("decr",arguments.key,cfcatch) />
            </cfcatch>
        </cftry>

        <cfreturn value />
    </cffunction>

    <cffunction name="delete" access="public" returntype="any" output="false"
        hint="Delete the given key from the cache.">
        <cfargument name="key" type="string" required="true" />

        <cfset var futureTask = "" />

        <cftry>
            <cfset futureTask = getMemcachedClient().delete(arguments.key) />
            <cfcatch>
                <cfset handleException("delete",arguments.key,cfcatch) />
            </cfcatch>
        </cftry>

        <cfreturn futureTask />
    </cffunction>

    <cffunction name="get" access="public" returntype="any" output="false"
        hint="Get with a single key and decode using the default transcoder. (synchronous)">
        <cfargument name="key" type="string" required="true" />

        <cfset var local = {} />

        <cfset local.value = "" />

        <cftry>
            <cfset local.value = getMemcachedClient().get(arguments.key) />

            <!--- catch nulls --->
            <cfif NOT StructKeyExists(local,"value")>
                <cfset local.value = "" />
            </cfif>

            <cfset local.value = deserializeObject(local.value) />

            <cfcatch>
                <cfset local.value = "" />
                <cfset handleException("get",arguments.key,cfcatch) />
                <!--- cfrethrow / --->
            </cfcatch>
        </cftry>

        <cfreturn local.value />
    </cffunction>

    <cffunction name="incr" access="public" returntype="numeric" output="false"
        hint="Increment the given counter, returning the new value.">
        <cfargument name="key" type="string" required="true" />
        <cfargument name="by" type="numeric" required="false" default="1" />
        <cfargument name="def" type="numeric" required="false" default="1" />
        <cfargument name="expiry" type="numeric" required="false" default="0" />

        <cfset var value = 0 />

        <cftry>
            <cfset value = getMemcachedClient().incr(arguments.key,arguments.by,arguments.def,arguments.expiry) />
            <cfcatch>
                <cfset handleException("incr",arguments.key,cfcatch) />
            </cfcatch>
        </cftry>

        <cfreturn value />
    </cffunction>

    <cffunction name="set" access="public" returntype="any" output="false"
        hint="Set an object in the cache (using the default transcoder) regardless of any existing value.">
        <cfargument name="key" type="string" required="true" />
        <cfargument name="value" type="any" required="true" />
        <cfargument name="expiry" type="numeric" required="false" default="60" />

        <cfset var futureTask = "" />

        <cftry>
            <cfset futureTask = getMemcachedClient().set(arguments.key,arguments.expiry,serializeObject(arguments.value)) />
            <cfcatch>
                <cfset handleException("set",arguments.key,cfcatch) />
            </cfcatch>
        </cftry>

        <cfreturn futureTask />
    </cffunction>

    <cffunction name="shutdown" returntype="void" output="false"
        hint="Shut down immediately">

        <cflog type="information" file="#variables.LOG_FILE#" text="Shutting down MemcachedClient." />
        <cfset getMemcachedClient().shutdown() />

    </cffunction>

    <cffunction name="touch" access="public" returntype="any" output="false"
        hint="Touch the given key to reset its expiration time with the default transcoder.">
        <cfargument name="key" type="string" required="true" />
        <cfargument name="expiry" type="numeric" required="true" />

        <cfset var futureTask = "" />

        <cftry>
            <cfset futureTask = getMemcachedClient().touch(arguments.key,arguments.expiry) />
            <cfcatch>
                <cfset handleException("touch",arguments.key,cfcatch) />
            </cfcatch>
        </cftry>

        <cfreturn futureTask />
    </cffunction>

    <cffunction name="keyExists" access="public" returntype="boolean" output="false"
        hint="Check for the existence of a key and return true or false.">
        <cfargument name="key" type="string" required="true" />

        <cfset var hasKey = true />
        <cfset var value = "" />

        <cfset value = get(arguments.key) />

        <cfif IsSimpleValue(value) AND NOT Len(value)>
            <cfset hasKey = false />
        </cfif>

        <cfreturn hasKey />
    </cffunction>

    <!--- server functions --->
    <cffunction name="flush" access="public" returntype="any" output="false"
        hint="Flush all caches from all servers immediately.">

        <cfset var futureTask = "" />

        <cftry>
            <cfset futureTask = getMemcachedClient().flush() />
            <cfcatch>
                <cfset handleException(operation="flush",exception=cfcatch) />
            </cfcatch>
        </cftry>

        <cfreturn futureTask />
    </cffunction>

    <cffunction name="getAvailableServers" access="public" returntype="any" output="false"
        hint="Get the addresses of available servers.">
        <cfreturn getMemcachedClient().getAvailableServers() />
    </cffunction>

    <cffunction name="getStats" access="public" returntype="any" output="false"
        hint="Get all of the stats from all of the connections.">
        <cfset var stats = {} />

        <cfset stats = mapToStruct(getMemcachedClient().getStats()) />

        <cfreturn stats />
    </cffunction>

    <cffunction name="getUnavailableServers" access="public" returntype="any" output="false"
        hint="Get the addresses of unavailable servers.">
        <cfreturn getMemcachedClient().getUnavailableServers() />
    </cffunction>

    <cffunction name="getVersions" access="public" returntype="any" output="false"
        hint="Get the versions of all of the connected memcacheds.">
        <cfset var versions = {} />

        <cfset versions = mapToStruct(getMemcachedClient().getVersions()) />

        <cfreturn versions />
    </cffunction>

    <!--- accessors --->
    <cffunction name="setMemcachedClient" access="public" returntype="void" output="false">
        <cfargument name="memcachedClient" type="any" required="true" />
        <cfset variables.memcachedClient = arguments.memcachedClient />
    </cffunction>
    <cffunction name="getMemcachedClient" access="public" returntype="any" output="false">
        <cfreturn variables.memcachedClient />
    </cffunction>

    <!--- private methods --->
    <cffunction name="serializeObject" access="private" returntype="any" output="false">
        <cfargument name="value" type="any" required="true" />

        <cfset var byteArrayOutputStream = "" />
        <cfset var objectOutputStream = "" />
        <cfset var serializedValue = "" />

        <cfif IsSimpleValue(arguments.value)>
            <cfreturn arguments.value />
        <cfelse>
            <cfset byteArrayOutputStream = CreateObject("java","java.io.ByteArrayOutputStream").init() />
            <cfset objectOutputStream = CreateObject("java","java.io.ObjectOutputStream").init(byteArrayOutputStream) />
            <cfset objectOutputStream.writeObject(arguments.value) />
            <cfset serializedValue = byteArrayOutputStream.toByteArray() />
            <cfset objectOutputStream.close() />
            <cfset byteArrayOutputStream.close() />
        </cfif>

        <cfreturn serializedValue />
    </cffunction>

    <cffunction name="deserializeObject" access="private" returntype="any" output="false">
        <cfargument name="value" type="any" required="true" />

        <cfset var deserializedValue = "" />
        <cfset var objectInputStream = "" />
        <cfset var byteArrayInputStream = "" />

        <cfif IsSimpleValue(arguments.value)>
            <cfreturn arguments.value />
        <cfelse>
            <cfset objectInputStream = CreateObject("java","java.io.ObjectInputStream") />
            <cfset byteArrayInputStream = CreateObject("java","java.io.ByteArrayInputStream") />
            <cfset objectInputStream.init(byteArrayInputStream.init(arguments.value)) />
            <cfset deserializedValue = objectInputStream.readObject() />
            <cfset objectInputStream.close() />
            <cfset byteArrayInputStream.close() />
        </cfif>

        <cfreturn deserializedValue />
    </cffunction>

    <cffunction name="mapToStruct" access="private" returntype="struct" output="false">
        <cfargument name="map" type="any" required="true" />

        <cfset var theStruct = {} />
        <cfset var entrySet = "" />
        <cfset var iterator = "" />
        <cfset var entry = "" />
        <cfset var key = "" />
        <cfset var value = "" />

        <cfset entrySet = arguments.map.entrySet() />
        <cfset iterator = entrySet.iterator() />

        <cfloop condition="#iterator.hasNext()#">
            <cfset entry = iterator.next() />
            <cfset key = entry.getKey() />
            <cfset value = entry.getValue() />
            <cfset theStruct[key] = value />
        </cfloop>

        <cfreturn theStruct />
    </cffunction>

    <cffunction name="validateKey" access="private" returntype="string" output="false">
        <cfargument name="key" type="string" required="true" />

        <cfif Len(arguments.key) GT getMemcachedClient().MAX_KEY_LENGTH>
            <cfset arguments.key = Hash(arguments.key,"SHA") />
        </cfif>

        <cfreturn arguments.key />
    </cffunction>

    <!--- exception handler --->
    <cffunction name="handleException" access="private" returntype="void" output="false">
        <cfargument name="operation" type="string" required="true" />
        <cfargument name="key" type="string" required="false" default="" />
        <cfargument name="exception" type="any" required="true" />

        <cfset var errorMessage = "" />

        <cfset errorMessage = "Operation='#arguments.operation#'" />

        <cfif Len(arguments.key)>
            <cfset errorMessage = errorMessage & " Key='#arguments.key#'" />
        </cfif>

        <cfif Len(arguments.exception.type)>
            <cfset errorMessage = errorMessage & " Type='#arguments.exception.type#'" />
        </cfif>

        <cfset errorMessage = errorMessage & " Message='#arguments.exception.message#'" />

        <cfif Len(arguments.exception.stackTrace)>
            <cfset errorMessage = errorMessage & " StackTrace='#arguments.exception.stackTrace#'" />
        </cfif>

        <cflog type="error" file="#variables.LOG_FILE#" text="#errorMessage#" />

    </cffunction>

    <!--- debug function --->
    <cffunction name="getMemento" access="public" returntype="any" output="false">
        <cfreturn variables />
    </cffunction>

</cfcomponent>