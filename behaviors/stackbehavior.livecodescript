script "WebDavLibStackBehavior"


--==================================================================--
--
-- WebDavLib
--
-- WebDAV communication library
--
-- @author rabit@revigniter.com
-- @version 1.1.2
-- @license: MIT
--
--==================================================================--




--> Library
--==================================================================--
--
-- Start using/Stop using
--

on libraryStack
   if the short name of the target = the short name of me then
      # PUT INITIALIZATION STUFF HERE:
      answer the target && "got libraryStack message"
      --
   else pass libraryStack
end libraryStack


on releaseStack
   if the short name of the target = the short name of me then
      # PUT CLEANUP STUFF HERE:
      answer the target && "got releaseStack message"
      --
   else pass releaseStack
end releaseStack


--====================================================================================--
--
-- Main Stuff
--

--> Declarations

local sLogTarget -- long ID of stack using WebDav library
local sLogTargetExists
local sWriteStatusCommand = "writeStatusWDL" -- command dispatched to stack sLogTarget
local sWriteToLogCommand = "writeToLogWDL" -- command dispatched to stack sLogTarget
local sWriteErrorCommand = "writeErrorWDL" -- command dispatched to stack sLogTarget

local sMostRecentServerResponse
local sWebDavPoolA
local sCurrentReqID
local sMaxRequests = 10
local sCheckResponseInterval = 200 -- millisecs
local sTimeout = 25000 -- millisecs

## NEEDED FOR _wdlArrayToKeyValueList
local sKeyValueList
local sKeys
##




--> Getter


/*----------------------------------------------------------------------
--| FUNCTION wdlGet
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-03-16
--| Last Mod: 2020-03-16
--| Requires: --
--|
--| Summary: Get library variables: status, error, requestHeaders,
--|          response and responseHeaders.
--|
--| Format:  wdlGet(param1, param2)
--|
--| Parameters: string <pItem>, integer <pReqID>
--|
--| Return: mixed
----------------------------------------------------------------------*/

function wdlGet pItem pReqID
   if pReqID <> empty then
      if pItem is in "status,error,requestHeaders,response,responseHeaders" then
         return sWebDavPoolA[pReqID][pItem]
      end if
   end if

   return empty
end wdlGet



--> Setter


/*----------------------------------------------------------------------
--| COMMAND wdlSet
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-03-16
--| Last Mod: 2020-03-16
--| Requires: --
--|
--| Summary: Set library variable value for: method, agent, host, uri,
--|          user, password, contentType, contentLength, nameSpace,
--|          properties, dataToUpload, callBack, object, timeOut,
--|          lockScope, lockType, lockOwner, lockToken, sslFlag, port,
--|          authType, and maxRequests
--|
--| Format:  wdlSet param1, param2[, param3]
--|
--| Parameters: string <pItem>, mixed <pVal>, integer <pReqID> (not used for maxRequests)
--|
--| Return: empty
----------------------------------------------------------------------*/

command wdlSet pItem pVal pReqID
   if pReqID <> empty then
      switch pItem
         case "method"
            if pVal is among the items of "GET,POST,HEAD,PUT,DELETE,OPTIONS,TRACE,PROPFIND,LOCK,UNLOCK,PROPPATCH,MKCOL" then
               put pVal into sWebDavPoolA[pReqID][pItem]
            end if
            if pVal is "LOCK" then
               put "Second-" & the cLockTimeout of stack "WebDavLib" into sWebDavPoolA[pReqID]["lockTimeout"]
            end if

            break
         case "authType"
            if pVal is in "Basic,Digest,NTLM,Negotiate" then
               put pVal into sWebDavPoolA[pReqID][pItem]
            end if

            break
         default
            -- default code
            put pVal into sWebDavPoolA[pReqID][pItem]
      end switch

   else -- if pReqID <> empty
      switch pItem
         case "maxRequests"
            if pVal is an integer and pVal > 0 then put pVal into sMaxRequests

            break
         case "logTarget"
            delete word 1 of pVal
            put pVal into sLogTarget

            break
         default
            -- default code
      end switch
   end if -- if pReqID <> empty
end wdlSet




--> WebDAV


/*----------------------------------------------------------------------
--| FUNCTION wdlGetserverMethods
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-04
--| Last Mod: 2020-05-04
--| Requires: _wdlExecute()
--|
--| Summary: Get comma delimited list of server methods.
--|
--| Format:  wdlGetserverMethods(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlGetserverMethods pReqID
   local tServerMethods

   put "OPTIONS" into sWebDavPoolA[pReqID]["method"]
   put "wdlGetserverMethods" into sWebDavPoolA[pReqID]["requestHandler"]

   # REQUEST
   put _wdlExecute(pReqID) into tServerMethods

   return tServerMethods
end wdlGetserverMethods




/*----------------------------------------------------------------------
--| FUNCTION wdlGetFileProps
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-04
--| Last Mod: 2020-05-04
--| Requires: wdlPropertyNamesXMLdata(), _wdlExecute()
--|
--| Summary: Get array of file properties.
--|
--| Format:  wdlGetFileProps(param1, param2)
--|
--| Parameters: integer <pReqID>, string <pProps>
--|
--| Return: mixed
----------------------------------------------------------------------*/

function wdlGetFileProps pReqID pProps
   local tFileProps

   put "PROPFIND" into sWebDavPoolA[pReqID]["method"]
   put "wdlGetFileProps" into sWebDavPoolA[pReqID]["requestHandler"]
   put pProps into sWebDavPoolA[pReqID]["props"]

   # BUILD PROPERTY XML DATA
   put FALSE into tCustomProps
   put wdlPropertyNamesXMLdata(pProps, tCustomProps) into tPropsXML

   put tPropsXML into sWebDavPoolA[pReqID]["propertiesXML"]
   put "application/xml; charset=" & quote & "utf-8" & quote into tContType
   put tContType into sWebDavPoolA[pReqID]["contentType"]

   # REQUEST
   put _wdlExecute(pReqID) into tFilePropsA

   return tFilePropsA
end wdlGetFileProps





/*----------------------------------------------------------------------
--| FUNCTION wdlGetFile
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-04
--| Last Mod: 2020-05-04
--| Requires: _wdlExecute()
--|
--| Summary: Download file.
--|
--| Format:  wdlGetFile(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: mixed
----------------------------------------------------------------------*/

function wdlGetFile pReqID
   local tData

   put "GET" into sWebDavPoolA[pReqID]["method"]
   put "wdlGetFile" into sWebDavPoolA[pReqID]["requestHandler"]

   # REQUEST
   put _wdlExecute(pReqID) into tData

   return tData
end wdlGetFile





