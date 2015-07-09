<cfsetting showdebugoutput=false>
<!---
	Name:			/adserver.cfm
	Last Updated:	4/20/07
	History:		Support for target, plus a html fix (1/23/06)
					Forgot to include host! This meant remote ad serving failed. Thanks to Critter for finding this. (rkc 1/27/06)
					Prevent non-active ads from showing.
					html ads (4/20/07)
	Notes:
	
	This is the main drivers to handle ad generation. It requires that either an add id is passed in (a), or
	a campaign id (c).
--->

<cfif not isDefined("url.a") and not isDefined("url.c")>
	<cfabort>
</cfif>

<cfif isDefined("url.x")>
	<cfset structDelete(application,"adcache")>
</cfif>

<cfif isDefined("url.c")>
	<cfif not isValid("UUID",url.c)>
		<cfabort>
	</cfif>
	<cfset campaign = application.campaignDAO.read(url.c)>
	<cfif campaign.getID() neq url.c or not campaign.getActive()>
		<cfabort>
	</cfif>
	<!--- 
	  	Ok, we have a valid campaign. First we need to determine if the campaign is in ram already.
		If so, we have a list that corresponds to each add and it's weight.
		
		First - do we have the global cache?
	--->
	<cflock name="#application.lockname#" type="readOnly" timeout="30">
	<cfif not structKeyExists(application,"adcache")>
		<cfset needInit = true>
	</cfif>
	</cflock>
	<cfif isDefined("variables.needInit")>
		<cflock name="#application.lockname#" type="exclusive" timeout="30">
		<cfif not structKeyExists(application,"adcache")>			
			<cfset application.adcache = structNew()>
		</cfif>
		</cflock>
	</cfif>

	<!--- Do we have a cache for this campaign? --->
	<cflock name="#application.lockname#" type="readOnly" timeout="30">
	<cfif not structKeyExists(application.adcache,campaign.getID())>
		<cfset needCampaignInit = true>
	</cfif>
	</cflock>
	<cfif isDefined("variables.needCampaignInit")>
		<!--- 
			  Not sure about this. It locks the entire cache for one campaign. But then I worry that if I do this the top level lock
			  would be in sync. Maybe a thread could get here while a thread checking for cache existing gets stalled.
			  I need to research this I think.
		--->  
		<cflock name="#application.lockname#" type="exclusive" timeout="30">
		<cfif not structKeyExists(application.adcache,campaign.getID())>
			<!--- We now create the initial data in our cache. --->
			<!--- All we cache is the ads and marker --->
			
			<cfset application.adcache[campaign.getID()] = structNew()>
			<cfset application.adcache[campaign.getID()].ads = application.campaignManager.getScheduledAds(campaign.getID())>
			<cfset application.adcache[campaign.getID()].marker = 0>
		</cfif>
		</cflock>
	</cfif>

<!---<cfoutput><cfdump var="#application.campaignManager.getScheduledAds(campaign.getID())#"></cfoutput>--->

	<!--- Ok, so at this point, we darn well better have our cache --->
	<cfif not structKeyExists(application.adcache,campaign.getID()) or not structKeyExists(application.adcache[campaign.getID()], "ads")>
		<cfabort>
	</cfif>

	<cfset data = application.adcache[campaign.getID()]>
	
	<!--- Any ads at all? --->
	<cfif data.ads.recordCount is 0>
		<cfabort>
	</cfif>

	<!--- increment marker --->
	<cflock name="#application.lockname#" type="exclusive" timeout="30">
	<cfset data.marker = data.marker + 1>
	<cfset counter = 0>
	<cfloop query="data.ads">
		<!--- create a quick tmp date out of our times --->
		<cfif timebegin is not "">
			<cfset dt = parseDateTime(timebegin)>
			<cfset dTimeBegin = createDateTime(year(now()), month(now()), day(now()), hour(dt), minute(dt), second(dt))>
		</cfif>
		<cfif timeend is not "">
			<cfset dt = parseDateTime(timeend)>
			<cfset dTimeEnd = createDateTime(year(now()), month(now()), day(now()), hour(dt), minute(dt), second(dt))>
		</cfif>
		
		<cfif 
			  	(datebegin is "" or
				datecompare(datebegin, now()) is -1)
				and
				(dateend is "" or
				datecompare(now(), dateend) is -1)
				and
				(timebegin is "" or
				datecompare(dTimeBegin, now()) is -1)
				and
				(timeend is "" or
				datecompare(now(), dTimeEnd) is -1)>
		
			<cfset counter = counter + weight>
			<cfif counter gte data.marker>
				<cfset picked = adidfk>
				<cfbreak>
			</cfif>
		</cfif>
	</cfloop>	
	<cfif not isDefined("picked")>
		<cfset data.marker = 1>
		<cfset picked = data.ads.adidfk[1]>
	</cfif>

	
	<!--- Ok, now we have a ad, we can get the source and increment impressions --->
	<cfset bean = application.admanager.getAdImpression(picked,campaign.getID())>
	</cflock>
<cfelse>

	<cflock name="#application.lockname#" type="exclusive" timeout="10">	
		<cfset bean = application.admanager.getAdImpression(url.a)>
	</cflock>	

</cfif>



<cfif bean.getID() neq "" and bean.getActive()>
	<!--- for link --->
	<cfset path = listDeleteAt(cgi.script_name, listLen(cgi.script_name,"/"), "/")>
	<cfif cgi.server_port_secure>
		<cfset prot = "https">
	<cfelse>
		<cfset prot = "http">
	</cfif>
	
	<cfset link = "<a href=""#prot#://#cgi.server_name##path#/adbouncer.cfm?a=#bean.getID()#">
	
	<cfif isDefined("url.c")>
		<cfset link = link & "&c=#campaign.getID()#">
	</cfif>
	<cfif bean.getTarget() neq "">
		<cfset link = link & """ target=""#bean.getTarget()#"">">
	<cfelse>
		<cfset link = link & """>">
	</cfif>
	
	<!--- for H/W --->
	<cfset ws = "">
	<cfset hs = "">
	<cfif bean.getWidth() neq "">
		<cfset ws = " width=""#bean.getWidth()#"" ">
	</cfif>
	<cfif bean.getHeight() neq "">
		<cfset hs = " height=""#bean.getHeight()#"" ">
	</cfif>
		
	<cfif len(bean.getSource())>
		<cfset imgpath = "#prot#://#cgi.server_name#" & path & "/images/ads/#bean.getSource()#">
		<cfset text = "#link#<img src=""#imgpath#"" border=""0""#ws##hs#></a>">
	<cfelseif len(bean.getBody())>
		<cfsavecontent variable="text">
		<cfoutput>
<table#ws##hs# class="adserver_table">
<tr>
<td class="adserver_title_td"><span class="adserver_title">#link##bean.getTitle()#</a></span></td>
</tr>
<tr>
<td class="adserver_body_td"><span class="adserver_body">#bean.getBody()#</span></td>
</tr>
</table>
		</cfoutput>
		</cfsavecontent>
		<cfset text = jsStringFormat(text)>
	<cfelseif len(bean.getHTML())>
		<cfset text = jsStringFormat(bean.getHTML())>
	</cfif>
	<cfoutput>
	document.write('#text#');
	</cfoutput>
</cfif>
