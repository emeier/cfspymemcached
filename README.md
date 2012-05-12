ColdFusion memcached client
==============

ColdFusion wrapper for the <a href="http://code.google.com/p/spymemcached/">spymemcached</a> java client

Installation
------------

Copy the 'spymemcached' folder into your application root or create a mapping to it.

By default, the client loads the spymemcached jar (2.7.3) using <a href="http://javaloader.riaforge.org/">javaLoader</a>

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