/*----------------------------------------------------------------------
--| FUNCTION wdlWritePermission
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-05
--| Last Mod: 2020-05-05
--| Requires: _wdlExecute()
--|
--| Summary: Write permission test.
--|
--| Format:  wdlWritePermission(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlWritePermission pReqID
   local tFile, tContType, tDataToUpload, tResponse

   put "PUT" into sWebDavPoolA[pReqID]["method"]
   put "wdlWritePermission" into sWebDavPoolA[pReqID]["requestHandler"]

   put "writeTest.txt" into tFile
   put sWebDavPoolA[pReqID]["uri"] & tFile into sWebDavPoolA[pReqID]["uri"]

   put "text/plain" into tContType
   put tContType into sWebDavPoolA[pReqID]["contentType"]

   # SIZE OF FILE TO UPLOAD
   put 4 into tFileSize -- 4 BYTES FOR WORD "test"
   put tFileSize into sWebDavPoolA[pReqID]["contentLength"]
   put "test" into tDataToUpload
   put tDataToUpload into sWebDavPoolA[pReqID]["dataToUpload"]

   # REQUEST
   put _wdlExecute(pReqID) into tResponse

   return tResponse
end wdlWritePermission





/*----------------------------------------------------------------------
--| FUNCTION wdlDeleteFileFolder
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-05
--| Last Mod: 2020-05-05
--| Requires: _wdlExecute()
--|
--| Summary: Delete file or folder.
--|
--| Format:  wdlDeleteFileFolder(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlDeleteFileFolder pReqID
   local tResponse

   put "DELETE" into sWebDavPoolA[pReqID]["method"]
   put "wdlDeleteFileFolder" into sWebDavPoolA[pReqID]["requestHandler"]

   # REQUEST
   put _wdlExecute(pReqID) into tResponse

   return tResponse
end wdlDeleteFileFolder





/*----------------------------------------------------------------------
--| FUNCTION wdlPutFile
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-05
--| Last Mod: 2020-05-05
--| Requires: _wdlExecute()
--|
--| Summary: Upload a file.
--|
--| Format:  wdlPutFile(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlPutFile pReqID
   local tContType, tDataToUpload, tResponse

   put "PUT" into sWebDavPoolA[pReqID]["method"]
   put "wdlPutFile" into sWebDavPoolA[pReqID]["requestHandler"]

   put "application/x-www-form-urlencoded" into tContType
   put tContType into sWebDavPoolA[pReqID]["contentType"]

   put URL ("binfile:" & sWebDavPoolA[pReqID]["filePath"]) into tDataToUpload
   put tDataToUpload into sWebDavPoolA[pReqID]["dataToUpload"]

   # REQUEST
   put _wdlExecute(pReqID) into tResponse

   return tResponse
end wdlPutFile





/*----------------------------------------------------------------------
--| FUNCTION wdlGetFileList
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-05
--| Last Mod: 2020-05-05
--| Requires: _wdlExecute()
--|
--| Summary: Get a XML directory listing.
--|
--| Format:  wdlGetFileList(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlGetFileList pReqID
   local tContType, tFileListXML

   put "PROPFIND" into sWebDavPoolA[pReqID]["method"]
   put "wdlGetFileList" into sWebDavPoolA[pReqID]["requestHandler"]

   put empty into sWebDavPoolA[pReqID]["propertiesXML"]
   put "application/xml; charset=" & quote & "utf-8" & quote into tContType
   put tContType into sWebDavPoolA[pReqID]["contentType"]

   # REQUEST
   put _wdlExecute(pReqID) into tFileListXML

   return tFileListXML
end wdlGetFileList





/*----------------------------------------------------------------------
--| FUNCTION wdlCreateFolder
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-05
--| Last Mod: 2020-05-05
--| Requires: _wdlExecute()
--|
--| Summary: Create folder on webDAV server.
--|
--| Format:  wdlCreateFolder(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlCreateFolder pReqID
   local tResponse

   put "MKCOL" into sWebDavPoolA[pReqID]["method"]
   put "wdlCreateFolder" into sWebDavPoolA[pReqID]["requestHandler"]

   # REQUEST
   put _wdlExecute(pReqID) into tResponse

   return tResponse
end wdlCreateFolder




/*----------------------------------------------------------------------
--| FUNCTION wdlSetFileProps
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-05
--| Last Mod: 2020-05-05
--| Requires: wdlSetRemovePropXMLdata(), _wdlExecute()
--|
--| Summary: Set file properties.
--|
--| Format:  wdlSetFileProps(param1, param2, param3)
--|
--| Parameters: integer <pReqID>, array <pSetPropsA>, array <pRemovePropsA>
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlSetFileProps pReqID pSetPropsA pRemovePropsA
   local tPropsXML, tContType, tContLength, tResponse

   # CHECK PROPERTIES TO SET OR REMOVE
   if (pSetPropsA is empty and pSetPropsA is not an array) and (pRemovePropsA is empty and pRemovePropsA is not an array) then
      answer error "Properties list empty!"
      exit to top
   end if

   if pSetPropsA is not empty and pSetPropsA is not an array then
      answer error "Set properties list is not an array!"
      exit to top
   end if

   if pRemovePropsA is not empty and pRemovePropsA is not an array then
      answer error "Remove properties list is not an array!"
      exit to top
   end if
   #

   put "PROPPATCH" into sWebDavPoolA[pReqID]["method"]
   put "wdlSetFileProps" into sWebDavPoolA[pReqID]["requestHandler"]

   # BUILD PROPERTY XML DATA
   put wdlSetRemovePropXMLdata(pSetPropsA, pRemovePropsA) into tPropsXML

   put tPropsXML into sWebDavPoolA[pReqID]["propertiesXML"]
   put "application/xml; charset=" & quote & "utf-8" & quote into tContType
   put tContType into sWebDavPoolA[pReqID]["contentType"]
   put the number of chars of tPropsXML into tContLength
   put tContLength into sWebDavPoolA[pReqID]["contentLength"]

   # REQUEST
   put _wdlExecute(pReqID) into tResponse

   return tResponse
end wdlSetFileProps





/*----------------------------------------------------------------------
--| FUNCTION wdlGetCustomProps
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-05
--| Last Mod: 2020-05-05
--| Requires: wdlPropertyNamesXMLdata(), _wdlExecute()
--|
--| Summary: Get custom properties.
--|
--| Format:  wdlGetCustomProps(param1, param2)
--|
--| Parameters: integer <pReqID>, string <pProps> (comma delimited list)
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlGetCustomProps pReqID pProps
   local tFileProps, tPropsXML, tContType, tFilePropsA

   put "PROPFIND" into sWebDavPoolA[pReqID]["method"]
   put "wdlGetCustomProps" into sWebDavPoolA[pReqID]["requestHandler"]
   put pProps into sWebDavPoolA[pReqID]["props"]

   # BUILD PROPERTY XML DATA
   put TRUE into tCustomProps
   put wdlPropertyNamesXMLdata(pProps, tCustomProps) into tPropsXML

   put tPropsXML into sWebDavPoolA[pReqID]["propertiesXML"]
   put "application/xml; charset=" & quote & "utf-8" & quote into tContType
   put tContType into sWebDavPoolA[pReqID]["contentType"]

   # REQUEST
   put _wdlExecute(pReqID) into tFilePropsA

   return tFilePropsA
end wdlGetCustomProps





/*----------------------------------------------------------------------
--| FUNCTION wdlLock
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-05
--| Last Mod: 2020-05-05
--| Requires: _wdlExecute()
--|
--| Summary: Lock file on webDAV server.
--|
--| Format:  wdlLock(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlLock pReqID
   local tScope, tType, tResponse

   put "exclusive" into tScope
   put "write" into tType

   put "LOCK" into sWebDavPoolA[pReqID]["method"]
   put "wdlLock" into sWebDavPoolA[pReqID]["requestHandler"]

   put "application/xml; charset=" & quote & "utf-8" & quote into sWebDavPoolA[pReqID]["contentType"]
   put tScope into sWebDavPoolA[pReqID]["lockScope"]
   put tType into sWebDavPoolA[pReqID]["lockType"]

   # REQUEST
   put _wdlExecute(pReqID) into tResponse

   put "Lock token:" && the cCurrentLockToken of stack "WebDavLib" & return before tResponse

   return tResponse
end wdlLock





/*----------------------------------------------------------------------
--| FUNCTION wdlUnlock
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-05
--| Last Mod: 2020-05-05
--| Requires: _wdlExecute()
--|
--| Summary: Unlock file on webDAV server.
--|
--| Format:  wdlUnlock(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlUnlock pReqID
   local tToken, tResponse

   if sWebDavPoolA[pReqID]["lockToken"] <> empty then
      set the cCurrentLockToken of stack "WebDavLib" to sWebDavPoolA[pReqID]["lockToken"]
   end if

   put the cCurrentLockToken of stack "WebDavLib" into tToken

   if tToken is not empty then
      if sWebDavPoolA[pReqID]["lockToken"] is empty then
         put tToken into sWebDavPoolA[pReqID]["lockToken"]
      end if

      put "UNLOCK" into sWebDavPoolA[pReqID]["method"]
      put "wdlUnlock" into sWebDavPoolA[pReqID]["requestHandler"]

      # REQUEST
      put _wdlExecute(pReqID) into tResponse

      if "204" is in tResponse then
         # SUCCESS, GET RID OF LOCK TOKEN
         set the cCurrentLockToken of stack "WebDavLib" to empty
      end if

      return tResponse
   else
      answer error "File" && sWebDavPoolA[pReqID]["uri"] && "is not locked!"
   end if
end wdlUnlock





/*----------------------------------------------------------------------
--| FUNCTION wdlGetFileHeaders
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-05-05
--| Last Mod: 2020-05-05
--| Requires: _wdlExecute()
--|
--| Summary: Get all headers of a file.
--|
--| Format:  wdlGetFileHeaders(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: array
----------------------------------------------------------------------*/

function wdlGetFileHeaders pReqID
   local tHeaderValuesA

   put "HEAD" into sWebDavPoolA[pReqID]["method"]
   put "wdlGetFileHeader" into sWebDavPoolA[pReqID]["requestHandler"]

   # REQUEST
   put _wdlExecute(pReqID) into tHeaderValuesA

   return tHeaderValuesA
end wdlGetFileHeaders






/*----------------------------------------------------------------------
--| COMMAND wdlSetupNewRequest
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2008-04-09
--| Last Mod: --
--| Requires: _wdlNew(), wdlSet
--|
--| Summary: Set values of sWebDavPoolA variable and return request ID.
--| These are the request data array keys used depending on the particular request method:
--| - host (the host address like: myname.ocloud.de)
--| - uri (the path to the WebDAV directory like: /remote.php/webdav/)
--| - port (as a general rule this is 80 or 443 for secure connections)
--| - user
--| - password (user password or app password)
--| - authType (Basic or Digest)
--| - sslFlag (a boolean, TRUE for a secure connection)
--| - method (see the WebDav methods above)
--| - agent (User-agent)
--| - propertiesXML (the properties XML data included in a XML request body)
--| - contentType (Content-type like application/xml; charset="utf-8")
--| - contentLength
--| - dataToUpload (the binary file data to upload)
--| - nameSpace (WebDAV XML namespace like http://www.w3.com/standards/z39.50/)
--| - lockScope (exclusive or shared)
--| - lockType (write)
--| - lockOwner (any name)
--| - lockToken (the cCurrentLockToken of stack "WebDavLib")
--| - callBack (the name of a callback handler used by methods GET and PUT)
--| - callbackTarget (the long ID of the object containing the callback handler)
--|
--| Format:  wdlSetupNewRequest param
--|
--| Parameters: array <pRequestDataA>
--|
--| Return: integer
----------------------------------------------------------------------*/

command wdlSetupNewRequest pRequestDataA
   local tReqID, tRequestKeysList, tKey

   put _wdlNew() into tReqID

   # SET REQUEST VARS
   put the keys of pRequestDataA into tRequestKeysList

   repeat for each line tKey in tRequestKeysList
      wdlSet tKey, pRequestDataA[tKey], tReqID
   end repeat

   return tReqID
end wdlSetupNewRequest





/*----------------------------------------------------------------------
--| FUNCTION _wdlNew
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2008-08-13
--| Last Mod: --
--| Requires: _wdlInitWebDavReq
--|
--| Summary: Add new connection ID and a pending WebDAV connection.
--|
--| Format:  _wdlNew()
--|
--| Parameters: --
--|
--| Return: integer
----------------------------------------------------------------------*/

private function _wdlNew
   local tReqID

   repeat with tReqID = 1 to sMaxRequests
      if sWebDavPoolA[tReqID]["status"] is empty then
         put empty into sWebDavPoolA[tReqID]["HTTPresponse"]
         _wdlInitWebDavReq tReqID
         return tReqID
      end if
   end repeat
   return 0
end _wdlNew



/*----------------------------------------------------------------------
--| COMMAND _wdlInitWebDavReq
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2008-08-13
--| Last Mod: --
--| Requires: --
--|
--| Summary: Set WebDAV request status to pending.
--|
--| Format:  _wdlInitWebDavReq param1
--|
--| Parameters: integer <pReqID>
--|
--| Return: empty
----------------------------------------------------------------------*/

private command _wdlInitWebDavReq pReqID
   put "pending" into sWebDavPoolA[pReqID]["status"]
end _wdlInitWebDavReq




/*----------------------------------------------------------------------
--| COMMAND wdlCleanup
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2008-08-13
--| Last Mod: --
--| Requires: --
--|
--| Summary: Clean up request variables of a specific connection ID.
--|
--| Format:  wdlCleanup param1
--|
--| Parameters: integer <pReqID>
--|
--| Return: empty
----------------------------------------------------------------------*/

command wdlCleanup pReqID
   put empty into sWebDavPoolA[pReqID]
end wdlCleanup





/*----------------------------------------------------------------------
--| FUNCTION _wdlRequestResponse
--|
--| Author: rabit
--| Version:  1.2
--| Created: 2008-05-09
--| Last Mod: 2020-03-04
--| Requires: wdlCheckResponse, _wdlWriteLog
--|
--| Summary: Gets request response from HTTP server.
--|
--| Format:  _wdlRequestResponse(param1, param2)
--|
--| Parameters: integer <pReqID>, string <pHeaders>
--|
--| Return: string
----------------------------------------------------------------------*/

