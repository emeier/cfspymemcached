<cfcomponent extends="mxunit.framework.TestCase" output="false">

    <!--- this will run before every single test in this test case --->
    <cffunction name="setUp" returntype="void" access="public" hint="put things here that you want to run before each test" output="false">
    </cffunction>

    <!--- this will run after every single test in this test case --->
    <cffunction name="tearDown" returntype="void" access="public" hint="put things here that you want to run after each test" output="false">
    </cffunction>

    <!--- this will run once after initialization and before setUp() --->
    <cffunction name="beforeTests" returntype="void" access="public" hint="put things here that you want to run before all tests" output="false">
        <cfset variables.memcachedClient = createObject("component", "spymemcached.MemcachedClient").init(servers="localhost:11211"
            ,protocol="TEXT"
            ,transcoder="JSON") />
    </cffunction>

    <!--- this will run once after all tests have been run --->
    <cffunction name="afterTests" returntype="void" access="public" hint="put things here that you want to run after all tests" output="false">
        <cfset variables.memcachedClient.shutdown() />
    </cffunction>

    <!--- tests --->
    <cffunction name="get_should_returnEmptyString_when_null" returntype="void" output="false">
        <cfset var key = "non_existent_key" />
        <cfset var value = "" />

        <cfset value = variables.memcachedClient.get(key) />

        <cfset assertFalse(Len(Trim(value))) />

    </cffunction>

    <cffunction name="key_should_expire" returntype="void" output="false">
        <cfset var key = "blerg" />
        <cfset var expectedValue = "bar" />
        <cfset var expiry = 1 />
        <cfset var actualValue = "" />

        <cfset variables.memcachedClient.set(key, expectedValue, expiry) />
        <cfset actualValue = variables.memcachedClient.get(key) />

        <cfset assertEquals(expectedValue, actualValue) />

        <cfset sleep(expiry*1000) />
        <cfset actualValue = variables.memcachedClient.get(key) />
        <cfset assertFalse(Len(Trim(actualValue))) />

    </cffunction>

    <cffunction name="key_should_notExist_when_setAndDeleted" returntype="void" output="false">
        <cfset var expectedValue = "who dat" />
        <cfset var actualValue = "" />
        <cfset var key = "key_should_notExist_when_setAndDeleted" />

        <cfset variables.memcachedClient.set(key, expectedValue, 10) />
        <cfset actualValue = variables.memcachedClient.get(key) />

        <cfset assertEquals(expectedValue, actualValue) />

        <cfset variables.memcachedClient.delete(key) />
        <cfset actualValue = variables.memcachedClient.get(key) />
        <cfset assertFalse(Len(Trim(actualValue))) />

    </cffunction>

    <cffunction name="add_should_fail_when_keyExists" returntype="void" output="false">
        <cfset var success = "" />
        <cfset var key = getTickCount() />
        <cfset var value = "foobar" />
        <cfset var expiry = 10 />

        <cfset success = variables.memcachedClient.add(key, value, expiry) />
        <cfset assertTrue(success, "Failed to add the key #key#") />

        <cfset success = variables.memcachedClient.add(key, value, expiry) />
        <cfset assertFalse(success, "Key that already exists was added.") />

    </cffunction>

    <cffunction name="key_should_incrementAndDecrement" returntype="void" output="false">
        <cfset var expectedValue = 14 />
        <cfset var actualValue = 0 />
        <cfset var key = "gobears" />
        <cfset var expiry = 1 />

        <cfset actualValue = variables.memcachedClient.incr(key=key, expiry=expiry) />
        <cfset actualValue = variables.memcachedClient.incr(key=key, by=20, expiry=expiry) />
        <cfset actualValue = variables.memcachedClient.decr(key=key, expiry=expiry) />
        <cfset actualValue = variables.memcachedClient.decr(key=key, by=6, expiry=expiry) />

        <cfset assertEquals(expectedValue, actualValue) />

    </cffunction>

    <cffunction name="setAndGet_should_storeAndRetrieveString" returntype="void" output="false">
        <cfset var expectedValue = "a string of some kind" />
        <cfset var actualValue = "" />
        <cfset var key = "setAndGet_should_storeAndRetrieveString" />

        <cfset variables.memcachedClient.set(key, expectedValue, 10) />
        <cfset actualValue = variables.memcachedClient.get(key) />

        <cfset assertEquals(expectedValue, actualValue) />

    </cffunction>

    <cffunction name="setAndGet_should_storeAndRetrieveArray" returntype="void" output="false">
        <cfset var expectedValue = [] />
        <cfset var actualValue = "" />
        <cfset var key = "setAndGet_should_storeAndRetrieveArray" />

        <cfset arrayAppend(expectedValue, "first item") />
        <cfset arrayAppend(expectedValue, "second item") />

        <cfset variables.memcachedClient.set(key, expectedValue, 10) />
        <cfset actualValue = variables.memcachedClient.get(key) />

        <cfset assertEquals(expectedValue, actualValue) />

    </cffunction>

    <cffunction name="setAndGet_should_storeAndRetrieveStruct" returntype="void" output="false">
        <cfset var expectedValue = {} />
        <cfset var actualValue = "" />
        <cfset var key = "setAndGet_should_storeAndRetrieveStruct" />

        <cfset expectedValue.first = "something" />
        <cfset expectedValue.second = "something else" />

        <cfset variables.memcachedClient.set(key, expectedValue, 10) />
        <cfset actualValue = variables.memcachedClient.get(key) />

        <cfset assertEquals(expectedValue, actualValue) />

    </cffunction>

    <cffunction name="setAndGet_should_storeAndRetrieveQuery" returntype="void" output="false">
        <cfset var expectedValue = queryNew("id,title") />
        <cfset var actualValue = "" />
        <cfset var key = "setAndGet_should_storeAndRetrieveString" />

        <cfset queryAddRow(expectedValue) />
        <cfset querySetCell(expectedValue, "id", 45) />
        <cfset querySetCell(expectedValue, "title", "first title") />
        <cfset queryAddRow(expectedValue) />
        <cfset querySetCell(expectedValue, "id", 99) />
        <cfset querySetCell(expectedValue, "title", "second title") />

        <cfset variables.memcachedClient.set(key, expectedValue, 10) />
        <cfset actualValue = variables.memcachedClient.get(key) />

        <cfset assertEquals(expectedValue, actualValue) />

    </cffunction>

    <cffunction name="test_stats" returntype="void" output="false">
        <cfset var stats = variables.memcachedClient.getStats() />

        <cfset assertTrue(structKeyExists(stats["localhost/127.0.0.1:11211"], "pid")) />

    </cffunction>

    <cffunction name="test_versions" returntype="void" output="false">
        <cfset var versions = variables.memcachedClient.getVersions() />

        <cfset assertTrue(Len(versions["localhost/127.0.0.1:11211"])) />

    </cffunction>

</cfcomponent>