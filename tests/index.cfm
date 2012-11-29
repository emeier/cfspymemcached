<cfsilent>
    <cfparam name="url.output" default="html">

    <cfset componentPath = "tests." />
    <cfset physicalDirectory = GetDirectoryFromPath(getCurrentTemplatePath()) />
    <cfset excludes = "" />
    <cfset testResults = CreateObject("component","mxunit.runner.DirectoryTestSuite").run(
        directory=physicalDirectory
        ,componentPath=componentPath
        ,recurse=true
        ,excludes=excludes) />
</cfsilent>
<cfoutput>#testResults.getResultsOutput(url.output)#</cfoutput>