private function _wdlRequestResponse pReqID, pHeaders
   local tProtocol, tMethods, tResponseData, tServerResponse

   if "wdlCheckResponse" is not in the pendingMessages then
      wdlCheckResponse
   end if

   if sWebDavPoolA[pReqID]["sslFlag"] is "true" then
      put "https://" into tProtocol
   else
      put "http://" into tProtocol
   end if

   # REQUEST HEADERS
   if sWebDavPoolA[pReqID]["method"] is "PUT" then
      if (sWebDavPoolA[pReqID]["authType"] is "Digest") and (sWebDavPoolA[pReqID]["authorizedRequest"] <> TRUE) then
         # GET VALUES (REALM, NONCE etc.) FROM SERVER, REQUIRED FOR THE NEXT REQUEST, JUST PUT 3 BYTES ("foo")
         set the itemDel to space
         put 3 into item 2 of line 4 of pHeaders
         set the itemDel to comma
      end if

      set the httpheaders to pHeaders
   else
      libURLSetCustomHTTPHeaders pHeaders
   end if

   # CALLBACK MESSAGE
   if sWebDavPoolA[pReqID]["callBack"] is empty then
      libUrlSetStatusCallback
   else
      libUrlSetStatusCallback sWebDavPoolA[pReqID]["callBack"], sWebDavPoolA[pReqID]["object"]
   end if

   # SEND REQUEST
   put "PROPFIND,PROPPATCH,LOCK,UNLOCK" into tMethods

   if sWebDavPoolA[pReqID]["method"] is among the items of tMethods then
      if sWebDavPoolA[pReqID]["socketToOpen"] <> empty then
         _wdlWriteLog pReqID
         put pReqID into sCurrentReqID

         if sWebDavPoolA[pReqID]["sslFlag"] is "true" then
            open secure socket to sWebDavPoolA[pReqID]["socketToOpen"] with message "wdlConnectionUp"
         else
            open socket to sWebDavPoolA[pReqID]["socketToOpen"] with message "wdlConnectionUp"
         end if

         return "socketOpened"
      end if
      return "Error: Request ID" && pReqID & ", no socket to open provided!"
   else
      _wdlWriteLog pReqID, sWebDavPoolA[pReqID]["currentRequest"]

      if sWebDavPoolA[pReqID]["method"] is "PUT" then
         if (sWebDavPoolA[pReqID]["authType"] is "Basic") or (sWebDavPoolA[pReqID]["authorizedRequest"] is TRUE) then
            put FALSE into sWebDavPoolA[pReqID]["authorizedRequest"]
            put sWebDavPoolA[pReqID]["dataToUpload"] into URL (tProtocol & sWebDavPoolA[pReqID]["host"] & ":" & sWebDavPoolA[pReqID]["port"] & sWebDavPoolA[pReqID]["uri"])

         else if sWebDavPoolA[pReqID]["authType"] is "Digest" then
            # GET VALUES (REALM, NONCE etc.) FROM SERVER, REQUIRED FOR THE NEXT REQUEST, JUST PUT 3 BYTES ("foo")
            put "foo" into URL (tProtocol & sWebDavPoolA[pReqID]["host"] & ":" & sWebDavPoolA[pReqID]["port"] & sWebDavPoolA[pReqID]["uri"])
         end if

      else
         get URL (tProtocol & sWebDavPoolA[pReqID]["host"] & ":" & sWebDavPoolA[pReqID]["port"])
      end if

   end if

   # RESPONSE
   switch sWebDavPoolA[pReqID]["method"]
      case "GET"
         if the result is not empty then
            return the result
         else
            # SUCCESS
            put it into tResponseData
            return tResponseData
         end if

         break
      case "PUT"
         if  the result is not empty then
            return the result
         else
            # SUCCESS
            return "done"
         end if

         break
      default
         put libUrlLastRHHeaders() into tServerResponse

         _wdlWriteLog pReqID, tServerResponse

         if matchtext(line 1 of tServerResponse, ".*2\d{2}.*") then -- STATUS CODE 2xx
            # SUCCESS
            return tServerResponse
         else
            return "Error:" && word 2 to -1 of line 1 of tServerResponse
         end if
   end switch
end _wdlRequestResponse






/*----------------------------------------------------------------------
--| COMMAND _wdlWriteLog
--|
--| Author: rabit
--| Version:  1.2
--| Created: 2008-06-09
--| Last Mod: 2020-04-30
--| Requires: --
--|
--| Summary: Write to log field in stack sLogTarget
--|         (needed for PROPFIND, PROPPATCH, LOCK, UNLOCK methods).
--|
--| Format:  _wdlWriteLog param1, param2
--|
--| Parameters: integer <pReqID>, string <pResponse>
--|
--| Return: empty
----------------------------------------------------------------------*/

command _wdlWriteLog pReqID pResponse
   local tRegEx, tSocketToOpen, tCurrentRequest

   if sLogTargetExists then
      if sWebDavPoolA[pReqID]["socketToOpen"] is empty then
         put "^" & sWebDavPoolA[pReqID]["host"] into tRegEx
         repeat for each line tSocket in the openSockets
            if matchText(tSocket, tRegEx) then
               put tSocket into sWebDavPoolA[pReqID]["socketToOpen"]
               exit repeat
            end if
         end repeat
      end if -- if sWebDavPoolA[pReqID]["socketToOpen"] is empty

      put sWebDavPoolA[pReqID]["socketToOpen"] into tSocketToOpen
      put sWebDavPoolA[pReqID]["currentRequest"] into tCurrentRequest

      do merge("dispatch" && quote & sWriteToLogCommand & quote && "to stack [[sLogTarget]] with pReqID, pResponse, tSocketToOpen, tCurrentRequest")
   end if -- if sLogTargetExists
end _wdlWriteLog





/*----------------------------------------------------------------------
--| COMMAND _wdlWriteStatus
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-04-01
--| Last Mod: --
--| Requires: --
--|
--| Summary: Write to status field in stack sLogTarget.
--|
--| Format:  _wdlWriteStatus param1, param2
--|
--| Parameters: integer <pReqID>, string <pStatus>
--|
--| Return: empty
----------------------------------------------------------------------*/

private command _wdlWriteStatus pReqID pStatus
   put pStatus into sWebDavPoolA[pReqID]["status"]

   if sLogTargetExists then
      do merge("dispatch" && quote & sWriteStatusCommand & quote && "to stack [[sLogTarget]] with pReqID, pStatus")
   end if
end _wdlWriteStatus




/*----------------------------------------------------------------------
--| COMMAND _wdlSetErrorOrDoneStatus
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-04-01
--| Last Mod: --
--| Requires: --
--|
--| Summary: Set status either to "error" or "done".
--|
--| Format:  _wdlSetErrorOrDoneStatus param1, param2
--|
--| Parameters: integer <pReqID>, string <pRequestResponse>
--|
--| Return: empty
----------------------------------------------------------------------*/

private command _wdlSetErrorOrDoneStatus pReqID pRequestResponse
   if "Error" is in pRequestResponse then
      put "error" into sWebDavPoolA[pReqID]["status"]
   else
      put "done" into sWebDavPoolA[pReqID]["status"]
   end if
end _wdlSetErrorOrDoneStatus





/*----------------------------------------------------------------------
--| FUNCTION _wdlProcessResponse
--|
--| Author: rabit
--| Version:  1.5
--| Created: 2008-05-19
--| Last Mod: 2020-05-05
--| Requires: _wdlPropertyVals()
--|
--| Summary: Process data from server response.
--|
--| Format:  _wdlProcessResponse(param1, param2)
--|
--| Parameters: integer <pReqID>, string <pServerResponse>
--|
--| Return: string
----------------------------------------------------------------------*/

private function _wdlProcessResponse pReqID, pServerResponse
   local tDataToReturn

   # PROCESS THE RETURNED DATA
   switch sWebDavPoolA[pReqID]["method"]
      case "OPTIONS"
         if matchtext(pServerResponse, ".*2\d{2}.*") then -- STATUS CODE 2xx
            # SUCCESS
            replace ": " with numToCodepoint(4) in pServerResponse
            delete line 1 of pServerResponse
            split pServerResponse by cr and numToCodepoint(4)
            put pServerResponse["Allow"] into tDataToReturn
         else
            if sWebDavPoolA[pReqID]["authType"] is "Basic" then
               put pServerResponse into tDataToReturn
            else
               put "Error:" && word 2 to -1 of line 1 of pServerResponse into tDataToReturn
            end if
         end if

         break
      case "GET"
         put pServerResponse into tDataToReturn

         break
      case "PUT"
         if matchtext(pServerResponse, ".*2\d{2}.*") then -- STATUS CODE 2xx
            # SUCCESS
            put "file uploaded" into tDataToReturn
         else
            put "Error:" && word 2 to -1 of line 1 of pServerResponse into tDataToReturn
         end if

         break
      case "DELETE"
         if matchtext(pServerResponse, ".*2\d{2}.*") then -- STATUS CODE 2xx
            # SUCCESS
            put "file/folder deleted" into tDataToReturn
         else
            put "Error:" && word 2 to -1 of line 1 of pServerResponse into tDataToReturn
         end if

         break
      case "PROPFIND"
         if sWebDavPoolA[pReqID]["props"] <> empty then
            put _wdlPropertyVals(sWebDavPoolA[pReqID]["props"], pServerResponse) into tDataToReturn
         else
            put pServerResponse into tDataToReturn
         end if

         break
      case "PROPPATCH"
         put pServerResponse into tDataToReturn

         break
      case "HEAD"
         if matchtext(pServerResponse, ".*2\d{2}.*") then -- STATUS CODE 2xx
            # SUCCESS
            replace ": " with numToCodepoint(4) in pServerResponse
            delete line 1 of pServerResponse
            split pServerResponse by cr and numToCodepoint(4)
            put pServerResponse into tDataToReturn
         else
            put "Error:" && word 2 to -1 of line 1 of pServerResponse into tDataToReturn
         end if

         break
      default
         put pServerResponse into tDataToReturn
   end switch

   return tDataToReturn
end _wdlProcessResponse





/*----------------------------------------------------------------------
--| FUNCTION _wdlExecute
--|
--| Author: rabit
--| Version:  1.3
--| Created: 2008-05-19
--| Last Mod: 2020-05-04
--| Requires: _wdlCheckLogTarget, _wdlCustomHeaders(), _wdlWriteStatus
--|          _wdlAuthBasicRequest(), _wdlRequestResponse(), _wdlProcessResponse(), _wdlWriteError
--|
--| Summary: Execute a request and get the result(s).
--|
--| Format:  _wdlExecute(param1)
--|
--| Parameters: integer <pReqID>
--|
--| Return: string
----------------------------------------------------------------------*/

