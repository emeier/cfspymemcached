<cfcomponent output="false">

    <cfsetting requesttimeout="600" />

    <cfset this.applicationRoot = getDirectoryFromPath(getCurrentTemplatePath()) />

    <cfset this.name = "cfspymemcachedtests_" & Hash(getCurrentTemplatePath()) />
    <cfset this.mappings = {} />
    <cfset this.mappings["/spymemcached"] = "#this.applicationRoot#../spymemcached" />
    <cfset this.mappings["/tests"] = this.applicationRoot />

</cfcomponent>