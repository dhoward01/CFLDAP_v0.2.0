<!---
	Name:			/Application.cfc
	Last Updated:	1/22/06
	History:		Oops, error email said LHP, not Harlan (thanks sneakylama) (1/22/06)
--->

<cfcomponent output="false">

	<!--- Generate a name based on file location. Makes it easier to share with other adservers on the same box. --->
	<cfset prefix = getCurrentTemplatePath()>
	<cfset prefix = reReplace(prefix, "[^a-zA-Z]","","all")>
	<cfset prefix = right(prefix, 64 - len("_AdServer"))>
	
	<cfset this.name = "#prefix#_AdServer">
	<cfset this.applicationTimeout = createTimeSpan(0,2,0,0)>
	<cfset this.loginStorage = "session">
	<cfset this.sessionManagement = true>
	<cfset this.sessionTimeout = createTimeSpan(0,0,20,0)>

	<cfsetting enablecfoutputonly=true>
	
	<cffunction name="onApplicationStart" returnType="boolean" output="false">
		<cfset var xmlFile = "">
		<cfset var xmlData = "">
		<cfset var rootDir = getDirectoryFromPath(getCurrentTemplatePath())>
		<cfset var key = "">
		<cfset var groups = "">
		
		<!--- load settings --->
		<cffile action="read" file="#rootdir#/defaults.cfm" variable="xmlFile">
		<!--- Remove comments --->
		<cfset xmlFile = replace(xmlFile, "<!---","")>
		<cfset xmlFile = trim(replace(xmlFile, "--->",""))>
		
		<cfset xmlData = xmlParse(xmlFile)>
		<cfloop item="key" collection="#xmlData.initvals.defaults#">
			<cfset application[key] = xmlData.initvals.defaults[key].xmlText>
		</cfloop>

		<cfset application.userDAO = createObject("component","components.UserDAO").init(application.dsn)>
		<cfset application.userManager = createObject("component","components.UserManager").init(application.dsn)>

		<cfset application.clientDAO = createObject("component","components.ClientDAO").init(application.dsn)>
		<cfset application.clientManager = createObject("component","components.ClientManager").init(application.dsn)>

		<cfset application.adDAO = createObject("component","components.AdDAO").init(application.dsn)>
		<cfset application.adManager = createObject("component","components.AdManager").init(application.dsn)>

		<cfset application.campaignDAO = createObject("component","components.CampaignDAO").init(application.dsn)>
		<cfset application.campaignManager = createObject("component","components.CampaignManager").init(application.dsn)>

		<cfset application.utils = createObject("component","components.Utils")>
				
		<cfreturn true>
	</cffunction>
	
	<cffunction name="onApplicationEnd" returnType="void" output="false">
		<cfargument name="applicationScope" required="true">
	</cffunction>

	<cffunction name="onRequestStart" returnType="boolean" output="false">
		<cfargument name="thePage" type="string" required="true">
		<cfset var showLogin = true>
		<cfset var roles = "">
		
		<cfsetting showdebugoutput="false">
		<cfif isDefined("url.logout")>
			<cflogout>
		</cfif>
		
		<cfif isDefined("url.reinit")>
			<cfset onApplicationStart()>
		</cfif>
		
		<cfsetting enablecfoutputonly=true>

		<!--- Ignore security for adserver.cfm --->
		<cfif listLast(arguments.thePage,"/") is "adserver.cfm" or listLast(arguments.thePage,"/") is "adbouncer.cfm">
			<cfreturn true>
		</cfif>
		
		<cflogin>
		
			<cfif isDefined("form.login") and isDefined("form.username") and isDefined("form.password")>
				<cfif application.userManager.authenticate(form.username, form.password)>
					<cfset session.userBean = application.userManager.getUserByUsername(form.username)>
					<cfset roles = application.userManager.getGroupsForUser(session.userBean.getID())>
					<cfset showLogin = false>
					<cfloginuser name="#form.username#" password="#form.password#" roles="#roles#">
				<cfelse>
					<cfset loginError = "Invalid user details.">	
				</cfif>
			</cfif>
			
			<cfif showLogin>
				<cfinclude template="login.cfm">
				<cfabort>
			</cfif>
		</cflogin>

		<cfreturn true>
	</cffunction>
	
	<cffunction name="onRequest" returnType="void">
		<cfargument name="thePage" type="string" required="true">
		<cfinclude template="includes/udfs.cfm">
		<cfinclude template="#arguments.thePage#">		
	</cffunction>

	<cffunction name="onRequestEnd" returnType="void" output="false">
		<cfargument name="thePage" type="string" required="true">
	</cffunction>

	<cffunction name="onError" returnType="void" output="true">
		<cfargument name="exception" required="true">
		<cfargument name="eventname" type="string" required="true">

		<cfif structKeyExists(arguments.exception,"rootcause") and arguments.exception.rootcause.type is "coldfusion.runtime.AbortException">
			<cfreturn>
		</cfif>
				
		<cfmail to="#application.adminemail#" from="#application.adminemail#" subject="Error in Harlan Ad Server" type="html">
An error has occured in AdServer. 

Event Name: #arguments.eventname#

Error Info:
Message: 		#arguments.exception.message#
Detail:			#arguments.exception.detail#
Root Cause: 	
<cfif structKeyExists(arguments.exception,"rootcause")><cfdump var="#arguments.exception.rootcause#"></cfif>
Type:			#arguments.exception.type#
Template:		#cgi.script_name#?#cgi.query_string#
Tag Context:
<cfif structKeyExists(arguments.exception,"rootcause")><cfdump var="#arguments.exception.rootcause.tagcontext#"></cfif>
		</cfmail>
		<cfinclude template="error.cfm">
	</cffunction>

	<cffunction name="onSessionStart" returnType="void" output="false">
	</cffunction>
	
	<cffunction name="onSessionEnd" returnType="void" output="false">
		<cfargument name="sessionScope" type="struct" required="true">
		<cfargument name="appScope" type="struct" required="false">
	</cffunction>

</cfcomponent>