private function _wdlExecute pReqID
   local tRequestHeadersA, tRequestHeaders, tRequestHeadersXML, tMethods, tSocketID
   local tRequestHeadersTemp, tRequestResponse, tErrorString, tServerResponse
   local tAuthTypeLineNum, tAuthResponseText, tNonce, tQop, tOpaque
   local tCnonce, tNC, tA1, tA2, tHashA1, tHashA2, tHashA1hex
   local tHashA2Hex, tRealm, tResponse, tResponseHex

   put the millisecs into sWebDavPoolA[pReqID]["startTime"]

   # SAVE MOST RECENT SERVER RESPONSE HEADERS
   put libUrlLastRHHeaders() into sMostRecentServerResponse

   # CHECK IF THERE IS A TARGET FOR LOG MESSAGES
   _wdlCheckLogTarget

   # BUILD CUSTOM HEADERS
   put _wdlCustomHeaders(pReqID) into tRequestHeadersA
   put tRequestHeadersA["requestHeaders"] into tRequestHeaders
   put tRequestHeadersA["socketID"] into tSocketID
   put tRequestHeadersA["requestHeadersXML"] into tRequestHeadersXML
   delete variable tRequestHeadersA

   _wdlWriteStatus pReqID, "running"

   # BUILD AUTHORIZATION STRING
   # AUTHTYPE BASIC
   if sWebDavPoolA[pReqID]["authType"] is "Basic" then
      put _wdlAuthBasicRequest(pReqID, tRequestHeaders, tRequestHeadersXML) into tRequestResponse

      # CHECK IF SERVER IS RESPONDING BY COMPARING THE MOST RECENT RESPONSE WITH LAST RESPONSE SAVED BY LIBURL
      if tRequestResponse is sMostRecentServerResponse then
         _wdlWriteStatus pReqID, "error"
         _wdlCleanUp pReqID

         return "Server is not responding!"
      end if

      # PROCESS THE RETURNED DATA
      if tRequestResponse is not "socketOpened" then
         # BAD REQUEST
         if "400" is in line 1 of tRequestResponse then
            _wdlWriteStatus pReqID, "error"
            put "400 Bad Request" & cr into tErrorString

            _wdlWriteError tErrorString
         end if
         #
         # METHOD NOT ALLOWED
         if "405" is in line 1 of tRequestResponse then
            _wdlWriteStatus pReqID, "error"

            if sWebDavPoolA[pReqID]["method"] is "MKCOL" then
               put "405 Method Not Allowed (maybe folder already exists)" & cr into tErrorString
            else
               put "405 Method Not Allowed" & cr into tErrorString
            end if

            _wdlWriteError tErrorString
         end if
         #

         return _wdlResponseToReturn(pReqID, tRequestResponse)
      else
         wait until sWebDavPoolA[pReqID]["HTTPresponse"] is not empty with messages

         if (sWebDavPoolA[pReqID]["pFindPatchLockAuth"] <> "CLOSED") and \
               (sWebDavPoolA[pReqID]["HTTPresponse"] <> "socketTimeout") and \
               (sWebDavPoolA[pReqID]["HTTPresponse"] <> "timeLimitExceeded") then

            # CHECK IF DATA STREAM IS CHUNKED, IF YES WAIT UNTIL ALL CHUNKS ARE TRANSFERRED
            if lineOffset("Transfer-Encoding: chunked", sWebDavPoolA[pReqID]["HTTPresponse"]) then
               wait until sWebDavPoolA[pReqID]["pFindPatchLockAuth"] is "COMPLETED" with messages
            end if

         else
            _wdlWriteStatus pReqID, sWebDavPoolA[pReqID]["HTTPresponse"]
            _wdlCleanUp pReqID

            return sWebDavPoolA[pReqID]["HTTPresponse"]
         end if

         wait 100 millisecs with messages
         _wdlWriteStatus pReqID, "done"

         # BAD REQUEST
         if "400" is in line 1 of sWebDavPoolA[pReqID]["HTTPresponse"] then
            _wdlWriteStatus pReqID, "error"
            put "400 Bad Request" & cr into tErrorString

            _wdlWriteError tErrorString
         end if
         #

         if sWebDavPoolA[pReqID]["method"] is "PROPFIND" then
            put _wdlProcessResponse(pReqID, sWebDavPoolA[pReqID]["HTTPresponse"]) into tRequestedDataA
            _wdlCleanUp pReqID
            return tRequestedDataA
         end if

         _wdlCleanUp pReqID
         return sWebDavPoolA[pReqID]["HTTPresponse"]
      end if

   else -- if sWebDavPoolA[pReqID]["authType"] is "Basic"
      # AUTHTYPE UNKNOWN, DIGEST OR OTHER (EMPTY)
      put tRequestHeaders into tRequestHeadersTemp

      # PROPFIND / PROPPATCH / LOCK HEADER
      if sWebDavPoolA[pReqID]["method"] is "PROPFIND" or sWebDavPoolA[pReqID]["method"] is "PROPPATCH" or sWebDavPoolA[pReqID]["method"] is "LOCK" then
         # ADD XML STUFF
         put tRequestHeaders & CRLF & CRLF & tRequestHeadersXML into tRequestHeadersTemp
         put tRequestHeadersTemp into sWebDavPoolA[pReqID]["currentRequest"]
      end if

      # UNLOCK HEADER
      if sWebDavPoolA[pReqID]["method"] is "UNLOCK" then
         put tRequestHeaders & CRLF & CRLF into tRequestHeadersTemp
         put tRequestHeadersTemp into sWebDavPoolA[pReqID]["currentRequest"]
      end if

      # PUT HEADER
      if sWebDavPoolA[pReqID]["method"] is "PUT" then
         replace CRLF with return in tRequestHeaders
         put tRequestHeaders into tRequestHeadersTemp
         put tRequestHeadersTemp into sWebDavPoolA[pReqID]["currentRequest"]
      end if

      if sWebDavPoolA[pReqID]["currentRequest"] is empty then
         put tRequestHeadersTemp into sWebDavPoolA[pReqID]["currentRequest"]
      end if

      # SEND REQUEST
      put _wdlRequestResponse(pReqID, tRequestHeadersTemp) into tRequestResponse

      # CHECK IF SERVER IS RESPONDING BY COMPARING THE MOST RECENT RESPONSE WITH LAST RESPONSE SAVED BY LIBURL
      if tRequestResponse is sMostRecentServerResponse then
         _wdlWriteStatus pReqID, "error"
         _wdlCleanUp pReqID

         return "Server is not responding!"
      end if

      if tRequestResponse is "socketOpened" then
         wait until sWebDavPoolA[pReqID]["HTTPresponse"] is not empty with messages
         put sWebDavPoolA[pReqID]["HTTPresponse"] into tRequestResponse

         # EXIT IF CONNECTION TIMED OUT
         if (tRequestResponse is "socketTimeout") or (tRequestResponse is "timeLimitExceeded") then
            _wdlWriteStatus pReqID, tRequestResponse
            _wdlCleanUp pReqID

            return tRequestResponse
         end if
      end if

      # BAD REQUEST
      if "400" is in line 1 of tRequestResponse then
         _wdlWriteStatus pReqID, "error"
         put "400 Bad Request" & cr into tErrorString

         _wdlWriteError tErrorString
      end if
      #

      # CHECK IF AUTHORIZATION IS REQUIRED
      if "401" is in line 1 of tRequestResponse then

         put "401 Authorization Required" into tErrorString
         # DON'T PANIC, NOTHING SERIOUS, INFO USED FOR BETTER ERROR HANDLING IN APP
         _wdlWriteError tErrorString, tSocketID

         if (sWebDavPoolA[pReqID]["method"] is "GET") or (sWebDavPoolA[pReqID]["method"] is "PUT") then
            _wdlWriteLog pReqID, tRequestResponse
         end if
         _wdlWriteStatus pReqID, "authorization required"

         # GET VALUES (REALM, NONCE etc.) REQUIRED FOR THE FOLLOWING REQUEST FROM SERVER
         put "PROPFIND,PROPPATCH,LOCK,UNLOCK" into tMethods
         if sWebDavPoolA[pReqID]["method"] is among the items of tMethods then
            put tRequestResponse into tServerResponse
         else
            put libURLLastRHHeaders() into tServerResponse
         end if

         put lineoffset("WWW-Authenticate:",tServerResponse) into tAuthTypeLineNum

         put line tAuthTypeLineNum of tServerResponse into tAuthResponseText
         set the itemdelimiter to space

         # AUTHTYPE
         if item 2 of tAuthResponseText is "Digest" then
            # GET REALM
            repeat with i = 3 to the number of items of tAuthResponseText
               if item i of tAuthResponseText begins with "realm" then
                  put item i of tAuthResponseText into tRealm
                  exit repeat
               end if
            end repeat
            --

            # GET NONCE
            repeat with i = 3 to the number of items of tAuthResponseText
               if item i of tAuthResponseText begins with "nonce" then
                  put item i of tAuthResponseText into tNonce
                  exit repeat
               end if
            end repeat
            --

            # GET QOP
            repeat with i = 3 to the number of items of tAuthResponseText
               if item i of tAuthResponseText begins with "qop" then
                  put item i of tAuthResponseText into tQop
                  exit repeat
               end if
            end repeat
            --

            # GET OPAQUE
            repeat with i = 3 to the number of items of tAuthResponseText
               if item i of tAuthResponseText begins with "opaque" then
                  put item i of tAuthResponseText into tOpaque
                  exit repeat
               end if
            end repeat

            if char -1 of tOpaque is "," then
               delete char -1 of tOpaque
            end if
            replace cr with empty in tOpaque
            replace lf with empty in tOpaque
            --

            # CLIENT NONCE, THIS MUST BE SPECIFIED IF A QOP DIRECTIVE IS SENT
            # CAN BE ANYTHING SINCE THIS AUTHENTICATION SESSION IS NOT GOING TO BE PERSISTENT
            if tQop is not empty then
               put "worscht" into tCnonce
            end if

            # NONCE-COUNT, THIS MUST BE SPECIFIED IF A QOP DIRECTIVE IS SENT
            # THE NC-VALUE IS THE HEXADECIMAL COUNT OF THE NUMBER OF REQUESTS
            # (INCLUDING THE CURRENT REQUEST) THAT THE CLIENT HAS SENT WITH
            # THE NONCE VALUE IN THIS REQUEST
            put "00000001" into tNC

            # GET VALUES
            set the itemdelimiter to quote
            put item 2 of tQop into tQop
            put item 2 of tRealm into tRealm
            put item 2 of tNonce into tNonce

            # CALCULATE THE HASHES OF A1 AND A2 AS DESCRIBED IN RFC 2617
            # A1
            put sWebDavPoolA[pReqID]["user"] & ":" & tRealm & ":" & sWebDavPoolA[pReqID]["password"] into tA1
            # A2
            put sWebDavPoolA[pReqID]["method"] & ":" & sWebDavPoolA[pReqID]["uri"] into tA2
            # HASH OF A1
            put the md5digest of tA1 into tHashA1
            get binarydecode("H*",tHashA1,tHashA1Hex)
            # HASH OF A2
            put the md5digest of tA2 into tHashA2
            get binarydecode("H*",tHashA2,tHashA2Hex)

            # CALCULATE THE RESPONSE HASH AS DESCRIBED IN RFC 2617
            put tHashA1Hex & ":" & tNonce & ":" & tNC & ":" & tCnonce & ":" & tQop & ":" & tHashA2Hex into tConcat
            put the md5digest of tConcat into tResponse
            # CONVERT MD5 RESPONSE TO STRING OF 32 HEX DIGITS
            get binarydecode("H*",tResponse,tResponseHex)

            # BUILD STRING
            set the itemdel to comma
            put "DELETE,HEAD,GET,OPTIONS,MKCOL,PUT" into tMethods
            if sWebDavPoolA[pReqID]["method"] is not among the items of tMethods then
               put CRLF & "Authorization: Digest username=" & quote & sWebDavPoolA[pReqID]["user"] & quote & ", realm=" & quote & tRealm & quote & ", nonce=" & quote & tNonce & quote & ", uri=" & quote & sWebDavPoolA[pReqID]["uri"] & quote & ", algorithm=MD5, response=" & quote & tResponseHex & quote  after tRequestHeaders
            else
               put return & "Authorization: Digest username=" & quote & sWebDavPoolA[pReqID]["user"] & quote & ", realm=" & quote & tRealm & quote & ", nonce=" & quote & tNonce & quote & ", uri=" & quote & sWebDavPoolA[pReqID]["uri"] & quote & ", algorithm=MD5, response=" & quote & tResponseHex & quote  after tRequestHeaders
            end if

            if tOpaque is not empty then
               put "," && quote & tOpaque & quote after tRequestHeaders
            end if

            if tQop is not empty then
               put ", qop=" & tQop & ", nc=" &  tNC & ", cnonce=" & quote & tCnonce & quote after tRequestHeaders
            end if
            --

            # ADD XML STUFF
            if sWebDavPoolA[pReqID]["method"] is "PROPFIND" or sWebDavPoolA[pReqID]["method"] is "PROPPATCH" or sWebDavPoolA[pReqID]["method"] is "LOCK" then
               put tRequestHeaders & CRLF & CRLF & tRequestHeadersXML into tRequestHeaders
               put "pFindPatchLockAuth" into tSocketID
            end if
            --

            # UNLOCK HEADER
            if sWebDavPoolA[pReqID]["method"] is "UNLOCK" then
               put tRequestHeaders & CRLF & CRLF into tRequestHeaders
               put "fUnlockAuth" into tSocketID
            end if

            if sWebDavPoolA[pReqID]["method"] is "PUT" then
               put TRUE into sWebDavPoolA[pReqID]["authorizedRequest"]
            end if

            put tRequestHeaders into sWebDavPoolA[pReqID]["currentRequest"]

            put "PROPFIND,PROPPATCH,LOCK,UNLOCK" into tMethods
            if sWebDavPoolA[pReqID]["method"] is among the items of tMethods then
               put sWebDavPoolA[pReqID]["host"] & ":" & sWebDavPoolA[pReqID]["port"] & "|" & tSocketID into sWebDavPoolA[pReqID]["socketToOpen"]
            end if

            # SEND REQUEST
            put _wdlRequestResponse (pReqID, tRequestHeaders) into tRequestResponse

            # PROCESS THE RETURNED DATA
            if tRequestResponse is not "socketOpened" then
               return _wdlResponseToReturn(pReqID, tRequestResponse)
            else
               wait until sWebDavPoolA[pReqID]["HTTPresponse"] is not empty with messages

               if (sWebDavPoolA[pReqID]["pFindPatchLockAuth"] <> "CLOSED") and \
                     (sWebDavPoolA[pReqID]["HTTPresponse"] <> "socketTimeout") and \
                     (sWebDavPoolA[pReqID]["HTTPresponse"] <> "timeLimitExceeded") then

                  # CHECK IF DATA STREAM IS CHUNKED, IF YES WAIT UNTIL ALL CHUNKS ARE TRANSFERRED
                  if lineOffset("Transfer-Encoding: chunked", sWebDavPoolA[pReqID]["HTTPresponse"]) then
                     wait until sWebDavPoolA[pReqID]["pFindPatchLockAuth"] is "COMPLETED" with messages
                  end if

               else
                  _wdlWriteStatus pReqID, sWebDavPoolA[pReqID]["HTTPresponse"]
                  _wdlCleanUp pReqID

                  return sWebDavPoolA[pReqID]["HTTPresponse"]
               end if

               wait 100 millisecs with messages
               _wdlWriteStatus pReqID, "done"

               if sWebDavPoolA[pReqID]["method"] is "PROPFIND" then
                  put _wdlProcessResponse(pReqID, sWebDavPoolA[pReqID]["HTTPresponse"]) into tRequestedDataA
                  _wdlCleanUp pReqID
                  return tRequestedDataA
               end if

               _wdlCleanUp pReqID

               return sWebDavPoolA[pReqID]["HTTPresponse"]
            end if

         else -- if item 2 of tAuthResponseText is "Digest"
            if item 2 of tAuthResponseText is "Basic" then
               get _wdlAuthBasicRequest(pReqID, tRequestHeaders, tRequestHeadersXML)
               put it into tResponse

               _wdlSetErrorOrDoneStatus pReqID, tResponse
               _wdlWriteStatus pReqID, sWebDavPoolA[pReqID]["status"]
               _wdlCleanUp pReqID

               return tResponse
            else
               _wdlWriteStatus pReqID, "error"
               answer error "AuthType unknown or empty!"
               _wdlCleanUp pReqID

               exit to top
            end if
         end if -- if item 2 of tAuthResponseText is "Digest"

      else -- if "401" is in line 1 of tRequestResponse
         # PROCESS THE RETURNED DATA
         if tRequestResponse is not "socketOpened" then
            return _wdlResponseToReturn(pReqID, tRequestResponse)
         else
            wait until sWebDavPoolA[pReqID]["HTTPresponse"] is not empty with messages
            if sWebDavPoolA[pReqID]["HTTPresponse"] is "socketTimeout" or \
                  sWebDavPoolA[pReqID]["HTTPresponse"] is "timeLimitExceeded" then
               put sWebDavPoolA[pReqID]["HTTPresponse"] into sWebDavPoolA[pReqID]["status"]
            else
               _wdlWriteStatus pReqID, "done"
            end if
            return sWebDavPoolA[pReqID]["HTTPresponse"]
         end if
      end if -- if "401" is in line 1 of tRequestResponse

   end if -- if sWebDavPoolA[pReqID]["authType"] is "BASIC"
