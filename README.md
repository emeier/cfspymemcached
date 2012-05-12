ColdFusion memcached client
==============

ColdFusion wrapper for the <a href="http://code.google.com/p/spymemcached/">spymemcached</a> java client

Usage
-----

Create a MemcachedClient in the application scope.

	<cfset application.memcachedClient = CreateObject("component","spymemcached.MemcachedClient").init("localhost:11211") />

After connecting, you can start to make requests.

	<cfset application.memcachedClient.set("foo","bar",300) />

	<cfset foo = application.memcachedClient.get("foo") />

	<cfset application.memcachedClient.delete("foo") />

All the basic commands (set, get, delete, add, etc...) are available, more advanced CAS commands have not yet been implemented

If you reload the application, you'll want to shutdown the client first:

	<cfset application.memcachedClient.shutdown() />