script "WebDavTestStackBehavior"



local sBarName, sCurrentFileSize
local sContacted, sAuthorizationRequested, sProgBarInitialized, sKeepLogData

-----------------------------------------------------------


----------------------------------------------
# REQUEST HANDLERS
---------------------------------------------
----------------------------------
## METHOD: OPTIONS
----------------------------------

command options
   local tCallback, tRequestDataA, tReqID, tRequestedData

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA
   put fld "davDirFld" into tRequestDataA["uri"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # REQUEST
   put wdlGetserverMethods(tReqID) into tRequestedData

   put "wdlGetserverMethods:" && tRequestedData
   wdlCleanup tReqID
end options

------------------------------


----------------------------------
## METHOD: PROPFIND
----------------------------------

command fileSize
   local tFile, tProps, tNameSpace, tCallback
   local tRequestDataA, tReqID, tFilePropValuesA

   libUrlSetStatusCallback

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   # GET PROPERTY
   # LEAVE EMPTY TO GET ALL PROPERTIES
   put "getcontentlength" into tProps
   -- put "creationdate" into tProps
   -- put "getcontentlength,getlastmodified" into tProps

   # CUSTOM PROPERTIES
   # USE tNameSpace FOR CUSTOM PROPERTIES ONLY!!!!!
   -- put quote & fld "namespaceFld" & quote into tNameSpace
   -- put "authors,testTag" into tProps
   # USE propname TO RETREIVE ALL PROPERTY NAMES
   -- put "propname" into tProps

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA
   put tFile into tRequestDataA["uri"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # REQUEST
   put wdlGetFileProps(tReqID, tProps) into tFilePropValuesA

   put empty into msg
   repeat for each key tKey in tFilePropValuesA
      put tKey & ":" && tFilePropValuesA[tKey] & return after msg
   end repeat

   wdlCleanup tReqID

   return tFilePropValuesA["getcontentlength"]
end fileSize




command fileList
   local tPropsXML, tContType, tRequestDataA, tReqID, tResponseData
   local tStartLineNum, tEndLineNum, tFilesListXML, tFilesListA
   local tTheKeys, tKey, tFileFolder, tDate, tFileList

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put fld "davDirFld" into tRequestDataA["uri"]
   put "PROPFIND" into tRequestDataA["method"]

   # GET FILE / FOLDER PATHS (NAMES) ONLY
   # LEAVE tPropsXML EMPTY TO RETREIVE ALL PROPS
   -- put wdlPropertyNamesXMLdata("resourcetype") into tPropsXML
   -- put "text/xml; charset=" & quote & "utf-8" & quote into tContType

   put tPropsXML into tRequestDataA["propertiesXML"]
   put "application/xml; charset=" & quote & "utf-8" & quote into tContType
   put tContType into tRequestDataA["contentType"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   ## REQUEST
   put wdlExecute(tReqID) into tResponseData

   writeToLogWDL tReqID, tResponseData

   put lineOffset("<?xml", tResponseData) into tStartLineNum
   put lineOffset("</D:multistatus>", tResponseData) into tEndLineNum
   put line tStartLineNum to tEndLineNum of tResponseData into tFilesListXML

   put convertXMLToArray(tFilesListXML, , ) into tFilesListA
   -- put printArray("theArray", tFilesListA)

   -- put the keys of tFilesListA["multistatus"]
   -- put the keys of tFilesListA["multistatus"]["response[23]"]["propstat"]["prop"]
   put the keys of tFilesListA["multistatus"] into tTheKeys

   repeat for each line tKey in tTheKeys
      put tFilesListA["multistatus"][tKey]["href"] into tFileFolder
      if line -1 of tFileFolder is empty then next repeat

      if tPropsXML is empty then
         put tFilesListA["multistatus"][tKey]["propstat"]["prop"]["creationdate"] into tDate
         if tDate is empty then
            put tFilesListA["multistatus"][tKey]["propstat[1]"]["prop"]["creationdate"] into tDate
         end if
         if tDate <> empty then
            put "CD:" && tDate into tDate
         end if


         if tDate is empty then
            put tFilesListA["multistatus"][tKey]["propstat"]["prop"]["getlastmodified"] into tDate
         end if
         if tDate is empty then
            put tFilesListA["multistatus"][tKey]["propstat[1]"]["prop"]["getlastmodified"] into tDate
         end if

         if tDate <> empty then
            put "MD:" && tDate into tDate
         end if

         put tDate && "--" && tFileFolder & return after tFileList
      else
         put tFileFolder & return after tFileList
      end if
   end repeat

   put tFileList

   wdlCleanup tReqID
end fileList




command getProperties
   local tFile, tNameSpace, tProps, tFilePropValues

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   # GET PROPERTY
   # LEAVE EMPTY TO GET ALL PROPERTIES
   -- put "creationdate" into tProps
   -- put "getcontentlength" into tProps
   -- put "creationdate,getcontentlength" into tProps

   # CUSTOM PROPERTIES
   # USE tNameSpace FOR CUSTOM PROPERTIES ONLY!!!!!
   put quote & fld "namespaceFld" & quote into tNameSpace


   # LEAVE tProps EMPTY TO RETREIVE ALL PROPERTY NAMES AND ALL PROPERTY VALUES
   -- put "authors,testTag" into tProps
   -- put "authors" into tProps
   -- put "testTag" into tProps
   put "testTag,Author" into tProps

   # USE propname TO RETREIVE ALL PROPERTY NAMES, REQUIRES EMPTY NAMESPACE
   --   put empty into tNameSpace
   --   put "propname" into tProps

   put getFileProps(tFile, tNameSpace, tProps) into tFilePropValues

   --   put offset("<?xml", tFilePropValues) into tFilePropXMLStart
   --   put char tFilePropXMLStart to -1 of tFilePropValues into tFilePropXML
   --   put ConvertXMLToArray(tFilePropXML, , TRUE) into tFilePropValuesA
   --   put tFilePropValuesA["multistatus"]["response"]["propstat"]["prop"]["getcontentlength"]["@value"]
   --   -- put printArray("theArray", tFilePropValuesA)


   put "testTag,Author" into tProps
   -- put "testTag" into tProps
   -- put "creationdate,getcontentlength" into tProps

   repeat for each item thisItem in tProps
      put wdlPropertyVals(thisItem, tFilePropValues) after tTheResult
   end repeat

   delete char -1 of tTheResult
   put tTheResult & return & return & tFilePropValues
end getProperties




command checkLocked
   local tFile, tNameSpace, tProps, tFileLockPropValue

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   -- USE tNameSpace ONLY FOR CUSTOM PROPERTIES
   -- put quote & the cNameSpace of this stack & quote into tNameSpace

   -- CUSTOM PROPERTIES
   -- put "authors,testTag" into tProps -- LEAVE EMPTY TO GET ALL PROPERTIES

   put "lockdiscovery" into tProps

   put getFileProps(tFile, tNameSpace, tProps) into tFileLockPropValue
   if tFileLockPropValue contains "opaquelocktoken:" then
      put "File:" && tFile && "is locked"
   else
      put "File:" && tFile && "is not locked"
   end if
end checkLocked

--------------------------------



----------------------------------
## METHOD: GET
----------------------------------

command downloadFile
   local tFile, tDownloadFile = ""

   put fld "downloadPathFld" into tDestPath
   if tDestPath is empty then
      answer error "No download folder specified!"
      exit to top
   end if


   if the optionkey is not down then
      put true into tDownloadFile
   end if

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   getFile tFile, tDownloadFile
end downloadFile



command getFile pFile pDownloadFile
   local tHeader, tCallBack, tCallbackTarget, tRequestDataA, tReqID, tServerResponse
   local tFileName, tDestPath

   put empty into sCurrentFileSize

   ## GET SIZE OF FILE TO DOWNLOAD
   put "Content-Length" into tHeader
   put getFileHeader (pFile, tHeader) into sCurrentFileSize

   if pDownloadFile is "true" then

      put TRUE into tCallback
      put commonSettings(tCallback) into tRequestDataA

      put "GET" into tRequestDataA["method"]
      put pFile into tRequestDataA["uri"]

      wdlSetupNewRequest tRequestDataA
      put the result into tReqID

      # WORKS WITH libURLDownloadToFile, libURLftpUpload, libURLftpUploadFile, put,
      # AND load COMMANDS, AS WELL AS DOWNLOADS TRIGGERED BY EVALUATING AN FTP OR HTTP URL
      prepareProgress

      ## REQUEST
      put wdlExecute(tReqID) into tServerResponse

      wdlCleanup tReqID

      ## RESPONSE
      if tServerResponse contains "Error" then
         put cr & cr & tServerResponse after fld "errorFld"
      else
         ## SUCCESS, SAVE FILE
         set the itemdelimiter to "/"
         put last item of pFile into tFileName

         put fld "downloadPathFld" & "/" & tFileName into tDestPath

         put tServerResponse into URL ("binfile:" & tDestPath)
      end if
   end if -- IF PDOWNLOADFILE IS "TRUE" THEN
end getFile

----------------------------------



----------------------------------
## METHOD: PUT
----------------------------------

command checkWritePermission
   local tFile, tURI, tCallBack, tCallbackTarget, tContType, tDataToUpload
   local tRequestDataA, tReqID, tServerResponse, tDeleteResult

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put "PUT" into tRequestDataA["method"]
   put "writeTest.txt" into tFile
   put fld "davDirFld" & tFile into tURI
   put tURI into tRequestDataA["uri"]
   --   put "urlCallback" into tCallBack
   --   put tCallBack into tRequestDataA["callback"]
   --   put the long id of this stack into tCallbackTarget
   --   put tCallbackTarget into tRequestDataA["callbackTarget"]
   put "text/plain" into tContType
   put tContType into tRequestDataA["contentType"]
   ## GET SIZE OF FILE TO UPLOAD
   put 4 into sCurrentFileSize -- 4 BYTES FOR WORD "test"
   put sCurrentFileSize into tRequestDataA["contentLength"]
   put "test" into tDataToUpload
   put tDataToUpload into tRequestDataA["dataToUpload"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # WORKS WITH libURLDownloadToFile, libURLftpUpload, libURLftpUploadFile, put,
   # AND load COMMANDS, AS WELL AS DOWNLOADS TRIGGERED BY EVALUATING AN FTP OR HTTP URL
   -- prepareProgress

   ## REQUEST
   put wdlExecute(tReqID) into tServerResponse

   wdlCleanup tReqID

   ## RESPONSE
   if tServerResponse contains "Error" then
      put cr & cr & tServerResponse after fld "errorFld"
   else -- success
      # CHECKING WRITE PERMISSIONS, SO KEEP LOG DATA OF PUT METHOD
      put TRUE into sKeepLogData
      put deleteFileFolder(tURI) into tDeleteResult
   end if
   put "can write result:" && line 1 of tServerResponse & "," && "delete result:" && tDeleteResult
end checkWritePermission




command uploadFile
   local tUploadFilePath, tIdentNum, tIdent

   put fld "filePathFld" into tUploadFilePath
   put 1 into tIdentNum

   put tIdentNum & "-" into tIdent
   putFile tUploadFilePath, tIdent
end uploadFile




command putFile pFile pIdent
   local tFile, tURI, tCallBack, tCallbackTarget, tContType
   local tDataToUpload, tRequestDataA, tReqID, tServerResponse

   ## GET SIZE OF FILE TO UPLOAD
   getLocalFileSize pFile

   prepareLogFields

   put TRUE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put "PUT" into tRequestDataA["method"]

   set the itemdelimiter to "/"
   put last item of pFile into tFile
   if pIdent is not empty then
      put fld "davDirFld" & pIdent & the secs & "_" & tFile into tURI
   else
      put fld "davDirFld" & the secs & "_" & tFile into tURI
   end if
   put tURI into fld "fileToDeleteFld"
   put tURI into tRequestDataA["uri"]

   put "application/x-www-form-urlencoded" into tContType
   put tContType into tRequestDataA["contentType"]
   put sCurrentFileSize into tRequestDataA["contentLength"]
   put URL ("binfile:" & pFile) into tDataToUpload
   put tDataToUpload into tRequestDataA["dataToUpload"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # WORKS WITH libURLDownloadToFile, libURLftpUpload, libURLftpUploadFile, put,
   # AND load COMMANDS, AS WELL AS DOWNLOADS TRIGGERED BY EVALUATING AN FTP OR HTTP URL
   prepareProgress

   ## REQUEST
   put wdlExecute(tReqID) into tServerResponse

   wdlCleanup tReqID

   ## RESPONSE
   if tServerResponse contains "Error" then
      put cr & cr & tServerResponse after fld "errorFld"
   else
      if "201" is in line 1 of tServerResponse then
         put "Request ID" && tReqID & ": created" & cr after fld "statusFld"
      end if

      put tServerResponse
   end if
end putFile

---------------------------------




----------------------------------
## METHOD: DELETE
----------------------------------

command deleteFile
   local tFile

   put fld "fileToDeleteFld" into tFile
   put deleteFileFolder(tFile)
end deleteFile






function deleteFileFolder pFileFolder
   local tRequestDataA, tReqID, tServerResponse

   if sKeepLogData <> TRUE then
      prepareLogFields
   else
      # CHECKING WRITE PERMISSIONS, SO KEEP LOG DATA OF PUT METHOD
      put FALSE into sKeepLogData
   end if

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put "DELETE" into tRequestDataA["method"]
   put pFileFolder into tRequestDataA["uri"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # REQUEST
   put wdlExecute(tReqID) into tServerResponse

   wdlCleanup tReqID

   # RESPONSE
   if tServerResponse contains "Error" then
      put cr & cr & tServerResponse after fld "errorFld"
   end if
   return tServerResponse
end deleteFileFolder



command deleteFolder
   local tFolder

   put fld "davDirFld" & "testFolder/" into tFolder
   put deleteFileFolder(tFolder)
end deleteFolder

----------------------------------



----------------------------------
## METHOD: MKCOL
----------------------------------

command createFolder
   local tFolder, tRequestDataA, tReqID

   put fld "davDirFld" & "testFolder/" into tFolder

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put "MKCOL" into tRequestDataA["method"]
   put tFolder into tRequestDataA["uri"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # REQUEST
   get wdlExecute(tReqID)

   put it
   wdlCleanup tReqID
end createFolder

----------------------------------



----------------------------------
## METHOD: PROPPATCH
----------------------------------

command setProperties
   local tFile, tRemoveProps, tSetProps, tNameSpace

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   -- put "Ralf Bitter,Xaver Bleed,Renglnadders Godhilf" into tSetProps["authors,Author"]
   -- put "Ralf Bitter" into tSetProps["author"]

   ----------
   --   put "foo" into tSetProps[0]["testTag"]
   --   put "Ralf Bitter" into tSetProps[0]["authors"]["Author"]
   --   put "Xaver Bleed" into tSetProps[1]["authors"]["Author"]
   --   put "Renglnadders Godhilf" into tSetProps[2]["authors"]["Author"]
   -----------

   --------
   put "foo" into tSetProps[0]["testTag"]
   put "Ralf Bitter" into tSetProps[1]["Author"]
   ---------

   put empty into tRemoveProps

   # USE tNameSpace FOR CUSTOM PROPERTIES ONLY!!!!!
   -- put quote & the cNameSpace of this stack & quote into tNameSpace
   put quote & fld "namespaceFld" & quote into tNameSpace

   setFileProps tFile, tSetProps, tRemoveProps, tNameSpace
end setProperties




command setFileProps pFile, pSetProps, pRemoveProps, pNameSpace
   local tPropsXML, tContType, tContLength, tRequestDataA, tReqID

   ## CHECK PROPERTIES TO SET OR REMOVE
   if (pSetProps is empty and pSetProps is not an array) and (pRemoveProps is empty and pRemoveProps is not an array) then
      answer error "Properties list empty!"
      exit to top
   end if

   if pSetProps is not empty and pSetProps is not an array then
      answer error "Set properties list is not an array!"
      exit to top
   end if

   if pRemoveProps is not empty and pRemoveProps is not an array then
      answer error "Remove properties list is not an array!"
      exit to top
   end if

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put "PROPPATCH" into tRequestDataA["method"]
   put pFile into tRequestDataA["uri"]
   ## BUILD PROPERTY XML DATA
   put wdlSetRemovePropXMLdata(pSetProps, pRemoveProps) into tPropsXML
   put tPropsXML into tRequestDataA["propertiesXML"]
   put "application/xml; charset=" & quote & "utf-8" & quote into tContType
   put tContType into tRequestDataA["contentType"]
   put the number of chars of tPropsXML into tContLength
   put tContLength into tRequestDataA["contentLength"]
   put pNameSpace into tRequestDataA["nameSpace"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   ## REQUEST
   get wdlExecute(tReqID)
   put it

   wdlCleanup tReqID
end setFileProps




command removeProperties
   local tFile, tRemoveProps, tSetProps

   put fld "davDirFld" & fld "remoteFileFld" into tFile

   -- put empty into tSetProps

   -- put "authors" into tRemoveProps

   -- put empty into tRemoveProps["authors"]
   put empty into tRemoveProps["testTag"]
   put empty into tRemoveProps["Author"]

   # USE tNameSpace FOR CUSTOM PROPERTIES ONLY!!!!!
   -- put quote & the cNameSpace of this stack & quote into tNameSpace
   put quote & fld "namespaceFld" & quote into tNameSpace

   setFileProps tFile, tSetProps, tRemoveProps, tNameSpace
end removeProperties

----------------------------------


----------------------------------
## METHOD: LOCK
----------------------------------

command lockFile
   local tFile, tScope, tTimeout, tType
   local tRequestDataA,tReqID

   put fld "davDirFld" & fld "remoteFileFld" into tFile
   put "exclusive" into tScope
   put "write" into tType

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put "LOCK" into tRequestDataA["method"]
   put tFile into tRequestDataA["uri"]
   put "application/xml; charset=" & quote & "utf-8" & quote into tRequestDataA["contentType"]
   put tScope into tRequestDataA["lockScope"]
   put tType into tRequestDataA["lockType"]
   put "LCapp" into tRequestDataA["lockOwner"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   # REQUEST
   get wdlExecute(tReqID)

   -- put it
   wdlCleanup tReqID
end lockFile

----------------------------------



----------------------------------
## METHOD: UNLOCK
----------------------------------

command unlockFile
   local tToken, tFile, tRequestDataA, tReqID

   put the cCurrentLockToken of stack "WebDavLib" into tToken

   if tToken is not empty then
      put fld "davDirFld" & fld "remoteFileFld" into tFile

      prepareLogFields

      put FALSE into tCallback
      put commonSettings(tCallback) into tRequestDataA

      put "UNLOCK" into tRequestDataA["method"]
      put tFile into tRequestDataA["uri"]
      put tToken into tRequestDataA["lockToken"]

      wdlSetupNewRequest tRequestDataA
      put the result into tReqID

      # REQUEST
      get wdlExecute(tReqID)

      -- put it
      wdlCleanup tReqID

      set the cCurrentLockToken of stack "WebDavLib" to empty
   else
      answer error "There are no locked files!"
   end if
end unlockFile

----------------------------------


----------------------------------
## METHOD: HEAD
----------------------------------

function getFileHeader pFile pHeader
   local tRequestDataA, tReqID, tResponseData

   prepareLogFields

   put FALSE into tCallback
   put commonSettings(tCallback) into tRequestDataA

   put "HEAD" into tRequestDataA["method"]
   put pFile into tRequestDataA["uri"]

   wdlSetupNewRequest tRequestDataA
   put the result into tReqID

   ## REQUEST
   get wdlExecute(tReqID)
   put it into tResponseData

   wdlCleanup tReqID

   if tResponseData contains "Error" is false then
      return tResponseData[pHeader]
   else
      put cr & cr & tResponseData after fld "errorFld"
      return tResponseData
   end if
end getFileHeader

-------------------------------------


----------------------------------------------
------------------ LOGGING ---------------------

# THESE HANDLERS ARE CALLED BY THE WebDAV LIBRARY
command writeStatusWDL pReqID pStatus
   put "Request ID" && pReqID & ":" && pStatus & cr into pStatus
   put pStatus after fld "statusFld"
end writeStatusWDL




command writeToLogWDL pReqID pResponse pSocketToOpen pCurrentRequest
   local tLogData

   if pResponse is empty then
      put "Request ID:" && pReqID && "Socket selected:" && pSocketToOpen & cr & pCurrentRequest & cr & cr into tLogData
   else
      put pResponse & cr & cr into tLogData
   end if

   put tLogData after fld "logFld"
end writeToLogWDL




command writeErrorWDL pErrorString pSocketID
   local tErrorString

   if pSocketID <> empty then
      put "Socket ID:" && pSocketID & ", " into pSocketID
   end if

   if pErrorString is "401 Authorization Required" then
      put pSocketID & pErrorString & cr into tErrorString
   else
      put pSocketID & "Error:" && pErrorString & cr into tErrorString
   end if

   put tErrorString after fld "errorFld"
end writeErrorWDL
----------------------------------------------------------



command urlCallback pUrl, pStatus
   local tCurrentFileSizeSet, tAmountLoaded, tEndPos

   put (sCurrentFileSize is an integer) into tCurrentFileSizeSet

   if sProgBarInitialized is empty and tCurrentFileSizeSet is TRUE then
      -- put item 3 of pStatus into sCurrentFileSize
      put "upDownloadProgBar" into sBarName
      put false into sContacted
      put false into sAuthorizationRequested
      initializeProgress sBarName, sCurrentFileSize
   end if

   -- MOVE SCROLLBAR THUMB
   if tCurrentFileSizeSet is TRUE then
      if the label of btn "authBtn" is "Digest" then
         -- if sAuthorizationRequested is true then
         if pStatus begins with "uploading" or pStatus begins with "loading" then
            put item 2 of pStatus into tAmountLoaded
            doProgress tAmountLoaded, tProgressInterval, sBarName, sCurrentFileSize -- tProgressInterval NOT USED
         end if
         -- end if
      else
         if pStatus begins with "uploading" or pStatus begins with "loading" then
            put item 2 of pStatus into tAmountLoaded
            doProgress tAmountLoaded, tProgressInterval, sBarName, sCurrentFileSize -- tProgressInterval NOT USED
         end if
      end if
   end if

   -- WRITE STATUS
   put pStatus & cr after fld "statusFld"

   if the label of btn "authBtn" is "Digest" then
      if item 1 of pStatus is "contacted" then
         put true into sContacted
      end if
      if item 1 of pStatus is "error" and sContacted is true then
         put true into sAuthorizationRequested
      end if
   end if

   -- SET END POSITION
   if tCurrentFileSizeSet is TRUE then
      if pStatus is "downloaded" or pStatus is "uploaded" then
         put true into tEndPos
         doProgress sCurrentFileSize, tProgressInterval, sBarName, sCurrentFileSize, tEndPos -- tProgressInterval NOT USED
      end if
   end if
end urlCallback





function getSetRemovePropXMLdata pSetProps, pRemoveProps
   local thisLine,tNextProp,tPrevProp,tPropCount
   local tPropsXML,tRemovePropsXML,tSetPropsXML

   -- BUILD SET PROPERTY XML DATA
   if pSetProps is an array then

      put "-" into tKeyDelim
      put "=" into tValueDelim

      put arrayToKeyValueList(pSetProps, tKeyDelim, tValueDelim) into tProps

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

      end if -- IF PSETPROPS IS NOT EMPTY THEN

      ##
      ## BUILD REMOVE PROPERTY XML DATA
      if pRemoveProps is an array then

         put "-" into tKeyDelim
         put "=" into tValueDelim

         put arrayToKeyValueList(pRemoveProps, tKeyDelim, tValueDelim) into tRemoveProps

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
      end if -- IF PREMOVEPROPS IS AN ARRAY THEN

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
   end getSetRemovePropXMLdata





command prepareLogFields
   local tLogFld, tErrorField, tLogField, tStatusFld

   # SET TARGET FOR LOG MESSAGES
   put the long id of this stack into tLogTarget
   wdlSet "logTarget", tLogTarget

   # EMPTY FIELDS
   put empty into fld "statusFld"
   put empty into fld "logFld"
   put empty into fld "errorFld"
end prepareLogFields



private command prepareProgress pBarName pCallback
   local tCallback

   -- PREPARE PROGRESS BAR
   if pCallback is empty then
      put "urlCallback" into tCallback
   else
      put pCallback into tCallback
   end if

   if pBarName is empty then
      put "upDownloadProgBar" into sBarName
   else
      put pBarName into sBarName
   end if

   set the cursor to busy

   put empty into sProgBarInitialized
   libUrlSetStatusCallback tCallback, (the long id of this stack)
end prepareProgress



private Command getLocalFileSize pFile
   local tInfo

   if the platform is "MacOS" then
      -- put "byteSize" into tInfo
      put "dataByteSize" into tInfo
      put fileInfoMac(pFile,tInfo) into sCurrentFileSize
   else
      put getFileSize(pFile) into sCurrentFileSize
   end if
end getLocalFileSize



/*----------------------------------------------------------------------
--| COMMAND initializeProgress
--|
--| Author: rabit
--| Version:  1.1
--| Created:  2007-10-08
--| Last Mod: 2008-07-23
--| Requires:  --
--|
--| Summary: Initialize progress bar.
--|
--| Format:  initializeProgress param1, param2
--|
--| Parameters: string <pBarName>, integer <pTotalNum>
--|
--| Return: empty
----------------------------------------------------------------------*/

command initializeProgress pBarName pTotalNum
   -- SETUP PROGRESS BAR:
   set the startvalue of sb pBarName to 0
   set the endvalue of sb pBarName to pTotalNum
   set the thumbpos of sb pBarName to 0

   set the visible of scrollbar pBarName to true

   put true into sProgBarInitialized
end initializeProgress





/*----------------------------------------------------------------------
--| COMMAND hideProgress
--|
--| Author: rabit
--| Version:  1.0
--| Created:  2007-10-15
--| Last Mod: --
--| Requires: --
--|
--| Summary: Reset and hide scrollbar.
--|
--| Format:  hideProgress param1
--|
--| Parameters: string <pBarName>
--|
--| Return: empty
----------------------------------------------------------------------*/
command hideProgress pBarName
   -- if there is a image "chasing arrows.gif" then
   -- hide image "chasing arrows.gif"
   -- end if
   set the visible of scrollbar pBarName to false
   set the thumbpos of sb pBarName to 0
end hideProgress




/*----------------------------------------------------------------------
--| COMMAND doProgress
--|
--| Author: rabit
--| Version:  1.0
--| Created:  2007-10-08
--| Last Mod: --
--| Requires:  --
--|
--| Summary: Move progress thumb.
--|
--| Format:  doProgress param1, param2, param3, param4, param5
--|
--| Parameters: integer <pCurrNum>, integer <pProgressInterval>, string <pBarName>
--|             integer <pTotalNum>, bool <pEndPos>
--|
--| Return: empty
----------------------------------------------------------------------*/

command doProgress pCurrNum pProgressInterval pBarName pTotalNum pEndPos
   set cursor to busy

   if not pEndPos then
      set the thumbposition of scrollBar pBarName to pCurrNum
   else
      set the thumbposition of scrollBar pBarName to pTotalNum
      hideProgress pBarName
      set cursor to arrow
   end if
end doProgress





command clearCurrentFileSize
   put empty into sCurrentFileSize
end clearCurrentFileSize




function commonSettings pCallback
   local tRequestDataA

   put fld "hostFld" into tRequestDataA["host"]
   put fld "portFld" into tRequestDataA["port"]
   put fld "userFld" into tRequestDataA["user"]
   put fld "passwordFld" into tRequestDataA["password"]
   put the label of btn "authBtn" into tRequestDataA["authType"]
   put the hilite of btn "secureBtn" into tRequestDataA["sslFlag"]
   put the cAgent of this stack && the version && "(" & the platform &  ")" into tRequestDataA["agent"]

   if pCallback is TRUE then
      put "urlCallback" into tCallBack
      put the long id of stack "webDavTest" into tCallbackTarget
      put tCallBack into tRequestDataA["callBack"]
      put tCallbackTarget into tRequestDataA["callbackTarget"]
   end if

   return tRequestDataA
end commonSettings





----------------------------------------------
# LOCAL FILES / FOLDERS
---------------------------------------------


-- file information Mac only
--
/*----------------------------------------------------------------------
--| FUNCTION fileInfoMac
--|
--| Author: --
--| Version:  1.1
--| Created:  2007-07-04
--| Last Mod: 2020-03-23
--| Requires:  --
--|
--| Summary:  File information, Mac only.
--|
--| Format:  fileInfoMac(param1,param2)
--|
--| Parameters: <pFile, pInfo>
--|
--| Return: mixed
----------------------------------------------------------------------*/

function fileInfoMac pFile,pInfo
   local tFolder, tFiles,tFilter, tSize, tDate, tType, tCreator
   -----
   set the itemdel to slash
   put item 1 to -2 of pFile into tFolder
   put URLDecode(files(tFolder, "detailed")) into tFiles

   filter tFiles with last item of pFile & "*"
   -----
   set the itemdel to comma
   switch pInfo
      case "size"
         put item 2 of tFiles + item 3 of tFiles into tSize
         put tSize div 1024 into tSize
         if tSize > 1000 then
            set the numberFormat to "0.0"
            put tSize / 1024 && "Mb" into tSize
         else put tSize && "Kb" into tSize
         return tSize
         break
      case "byteSize"
         put item 2 of tFiles + item 3 of tFiles into tSize
         return tSize
         break
      case "dataByteSize"
         put item 2 of tFiles into tSize
         return tSize
         break
      case "creation"
         put item 4 of tFiles into tDate
         convert tDate from seconds to system date and system time
         return tDate
         break
      case "modification"
         put item 5 of tFiles into tDate
         convert tDate from seconds to system date and system time
         return tDate
         break
      case "type"
         put char -4 to -1 of item 11 of tFiles into tType
         if tType = empty then return "????"
         else return tType
         break
      case "creator"
         put char -8 to -5 of item 11 of tFiles into tCreator
         if tCreator = empty then return "????"
         else return tCreator
   end switch
end fileInfoMac




/*----------------------------------------------------------------------
--| FUNCTION getFileSize
--|
--| Author: libURL
--| Version:  1.0
--| Created:  2008-05-01
--| Last Mod: --
--| Requires:  fileInfo
--|
--| Summary:  Get size of a given file.
--|
--| Format:  getFileSize(param1)
--|
--| Parameters: <pPath>
--|
--| Return: integer
----------------------------------------------------------------------*/

function getFileSize pPath
   put fileInfo(pPath) into tInfo
   return tInfo["fileSize"]
end getFileSize






/*----------------------------------------------------------------------
--| FUNCTION fileInfo
--|
--| Author: libURL
--| Version:  1.2
--| Created:  2008-05-01
--| Last Mod: 2020-03-23
--| Requires:  pathWithoutFileName, fileNameFromPath
--|
--| Summary:  Get all available information of a given file.
--|
--| Format:  fileInfo(param1)
--|
--| Parameters: string <pFileName>
--|
--| Return: array
----------------------------------------------------------------------*/

function fileInfo pFileName
   local tFolderName, tFileName, tInfo, tFileInfoA

   put pathWithoutFileName(pFileName) into tFolderName
   put fileNameFromPath(pFileName) into tFileName

   put URLDecode(files(tFolderName, "detailed")) into tFileList

   -- get lineoffset(tFileName,tFileList)
   -- put line it of tFileList into tInfo
   filter tFileList with tFileName & "*"
   put tFileList into tInfo

   put item 1 of tInfo into tFileInfoA["fileName"]
   put item 2 of tInfo into tFileInfoA["fileSize"]
   put item 3 of tInfo into tFileInfoA["resourceSize"]
   put item 4 of tInfo into tFileInfoA["created"]
   put item 5 of tInfo into tFileInfoA["lastModified"]
   put item 6 of tInfo into tFileInfoA["lastAccessed"]
   put item 7 of tInfo into tFileInfoA["lastBackedUp"]
   put item 8 of tInfo into tFileInfoA["Owner"]
   put item 9 of tInfo into tFileInfoA["GroupOwner"]
   put item 10 of tInfo into tFileInfoA["Permissions"]
   put item 11 of tInfo into tFileInfoA["fileType"]

   return tFileInfoA
end fileInfo





----------------------------------------------
# HANDLERS TO DISPLAY AN ARRAY IN READABLE FORM
---------------------------------------------

function printArray pArrayName, pArray
   if pArray is an array then
      put pArrayname & " = {" & "<br />" into tData
      put dumpArray(pArray, " ", " ") after tData
      put "}" after tData
   end if

   return tData
end printArray



function dumpArray pArray, pIndent, pIndentString
   if pArray is an array then
      put the keys of pArray into tKeys
      sort lines of tKeys
      repeat for each line tKey in tKeys
         if pArray[tKey] is an array then
            put pIndent & tKey & " = {" & "<br />" & return after tArrayData
            put dumpArray(pArray[tKey], (pIndent & pIndentString), pIndentString) after tArrayData
            put pIndent & "}" & "<br />" & return after tArrayData
         else
            put pIndent & tKey & " = " & pArray[tKey] & "<br />" & return after tArrayData
         end if
      end repeat

      return tArrayData
   end if

   return FALSE
end dumpArray





----------------------------------
# XML HANDLERS (by Trevor DeVore)
----------------------------------

-- Following handlers provided by Trevor DeVore of Blue Mango Learning Systems.
--
-- Converts an XML tree into a LiveCode multi-dimensional array.
-- A nodes attributes will be stored as an array of it's "@attributes" key.
-- Node names will retain the sequence information (i.e. node[1], node[2], etc.).
-- This information is necessary to determine order that keys should be processed in. Example:
-- set the itemDelimiter to "["
-- put the keys of theArray into theKeys
-- sort theKeys numeric by the last item of each
--
-- pUseValueKey: The default value is false. In this case you get an array that has an @attributes
-- key for nodes that have attributes and either a) no value or b) only child nodes. Otherwise it contains the node contents.
-- Set to true if you want to store a nodes value in the '@value' key. This will allow a key to have
-- both attributes (in @attributes key) and a value (in @value key).
--
function convertXMLToArray pXML, pStoreEncodedAs, pUseValueKey
   local theArray,theResult,theRootNode,theTreeID
   local theXMLEncoding

   ## Create an XML tree from XML text
   put revCreateXMLTree(pXML, true, true, false) into theTreeID

   if theTreeID is an integer then
      ## Determine the encoding of the XML, default to UTF-8
      put matchtext(pXML, "<\?xml (.*)encoding=" & quote & "(.*)" & quote & "\?>", versionMatch, theXMLEncoding) into theResult
      if theXMLEncoding is empty then put "utf-8" into theXMLEncoding

      ## Now convert to array.
      ## The 1st dimension has one key which is the name of the root node.
      put revXMLRootNode(theTreeID) into theRootNode
      if theRootNode is not empty and not(theRootNode begins with "xmlerr,") then
         put ConvertXMLNodeToArray(theTreeID, theRootNode, theXMLEncoding, pStoreEncodedAs, pUseValueKey) into theArray[theRootNode]
      end if
   end if

   return theArray
end convertXMLToArray




function ConvertXMLTreeToArray pXMLTree, pStoreEncodedAs, pUseValueKey
   return ConvertXMLToArray(revXMLText(pXMLTree), pStoreEncodedAs, pUseValueKey)
end ConvertXMLTreeToArray


--
-- Converts a multi-dimensional array to an XML tree.
-- The array should contain one key in the 1st dimension which
-- will become the root node. Attributes of a node should be stored
-- as an array in the @attributes key. Sequence information for multiple
-- nodes with the same name should be included in the node name using
-- brackets (i.e. node[1], node[2], node[3]).
-- Returns an xml tree id (integer) or an error message.
--
function ConvertArrayToXML pArray, pArrayEncoding, pStoreEncodedAs
   local theError,theRootNode,theXML,theXMLTree

   ## if pArrayEncoding is empty then current platform encoding is assumed
   if pStoreEncodedAs is empty then put "UTF-8" into pStoreEncodedAs

   ## Create XML for root node. Note that we take extra steps in order to support
   ## converting an array that only represents part of a tree rather than the entire tree.
   ## In this case there may be multiple nodes at the root level.
   put line 1 of the keys of pArray into theRootNode
   set the itemdelimiter to "["
   put "<" & item 1 of theRootNode & "/>" into theXML

   ## Create XML needed to create tree
   put format("<?xml version=\"1.0\" encoding=\"%s\"?>%s", \
           pStoreEncodedAs, theXML) into theXML
   put revCreateXMLTree(theXML, true, true, false) into theXMLTree

   if theXMLTree is an integer then
       ## Loop over all nodes at root level
       put SortArrayKeysWithXMLOrdering(pArray) into theNodes

       ## Create tree using helper function
       repeat for each line theNode in theNodes
           ConvertArrayDimensionToXML pArray[theNode], theXMLTree, slash & theNode, \
                   pArrayEncoding, pStoreEncodedAs
           put the result into theError

           if theError is not empty then exit repeat
       end repeat

       if theError is not empty then
           ## something went wrong, clean bad tree
           revDeleteXMLTree theXMLTree
       end if
   else
       put theXMLTree into theError
   end if

   if theError is not empty then
       return theError
   else
       return theXMLTree
   end if
end ConvertArrayToXML

--
-- Helper function for ConvertArrayToXML
-- Converts the multi-dimensional array pArray to nodes in pTreeID.-- Calls itself recursively.
-- Returns error message.
--
private command ConvertArrayDimensionToXML pArray, pTreeID, pNode, pArrayEncoding, pStoreEncodedAs
   local theError,theKey,theKeys,theNode

   ## A workaround for fact that LiveCode does not return
   ## keys in the order we created them
   put SortArrayKeysWithXMLOrdering(pArray) into theNodes

   ## Arrays might have sequencing info in name
   ## (i.e. step[1], step[2], ... )
   set the itemdelimiter to "["

   repeat for each line theFullNode in theNodes
      put item 1 of theFullNode into theNode

      ## Look for attributes. These will be added as attributes to pNode.
      if theNode is "@attributes" then
         repeat for each line theKey in the keys of pArray[theFullNode]
            revSetXMLAttribute pTreeID, pNode, theKey, \
                  EncodeString(pArray[theFullNode][theKey], \
                  pArrayEncoding, pStoreEncodedAs)
            if the result begins with "xmlerr," then
               put the result && "(setting attribute" && theKey && "for node" && pNode & ")" into theError
            end if

            if theError is not empty then exit repeat
         end repeat

      else if theNode is "@value" then
         ## This XML tree is using complex structure. Node is the value of the parent node
         revPutIntoXMLNode pTreeID, pNode, EncodeString(pArray[theFullNode], pArrayEncoding, pStoreEncodedAs)
         if the result begins with "xmlerr," then
            put the result && "(adding child node" && theNode && "to node" && pNode & ")" into theError
         end if

      else
         if the keys of pArray[theFullNode] is not empty then
            ## Node has children. Add node to XML tree then call self recursivly to create children nodes.
            revAddXMLNode pTreeID, pNode, theNode, empty
            if the result begins with "xmlerr," then
               put the result && "(adding node" && theNode & ")" into theError
            end if

            if theError is empty then
               ConvertArrayDimensionToXML pArray[theFullNode], pTreeID, pNode & slash & theFullNode, \
                     pArrayEncoding, pStoreEncodedAs
               put the result into theError
            end if
         else
            ## Node has no children but possibly a value. Create node and add value (which may be empty).
            revAddXMLNode pTreeID, pNode, theNode, \
                  EncodeString(pArray[theFullNode], pArrayEncoding, pStoreEncodedAs)
            if the result begins with "xmlerr," then
               put the result && "(adding child node" && theNode && "to node" && pNode & ")" into theError
            end if
         end if
      end if

      if theError is not empty then exit repeat
   end repeat

   return theError
end ConvertArrayDimensionToXML


--
-- LiveCode array keys are never guaranteed to be in order you created
-- them in so we must come up with some other way of maintaining
-- proper sequence. For arrays representing XML, the XML syntax is
-- used (i.e. node[1], node[2], etc.). This handler will sort keys that use
-- this syntax for representing sequence.
--
function SortArrayKeysWithXMLOrdering pArray
   put the keys of pArray into theKeys
   set the itemdelimiter to "["
   sort theKeys numeric by the last item of each -- 1], 2], 3], etc.

   set the wholematches to true
   put lineoffset("@attributes", theKeys) into theLineNo
   if theLineNo > 0 then
       delete line theLineNo of theKeys
   end if

   return theKeys
end SortArrayKeysWithXMLOrdering


--
-- Helper function for ConvertXMLToArray.
-- Converts an XML node to a multi-dimensional array.-- Calls itself recursively.
--
private function ConvertXMLNodeToArray pTreeID, pNode, pXMLTreeEncoding, pStoreEncodedAs, pUseValueKey
   local theArrayA,theAttributes,theChildNode,theKey

   ## Look for attributes of the node. Store as array in "@attributes" key
   put revXMLAttributes(pTreeID, pNode, tab, cr) into theAttributes
   if theAttributes is not empty then
       put EncodeString(theAttributes, pXMLTreeEncoding, pStoreEncodedAs) into theAttributes
       split theAttributes by cr and tab -- create array
       put theAttributes into theArrayA["@attributes"]
   end if

   ## Look for children nodes.
   set the itemdelimiter to slash
   put revXMLFirstChild(pTreeID, pNode) into theChildNode
   if theChildNode is empty or theChildNode begins with "xmlerr," then
       put EncodeString(revXMLNodeContents(pTreeID, pNode), pXMLTreeEncoding, pStoreEncodedAs) into theValue
       if word 1 to -1 of theValue is empty and the keys of theArrayA is not empty then
           ## Empty node that has attributes
           return theArrayA
       else if pUseValueKey then
           ## Force value into @value
           put theValue into theArrayA["@value"]
           return theArrayA
       else
           ## Single Node with value: Return value. Attributes are ignored.
           return theValue
       end if
   else
       ## Child nodes were found. Recursively call self and store result in array.
       repeat while theChildNode is not empty and not (theChildNode begins with "xmlerr,")
           put the last item of theChildNode into theKey
           put ConvertXMLNodeToArray(pTreeID, theChildNode, pXMLTreeEncoding, pStoreEncodedAs, pUseValueKey) into theArrayA[theKey]
           put revXMLNextSibling(pTreeID, theChildNode) into theChildNode
       end repeat

       return theArrayA
   end if
end ConvertXMLNodeToArray

--
-- Helper function for converting the encoding of strings when converting to and from XML.
--
private function EncodeString pString, pInEncoding, pOutEncoding
   ## convert utf-8 to utf8 for uniencode/decode
   replace "-" with empty in pInEncoding
   replace "-" with empty in pOutEncoding

   if pInEncoding is not empty then
      -- if pOutEncoding is empty then pString will be converted to the current platform encoding
      return unidecode(uniencode(pString, pInEncoding), pOutEncoding)
   else
      if pOutEncoding is not empty then
         -- if pInEncoding is empty then pString is assumed to be in the current platform encoding
         return unidecode(uniencode(pString, pInEncoding), pOutEncoding)
      else
         return pString
      end if
   end if
end EncodeString