end _wdlExecute







/*----------------------------------------------------------------------
--| FUNCTION _wdlAuthBasicRequest
--|
--| Author: rabit
--| Version:  1.3
--| Created: 2008-05-20
--| Last Mod: 2020-03-26
--| Requires: _wdlRequestResponse()
--|
--| Summary: Build basic authorization string and request headers,
--|          send request and return result data.
--|
--| Format: _wdlAuthBasicRequest(param1, param2, param3)
--|
--| Parameters: integer <pReqID>, string <pRequestHeaders>, string <pRequestHeadersXML>
--|
--| Return: string
----------------------------------------------------------------------*/

private function _wdlAuthBasicRequest pReqID, pRequestHeaders, pRequestHeadersXML
   local tRequestHeaders, tAuth, tAuthEncoded, tAuthString, tRequestResponse

   # BUILD AUTHORIZATION STRING
   put pRequestHeaders into tRequestHeaders
   put sWebDavPoolA[pReqID]["user"] & ":" & sWebDavPoolA[pReqID]["password"] into tAuth
   put base64encode(tAuth) into tAuthEncoded
   put "Basic" && tAuthEncoded into tAuthString
   #

   # BUILD HEADERS
   if sWebDavPoolA[pReqID]["method"] is not among the items of "PROPPATCH,PROPFIND" then
      put return & "Authorization:" && tAuthString after tRequestHeaders
   else
      put CRLF & "Authorization:" && tAuthString after tRequestHeaders
   end if

   if sWebDavPoolA[pReqID]["method"] is "PROPFIND" or sWebDavPoolA[pReqID]["method"] is "PROPPATCH" or sWebDavPoolA[pReqID]["method"] is "LOCK" then -- ADD XML STUFF
      put CRLF & CRLF & pRequestHeadersXML after tRequestHeaders
   end if

   if sWebDavPoolA[pReqID]["method"] is "UNLOCK" then
      put return & return after tRequestHeaders
      -- put CRLF & CRLF after tRequestHeaders
   end if

   if sWebDavPoolA[pReqID]["method"] is "PUT" then
      -- put tRequestHeaders & CRLF & CRLF & sWebDavPoolA[pReqID]["dataToUpload"] into tRequestHeaders
      replace CRLF with return in tRequestHeaders
   end if

   put tRequestHeaders into sWebDavPoolA[pReqID]["currentRequest"]

   # SEND REQUEST
   put _wdlRequestResponse(pReqID, sWebDavPoolA[pReqID]["currentRequest"]) into tRequestResponse

   return tRequestResponse
end _wdlAuthBasicRequest







/*----------------------------------------------------------------------
--| COMMAND wdlConnectionUp
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2008-05-30
--| Last Mod: --
--| Requires: wdlGotResponse
--|
--| Summary: Send request after socket was opened (PROPFIND, PROPPATCH, LOCK, UNLOCK methods).
--|
--| Format:  wdlConnectionUp param1
--|
--| Parameters: string <pSocket>
--|
--| Return: empty
----------------------------------------------------------------------*/

command wdlConnectionUp pSocket
   set sockettimeoutinterval to the cSocketTimeoutWrite of stack "WebDavLib" * 1000

   write sWebDavPoolA[sCurrentReqID]["currentRequest"] to socket pSocket with message "wdlGotResponse"
end wdlConnectionUp





/*----------------------------------------------------------------------
--| COMMAND wdlGotResponse
--|
--| Author: rabit
--| Version:  1.1
--| Created: 2008-05-30
--| Last Mod: 2020-03-26
--| Requires: _wdlCleanedResponseData, _wdlGetLockToken()
--|
--| Summary: Get response from server (PROPFIND, PROPPATCH, LOCK, UNLOCK methods),
--|          and check if the transfer is complete.
--|
--| Format:  wdlGotResponse param1, param2
--|
--| Parameters: string <pSocket>, string <pData>
--|
--| Return: empty
----------------------------------------------------------------------*/

command wdlGotResponse pSocket, pData
   local tCompleted, tResponse, tSocketID

   put _wdlCleanedResponseData(pSocket, pData, tCompleted) into tCleanedResponseData
   put tCleanedResponseData after sWebDavPoolA[sCurrentReqID]["HTTPresponse"]

   set sockettimeoutinterval to the cSocketTimeoutRead of stack "WebDavLib" * 1000

   read from socket pSocket with message "wdlGotResponse"

   # NOW FINISHED GETTING RESPONSE
   if tCleanedResponseData <> empty then
      put tCleanedResponseData & return into tResponse

      _wdlWriteLog sCurrentReqID, tResponse
   end if

   if tResponse contains "Lock-Token:" then
      set the cCurrentLockToken of stack "WebDavLib" to _wdlGetLockToken(tResponse)
   end if

   set the itemDel to "|"
   put item 2 of pSocket into tSocketID

   put tCompleted into sWebDavPoolA[sCurrentReqID][tSocketID]
end wdlGotResponse




/*----------------------------------------------------------------------
--| FUNCTION _wdlCleanedResponseData
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-03-04
--| Last Mod: 2020-03-04
--| Requires: --
--|
--| Summary: Remove empty lines and length info in chunked response data.
--|
--| Format:  _wdlCleanedResponseData(param1, param2, param3)
--|
--| Parameters: string <pSocketID>, string <pData>, string <pCompleted>
--|
--| Return: string
----------------------------------------------------------------------*/

private function _wdlCleanedResponseData pSocketID pData @pCompleted
   local tSocketID, tResponse

   set the itemDel to "|"
   put item 2 of pSocketID into tSocketID

   if pData <> empty then
      put pData & return into tResponse

      # REMOVE EMPTY LINE AND \r\n ("<CR>") AT END OF CHUNK
      if (line -1 of tResponse is empty) and (matchText(line -3 of tResponse, "^</[:a-zA-Z]+>")) then
         put line 1 to -2 of tResponse into tResponse
         delete char -1 of tResponse
      end if

      # REMOVE LENGTH OF CURRENT CHUNK IN HEXADECIMAL FORMAT FOLLOWED BY \r\n ("<CR>")
      if matchText(line 1 of tResponse, "^[0-9a-fA-F]+\r") then
         put line 2 to -1 of tResponse into tResponse
      end if

      # END OF TRANSFER
      # CHECK IF THIS IS THE LAST CHUNK TRANSFERRED
      if matchText(tResponse, "0\r") is TRUE then
         put "COMPLETED" into pCompleted
      end if
   end if -- if pData <> empty

   return tResponse
end _wdlCleanedResponseData



/*----------------------------------------------------------------------
--| COMMAND _wdlWriteError
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-02-11
--| Last Mod: --
--| Requires: --
--|
--| Summary: Write error text into an error field in stack sLogTarget when a socket error occurs.
--|
--| Format:  _wdlWriteError param1[, param2]
--|
--| Parameters: string <pErrorString>, integer <pSocketID> (optional)
--|
--| Return: empty
----------------------------------------------------------------------*/

private command _wdlWriteError pErrorString pSocketID
   if sLogTargetExists then
      do merge("dispatch" && quote & sWriteErrorCommand & quote && "to stack [[sLogTarget]] with pErrorString, pSocketID")
   end if
end _wdlWriteError






/*----------------------------------------------------------------------
--| COMMAND socketClosed
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-03-04
--| Last Mod: 2020-03-04
--| Requires: --
--|
--| Summary: Mark socket of current request as closed.
--|
--| Format:  socketClosed param1
--|
--| Parameters: string <pSocketID>
--|
--| Return: empty
----------------------------------------------------------------------*/

on socketClosed pSocketID
   local tSocketID

   set the itemDel to "|"
   put item 2 of pSocketID into tSocketID

   put "CLOSED" into sWebDavPoolA[sCurrentReqID][tSocketID]
end socketClosed





/*----------------------------------------------------------------------
--| COMMAND socketTimeout
--|
--| Author: rabit
--| Version:  1.1
--| Created: 2008-06-06
--| Last Mod: 2020-04-01
--| Requires: _wdlWriteError
--|
--| Summary: Write error text into an error field in stack sLogTarget when a socket command halts.
--|
--| Format:  socketTimeout param1
--|
--| Parameters: integer <pSocketID>
--|
--| Return: empty
----------------------------------------------------------------------*/

on socketTimeout pSocketID
   local tTimeOutMsg

   put cr & cr & "Timeout!" && pSocketID into tTimeOutMsg
   _wdlWriteError tTimeOutMsg

   put "socketTimeout" into sWebDavPoolA[sCurrentReqID]["HTTPresponse"]
end socketTimeout





/*----------------------------------------------------------------------
--| FUNCTION _wdlGetLockToken
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2008-06-09
--| Last Mod: --
--| Requires: --
--|
--| Summary: Get the lock token from the server response.
--|
--| Format:  _wdlGetLockToken(param1)
--|
--| Parameters: string <pServerResponse>
--|
--| Return: string
----------------------------------------------------------------------*/

private function _wdlGetLockToken pServerResponse
   local tTokenLineNum, tTokenLine, tPropOffset, tTokenLastCharNum, tLockToken

   put lineoffset("opaquelocktoken:", pServerResponse) into tTokenLineNum
   put line tTokenLineNum of pServerResponse into tTokenLine
   put offset("<opaquelocktoken:", tTokenLine) into tPropOffset
   put offset(">",tTokenLine) into tTokenLastCharNum
   put char tPropOffset to tTokenLastCharNum of tTokenLine into tLockToken

   return tLockToken
end _wdlGetLockToken




/*----------------------------------------------------------------------
--| FUNCTION wdlSetRemovePropXMLdata
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-02-25
--| Last Mod: --
--| Requires: --
--|
--| Summary: Build property XML data setting and removing custom props.
--|
--| Format:  wdlSetRemovePropXMLdata(param1, param2)
--|
--| Parameters: array <pSetPropsA>, array <pRemovePropsA>
--|
--| Return: string
----------------------------------------------------------------------*/

function wdlSetRemovePropXMLdata pSetPropsA, pRemovePropsA
   local tKeyDelim, tValueDelim, tProps, tSetPropsXML, tPropsLineNums
   local tCurrentLine, tPropsLine, tValue, tNodes, tPrevNodes, tNextNodes
   local tRemoveProps, tPropLine, tLastTag, tOpeningTags, tClosingTags
   local tRemovePropsXML, tPropsXML

   # BUILD SET PROPERTY XML DATA
   if pSetPropsA is an array then

      put "-" into tKeyDelim
      put "=" into tValueDelim

      put _wdlArrayToKeyValueList(pSetPropsA, tKeyDelim, tValueDelim) into tProps

      ## SORT PROPS LINES
      set the itemdelimiter to tKeyDelim
      sort tProps by item 1 of each

      ## BUILD XML
      put "<D:set>" & return & "<D:prop>" & return into tSetPropsXML

      ## GET VALUES FROM PROPSLIST
      set the itemdelimiter to tKeyDelim
      put the number of lines of tProps into tPropsLineNums
      put 1 into tCurrentLine

      repeat for each line tPropsLine in tProps
         if item 1 of tPropsLine is a number then
            delete item 1 of tPropsLine

            ## GET VALUE
            set the itemdelimiter to tValueDelim
            put last item of tPropsLine into tValue

            ## GET NODE NAMES
            put tPropsLine into tNodes
            delete last item of tNodes

            ## BUILD XML
            set the itemdelimiter to tKeyDelim
            if tNodes <> tPrevNodes then
               ## WRITE OPENING TAGS
               repeat for each item tNode in tNodes
                  put "<Z:" & tNode & ">" & return after tSetPropsXML
                  if tNode is last item of tNodes then
                     ## WRITE FIRST VALUE AFTER LAST OPENING TAG
                     delete char -1 of tSetPropsXML
                     put tValue & "</Z:" & tNode & ">" & return after tSetPropsXML
                  end if
               end repeat
               put tNodes into tPrevNodes

            else
               ## WRITE VALUES
               put last item of tPrevNodes into tNode
               put "<Z:" & tNode & ">" & tValue & "</Z:" & tNode & ">" & return after tSetPropsXML
            end if -- IF tNodes <> tPrevNodes then

            ## CHECK IF NODES IN NEXT LINE ARE EQUAL
            if tCurrentLine < tPropsLineNums then
               ## GET NODES OF NEXT LINE
               put line (tCurrentLine + 1) of tProps into tNextNodes
               set the itemdelimiter to tValueDelim
               delete last item of tNextNodes -- REMOVE VALUE
               set the itemdelimiter to tKeyDelim
               delete item 1 of tNextNodes -- REMOVE NUMBER

               ## COMPARE NODES IN CURRENT AND NEXT LINE
               if tNextNodes <> tPrevNodes then
                  ## WRITE CLOSING TAGS
                  repeat with i = (the number of items of tPrevNodes -1) down to 1
                     put "</Z:" & item i of  tPrevNodes & ">" & return after tSetPropsXML
                  end repeat
                  put empty into tPrevNodes
               end if

            else -- IF TCURRENTLINE < TPROPSLINENUMS THEN
               ## WRITE CLOSING TAGS
               repeat with i = (the number of items of tPrevNodes -1) down to 1
                  put "</Z:" & item i of  tPrevNodes & ">" & return after tSetPropsXML
               end repeat
            end if -- IF TCURRENTLINE < TPROPSLINENUMS THEN

            else -- IF ITEM 1 OF TPROPSLINE IS A NUMBER THEN
               set the itemdelimiter to tValueDelim
               put item 1 of tPropsLine into tNode
               put last item of tPropsLine into tValue
               put "<Z:" & tNode & ">" & tValue & "</Z:" & tNode & ">" & return after tSetPropsXML
            end if -- IF ITEM 1 OF TPROPSLINE IS A NUMBER THEN

            add 1 to tCurrentLine
         end repeat

         put "</D:prop>" & return & "</D:set>" after tSetPropsXML

      end if -- IF pSetPropsA IS NOT EMPTY THEN

      ##
      ## BUILD REMOVE PROPERTY XML DATA
      if pRemovePropsA is an array then

         put "-" into tKeyDelim
         put "=" into tValueDelim

         put _wdlArrayToKeyValueList(pRemovePropsA, tKeyDelim, tValueDelim) into tRemoveProps

         put "<D:remove>" & return & "<D:prop>" & return into tRemovePropsXML

         repeat for each line tPropLine in tRemoveProps
            delete last char of tPropLine -- "="

            set the itemdelimiter to tKeyDelim

            if the number of items of tPropLine > 1 then
               repeat for each item thisItem in tPropLine
                  if thisItem is last item of tPropLine then
                     ## WRITE OPENING TAG AND CLOSING TAG IN ONE LINE
                     put "<Z:" & thisItem & "></Z:" & thisItem & ">" into tLastTag
                  else
                     ## WRITE OPENING TAGS
                     put "<Z:" & thisItem & ">" & cr after tOpeningTags
                     put cr & "</Z:" & thisItem & ">" before tClosingTags
                  end if
               end repeat
               ## BUILD XML
               put tOpeningTags & tLastTag & tClosingTags & cr after tRemovePropsXML
            else
               put "<Z:" & tPropLine & "></Z:" & tPropLine & ">" & return after tRemovePropsXML
            end if
         end repeat

         put "</D:prop>" & return & "</D:remove>" after tRemovePropsXML
      end if -- IF pRemovePropsA IS AN ARRAY THEN

      ## ADD SET PROPS XML
      if tSetPropsXML is not empty then
         put  tSetPropsXML into tPropsXML
         if tRemovePropsXML is not empty then
            put tPropsXML & return & tRemovePropsXML into tPropsXML
         end if
      else
         if tRemovePropsXML is not empty then
            put tRemovePropsXML into tPropsXML
         end if
      end if

      return tPropsXML
   end wdlSetRemovePropXMLdata




   /*----------------------------------------------------------------------
   --| FUNCTION wdlPropertyNamesXMLdata
   --|
   --| Author: rabit
   --| Version:  1.0
   --| Created: 2020-03-04
   --| Last Mod: 2020-03-04
   --| Requires: --
   --|
   --| Summary: Build properties XML request data.
   --|
   --| Format:  wdlPropertyNamesXMLdata(param1, param2)
   --|
   --| Parameters: string <pProps>, bool <pCustomProps>
   --|
   --| Return: string
   ----------------------------------------------------------------------*/

   function wdlPropertyNamesXMLdata pProps pCustomProps
      local tPropsXML

      # BUILD PROPERTY XML DATA
      if pProps is not empty then -- ELSE ALL PROPERTIES ARE SENT
      if pCustomProps is TRUE then -- CUSTOM PROPERTIES
         repeat for each item thisItem in pProps
            put "<R:" & thisItem & "/>" & cr after tPropsXML
         end repeat
      else
         repeat for each item thisItem in pProps
            put "<D:" & thisItem & "/>" & cr after tPropsXML
         end repeat
      end if
      delete char -1 of tPropsXML
   end if -- if pProps is not empty

   return tPropsXML
end wdlPropertyNamesXMLdata




/*----------------------------------------------------------------------
--| FUNCTION _wdlPropertyVals
--|
--| Author: rabit
--| Version:  1.1
--| Created: 2020-02-26
--| Last Mod: 2020-05-04
--| Requires: --
--|
--| Summary: Get value(s) of a specific property in XML response data.
--|
--| Format:  _wdlPropertyVals(param1, param2)
--|
--| Parameters: string <pProp>, string <pFilePropValues> (XML response)
--|
--| Return: string
----------------------------------------------------------------------*/

private function _wdlPropertyVals pProps pFilePropValues
   local tPropLineNum, tFilePropValues, tProp, tPropLine
   local tPropValue, tOpaqueTokenLineNum, tTokenLine
   local tOpaqueToken, tTheResultA

   repeat for each item tProp in pProps
      put empty into tPropLineNum
      put pFilePropValues into tFilePropValues

      repeat until tPropLineNum is 0
         put lineOffset(tProp & ">", tFilePropValues) into tPropLineNum

         if tPropLineNum <> 0 then
            put line tPropLineNum of tFilePropValues into tPropLine

            if tProp is "lockdiscovery" then
               get matchText(tPropLine, "(?U)<.*lockdiscovery.*><.*:(.*)>" , tPropValue)
            else
               get matchText(tPropLine, "(?U)<.*" & tProp & ".*>(.*)</" , tPropValue)
            end if -- if tProp is "lockdiscovery"

            if it is true then
               if tProp is "lockdiscovery" then
                  # GET LOCK TOKEN
                  put lineOffset(">opaquelocktoken:", tFilePropValues) into tOpaqueTokenLineNum
                  put line tOpaqueTokenLineNum of tFilePropValues into tTokenLine
                  get matchText(tTokenLine, "(?U).*>(opaquelocktoken:.*)<.*>" , tOpaqueToken)
                  put tPropValue & return & "lock token:" && "<" & tOpaqueToken & ">" into tTheResultA[tProp]
               else
                  put tPropValue into tTheResultA[tProp]
               end if
            else
               put "Property value not found!" into tTheResultA[tProp]
            end if -- if it is true
         else
            exit repeat
         end if -- if tPropLineNum <> 0

         if tProp is "lockdiscovery" then
            exit repeat
         end if

         put line tPropLineNum + 1 to -1 of tFilePropValues into tFilePropValues
      end repeat
   end repeat

   return tTheResultA
end _wdlPropertyVals






/*----------------------------------------------------------------------
--| COMMAND wdlCheckResponse
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-04-01
--| Last Mod: --
--| Requires: _wdlWriteError
--|
--| Summary: Check if response exceeds time limit.
--|
--| Format:  wdlCheckResponse
--|
--| Parameters: --
--|
--| Return: empty
----------------------------------------------------------------------*/

command wdlCheckResponse
   local tCounter, tReqID, tErrorString

   put 0 into tCounter

   repeat with tReqID = 1 to sMaxRequests
      if sWebDavPoolA[tReqID]["status"] is not empty and sWebDavPoolA[tReqID]["status"] \
            is not in "done,error,cancelled,socketTimeout,timeLimitExceeded" then
         if the millisecs - sWebDavPoolA[tReqID]["startTime"] > sTimeout then
            put "Error: Timeout!" into sWebDavPoolA[tReqID]["error"]
            # STOP WAITING
            put "timeLimitExceeded" into sWebDavPoolA[tReqID]["HTTPresponse"]
            -- put "COMPLETED" into sWebDavPoolA[tReqID]["pFindPatchLockAuth"]

            put "Time limit exceeded." & cr into tErrorString
            _wdlWriteError tErrorString

            exit repeat
         end if

         add 1 to tCounter
      end if
   end repeat

   if tCounter > 0 then
      send "wdlCheckResponse" to me in sCheckResponseInterval millisecs
   end if
end wdlCheckResponse





/*----------------------------------------------------------------------
--| COMMAND _wdlCleanUp
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-04-01
--| Last Mod: --
--| Requires: --
--|
--| Summary: Delete varaiables and close socket of a specific request.
--|
--| Format:  _wdlCleanUp param1
--|
--| Parameters: integer <pReqID>
--|
--| Return: empty
----------------------------------------------------------------------*/

private command _wdlCleanUp pReqID
   close socket sWebDavPoolA[pReqID]["socketToOpen"]

   repeat for each key tKey in sWebDavPoolA[pReqID]
      if tKey <> "HTTPresponse" then
         delete variable sWebDavPoolA[pReqID][tKey]
      end if
   end repeat
end _wdlCleanUp






/*----------------------------------------------------------------------
--| COMMAND _wdlCheckLogTarget
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-04-01
--| Last Mod: --
--| Requires: --
--|
--| Summary: Check if there is a target for logging.
--|
--| Format:  _wdlCheckLogTarget
--|
--| Parameters: --
--|
--| Return: empty
----------------------------------------------------------------------*/

private command _wdlCheckLogTarget
   put empty into sLogTargetExists
   if sLogTarget is not empty then
      do merge("put there is a stack [[sLogTarget]] into sLogTargetExists")
   end if
end _wdlCheckLogTarget






/*----------------------------------------------------------------------
--| FUNCTION _wdlResponseToReturn
--|
--| Author: rabit
--| Version:  1.0
--| Created: 2020-04-07
--| Last Mod: --
--| Requires: _wdlProcessResponse(), _wdlSetErrorOrDoneStatus, _wdlCleanUp, wdlCleanup
--|
--| Summary: Prepare response and write logs.
--|
--| Format:  _wdlResponseToReturn(param1, param2)
--|
--| Parameters: integer <pReqID>, string <pRequestResponse>
--|
--| Return: string
----------------------------------------------------------------------*/

private function _wdlResponseToReturn pReqID pRequestResponse
   local tResponse, tRequestResponse

   if sWebDavPoolA[pReqID]["method"] <> "PUT" then
      get _wdlProcessResponse(pReqID, pRequestResponse)
      put it into pRequestResponse

      _wdlSetErrorOrDoneStatus pReqID, tResponse
      _wdlWriteStatus pReqID, sWebDavPoolA[pReqID]["status"]
      _wdlCleanUp pReqID

   else
      # PUT RETURNS ERROR OR EMPTY
      _wdlSetErrorOrDoneStatus pReqID, pRequestResponse
      _wdlWriteStatus pReqID, sWebDavPoolA[pReqID]["status"]
      wdlCleanup pReqID
   end if
       return pRequestResponse
end _wdlResponseToReturn







/*----------------------------------------------------------------------
--| FUNCTION _wdlCustomHeaders
--|
--| Author: rabit
--| Version:  1.1
--| Created: 2020-04-01
--| Last Mod: 2020-05-05
--| Requires: --
--|
--| Summary: Build custom headers.
--|
--| Format:  _wdlCustomHeaders(param)
--|
--| Parameters: integer <pReqID>
--|
--| Return: string
----------------------------------------------------------------------*/

private function _wdlCustomHeaders pReqID
   local tRequestHeadersA, tHeaders, tSocketID
   local tHeadersXML, tErrorString, tMethods

   switch sWebDavPoolA[pReqID]["method"]
      case "OPTIONS"
         put the cOptionsHeaders of stack "WebDavLib" into tHeaders
         replace "{uri}" with sWebDavPoolA[pReqID]["uri"] in tHeaders

         put "pOptions" into tSocketID

         break
      case "MKCOL"
         put the cMkcolHeaders of stack "WebDavLib" into tHeaders
         replace "{uri}" with sWebDavPoolA[pReqID]["uri"] in tHeaders
         -- replace "{agent}" with sWebDavPoolA[pReqID]["agent"] in tHeaders

         put "pMkcol" into tSocketID

         break
      case "GET"
         put the cGetHeaders of stack "WebDavLib" into tHeaders
         replace "{uri}" with sWebDavPoolA[pReqID]["uri"] in tHeaders
         replace "{agent}" with sWebDavPoolA[pReqID]["agent"] in tHeaders

         put "pGet" into tSocketID

         break
      case "PUT"
         put the cGenericHeaders of stack "WebDavLib" into tHeaders
         replace "{method}" with sWebDavPoolA[pReqID]["method"] in tHeaders
         replace "{uri}" with sWebDavPoolA[pReqID]["uri"] in tHeaders
         replace "{agent}" with sWebDavPoolA[pReqID]["agent"] in tHeaders
         replace "{contType}" with sWebDavPoolA[pReqID]["contentType"] in tHeaders
         replace "{contLength}" with sWebDavPoolA[pReqID]["contentLength"] in tHeaders

         if the cExpect100 of stack "WebDavLib" is TRUE then
            put return & "Expect: 100-continue" after tHeaders ------------------------------ TEST
         end if

         put "pPut" into tSocketID
         -- put sWebDavPoolA[pReqID]["host"] & ":" & sWebDavPoolA[pReqID]["port"] & "|" & tSocketID into sWebDavPoolA[pReqID]["socketToOpen"]

         break
      case "DELETE"
         put the cDeleteHeaders of stack "WebDavLib" into tHeaders
         replace "{uri}" with sWebDavPoolA[pReqID]["uri"] in tHeaders
         replace "{agent}" with sWebDavPoolA[pReqID]["agent"] in tHeaders

         put "pDelete" into tSocketID

         break
      case "PROPFIND"
         put the cGenericHeaders of stack "WebDavLib" into tHeaders
         put the cPropFindBody of stack "WebDavLib" into tHeadersXML

         # FOR DIRECTORY LISTINGS ADD DEPTH
         if ("resourcetype" is in sWebDavPoolA[pReqID]["propertiesXML"]) or (sWebDavPoolA[pReqID]["propertiesXML"] is empty) then
           if sWebDavPoolA[pReqID]["depth"] is an integer then
             put return & "Depth:" && sWebDavPoolA[pReqID]["depth"] after tHeaders
           else
             put return & "Depth:" && the cDepth of stack "WebDavLib" after tHeaders
           end if
         end if

         if sWebDavPoolA[pReqID]["propertiesXML"] is empty then
            put "<D:allprop/>" into line 3 to 5 of tHeadersXML
         else
            if sWebDavPoolA[pReqID]["propertiesXML"] <> "<D:propname/>" then
               if sWebDavPoolA[pReqID]["nameSpace"] is not empty then
                  replace "{namespace}" with " xmlns:R=" & sWebDavPoolA[pReqID]["nameSpace"] in tHeadersXML
               else
                  replace "{namespace}" with empty in tHeadersXML
               end if
               replace "{props}" with sWebDavPoolA[pReqID]["propertiesXML"] in tHeadersXML

            else -- sWebDavPoolA[pReqID]["propertiesXML"] <> "<D:propname/>"
               put sWebDavPoolA[pReqID]["propertiesXML"] into line 3 to 5 of tHeadersXML
            end if -- sWebDavPoolA[pReqID]["propertiesXML"] <> "<D:propname/>"
         end if -- sWebDavPoolA[pReqID]["propertiesXML"] is empty

         replace "{method}" with sWebDavPoolA[pReqID]["method"] in tHeaders
         replace "{uri}" with sWebDavPoolA[pReqID]["uri"] in tHeaders
         replace "{contType}" with sWebDavPoolA[pReqID]["contentType"] in tHeaders
         replace "{contLength}" with length(tHeadersXML) in tHeaders

         put "pfind" into tSocketID
         put sWebDavPoolA[pReqID]["host"] & ":" & sWebDavPoolA[pReqID]["port"] & "|" & tSocketID into sWebDavPoolA[pReqID]["socketToOpen"]

         break
      case "PROPPATCH"
         put the cGenericHeaders of stack "WebDavLib" into tHeaders
         put the cPropPatchBody of stack "WebDavLib" into tHeadersXML

         replace "{method}" with sWebDavPoolA[pReqID]["method"] in tHeaders
         replace "{uri}" with sWebDavPoolA[pReqID]["uri"] in tHeaders
         replace "{contType}" with sWebDavPoolA[pReqID]["contentType"] in tHeaders
         replace "{namespace}" with sWebDavPoolA[pReqID]["nameSpace"] in tHeadersXML
         replace "{setRemoveProps}" with sWebDavPoolA[pReqID]["propertiesXML"] in tHeadersXML
         replace "{contLength}" with length(tHeadersXML) in tHeaders

         put "pPatch" into tSocketID
         put sWebDavPoolA[pReqID]["host"] & ":" & sWebDavPoolA[pReqID]["port"] & "|" & tSocketID into sWebDavPoolA[pReqID]["socketToOpen"]

         break
      case "HEAD"
         put the cHeadHeaders of stack "WebDavLib" into tHeaders
         replace "{uri}" with sWebDavPoolA[pReqID]["uri"] in tHeaders
         replace "{agent}" with sWebDavPoolA[pReqID]["agent"] in tHeaders

         put "pHead" into tSocketID

         break
      case "LOCK"
         put the cLockHeaders of stack "WebDavLib" into tHeaders
         put the cLockBody of stack "WebDavLib" into tHeadersXML

         replace "{uri}" with sWebDavPoolA[pReqID]["uri"] in tHeaders
         replace "{timeout}" with sWebDavPoolA[pReqID]["lockTimeout"] in tHeaders
         replace "{contType}" with sWebDavPoolA[pReqID]["contentType"] in tHeaders
         replace "{scope}" with sWebDavPoolA[pReqID]["lockScope"] in tHeadersXML
         replace "{type}" with sWebDavPoolA[pReqID]["lockType"] in tHeadersXML
         replace "{owner}" with sWebDavPoolA[pReqID]["lockOwner"] in tHeadersXML
         replace "{contLength}" with length(tHeadersXML) in tHeaders

         put "fLock" into tSocketID
         put sWebDavPoolA[pReqID]["host"] & ":" & sWebDavPoolA[pReqID]["port"] & "|" & tSocketID into sWebDavPoolA[pReqID]["socketToOpen"]

         break
      case "UNLOCK"
         put the cUnlockHeaders of stack "WebDavLib" into tHeaders
         replace "{uri}" with sWebDavPoolA[pReqID]["uri"] in tHeaders
         replace "{lockToken}" with sWebDavPoolA[pReqID]["lockToken"] in tHeaders

         put "fUnlock" into tSocketID
         put sWebDavPoolA[pReqID]["host"] & ":" & sWebDavPoolA[pReqID]["port"] & "|" & tSocketID into sWebDavPoolA[pReqID]["socketToOpen"]

         break
      default
         put "Unknown method provided!" into tErrorString
         _wdlWriteError tErrorString
         answer error tErrorString

         exit to top
   end switch

   replace "{host}" with sWebDavPoolA[pReqID]["host"] in tHeaders

   # COMPLY WITH STANDARD HttpProtocolOptions
   put "DELETE,HEAD,GET,OPTIONS,MKCOL" into tMethods
   if sWebDavPoolA[pReqID]["method"] is not among the items of tMethods then
      -- if sWebDavPoolA[pReqID]["method"] <> "DELETE" then
      replace return with CRLF in tHeaders
   end if

   put tHeaders into tRequestHeadersA["requestHeaders"]
   put tSocketID into tRequestHeadersA["socketID"]
   put tHeadersXML into tRequestHeadersA["requestHeadersXML"]

   return tRequestHeadersA
end _wdlCustomHeaders





/*----------------------------------------------------------------------
--| FUNCTION _wdlArrayToKeyValueList
--|
--| Author: rabit
--| Version:  1.0
--| Created:  --
--| Last Mod: 2008-09-15
--| Requires:  _wdlArrayToKeyValueHelper, script locals sKeyValueList and sKeys
--|
--| Summary: Returns list of keys and values of a given array. Needs more
--|          work for multidimensional arrays!!!!!!!
--|
--| Format:  _wdlArrayToKeyValueList(param1,param2,param3)
--|
--| Parameters: array <pArrayA>, string <pKeyDelim>, string <pValueDelim>
--|
--| Return: string
----------------------------------------------------------------------*/

private function _wdlArrayToKeyValueList pArrayA pKeyDelim pValueDelim
   local tArray,tArrayKeys,theID,tKey

   put empty into sKeyValueList

   put the keys of pArrayA into tArrayKeys

   repeat for each line tKey in tArrayKeys
      if pArrayA[tKey] is an array then

         put empty into sKeys

         _wdlArrayToKeyValueHelper pArrayA,tKey,pKeyDelim,pValueDelim

      else
         ## BUILD LIST
         put tKey & "=" & pArrayA[tKey] & cr after sKeyValueList
      end if
   end repeat

   delete last char of sKeyValueList

   return sKeyValueList
end _wdlArrayToKeyValueList





/*----------------------------------------------------------------------
--| COMMAND _wdlArrayToKeyValueHelper
--|
--| Author: rabit
--| Version:  1.0
--| Created:  2008-09-15
--| Last Mod: --
--| Requires: script locals sKeyValueList and sKeys
--|
--| Summary: Needed by _wdlArrayToKeyValueList.
--|
--| Format:  _wdlArrayToKeyValueHelper param1 param2 param3 param4
--|
--| Parameters: array <pArrayA>, string <pKey>, string <pKeyDelim>, string <pValueDelim>>
--|
--| Return: empty
----------------------------------------------------------------------*/

private command _wdlArrayToKeyValueHelper pArrayA pKey pKeyDelim pValueDelim
   local tAllKeys,tArrayChildElement,tKey,tKeysString

   local tKeyToAdd,tNextKey,tNextKeys
   ## BUILD LIST OF KEYS
   if sKeys is empty then
      put pKey into sKeys
   else
      put cr & pKey after sKeys
   end if

   repeat for each line tKey in sKeys
      ## ADD KEYS TO VARIABLE NAME LIKE  tName[key][key][key][key][key] ...
      put "[" & tKey & "]" after tAllKeys
      ## BUILD STRING OF KEYS FOR LIST
      put "-" & tKey after tKeysString
   end repeat
   delete char 1 of tKeysString

   ## BUILD VARIABLE
   do "put" && merge("pArrayA[[tAllKeys]]") && "into tArrayToCheck"

   if tArrayToCheck is an array then
      repeat for each element tArrayChildElement in tArrayToCheck

         if tArrayChildElement is an array then
            put the keys of tArrayToCheck into tNextKeys

            repeat for each line tNextKey in tNextKeys
               if tNextKey is not tPrevKey then
                  put empty into tPrevKey
                  _wdlArrayToKeyValueHelper pArrayA,tNextKey,pKeyDelim,pValueDelim
               else
                  next repeat
               end if
            end repeat

         else
            ## BUILD LIST
            put the keys of tArrayToCheck into tKeyToAdd

            repeat for each line tKeyLineTocheck in tKeyToAdd
               put tKeyLineTocheck into tTestKey
               if tArrayToCheck[tTestKey] is tArrayChildElement then
                  put tTestKey into tPrevKey
                  put tKeysString & pKeyDelim & tTestKey & pValueDelim & tArrayChildElement & cr after sKeyValueList
                  exit repeat
               end if
            end repeat

         end if

      end repeat

   else
      ## BUILD LIST
      put tKeysString & pValueDelim &  tArrayToCheck & cr after sKeyValueList
   end if
end _wdlArrayToKeyValueHelper





on socketError pSocketID pErrorString
   _wdlWriteError pErrorString, pSocketID
end socketError
