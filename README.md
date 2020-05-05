# livecode-webdavlib


WebDavLib is a LiveCode library for accessing WebDAV servers. it supports Digest and Basic authentication. WebDavLib does not depend on tsNet and can therefore be used with the Community Edition.

##### WebDavLib currently supports the following WebDAV methods:

-   OPTIONS
-   PROPFIND
-   HEAD
-   GET
-   PUT
-   DELETE
-   MKCOL
-   PROPPATCH
-   LOCK
-   UNLOCK


##### Examples of tasks the library allows to accomplish:

-   Generate a list of all WebDAV methods provided by the server
-   Get the file size, modification date, content type etc. of a remote file
-   Download a file
-   Check write permission of a directory
-   Upload a file
-   Delete a file / folder
-   List files / folders
-   Create a folder
-   Set custom file properties
-   Get custom file properties
-   Remove custom file properties
-   Lock a file (may be not supported on NextCloud servers)
-   Check if a file is locked
-   Unlock a file (may be not supported on NextCloud servers)

WebDavLib is tested on a commercial NextCloud server, on a private NextCloud server and on a local WebDAV server.


### Getting Started

Check out the enclosed sample stack "webDavTest". Fill out the form and execute the request handler by choosing a method from the option menu (top to bottom) and clicking on "Request".


### Usage

Basically the procedure to send a WebDAV request involves:

-   Setting up the request data using an array
-   Storing the request data in WebDavLib which returns a request ID
-   Sending the request to the server to receive a response

Following is an example (returning the WebDAV methods the server supports):

```
-- SETUP REQUEST DATA
put fld "hostFld" into tRequestDataA["host"]
put fld "portFld" into tRequestDataA["port"]
put fld "userFld" into tRequestDataA["user"]
put fld "passwordFld" into tRequestDataA["password"]
put the label of btn "authBtn" into tRequestDataA["authType"]
put the hilite of btn "secureBtn" into tRequestDataA["sslFlag"]
put the cAgent of this stack && the version && "(" & the platform &  ")" into tRequestDataA["agent"]
put fld "davDirFld" into tRequestDataA["uri"]

-- STORE REQUEST DATA IN LIBRARY, GET REQUEST ID
wdlSetupNewRequest tRequestDataA
put the result into tReqID

-- SEND REQUEST TO SERVER
put wdlGetserverMethods(tReqID) into tServerResponse

wdlCleanup tReqID
```

These are the request data array keys used depending on the particular request method:

-   host (the host address like: myname.ocloud.de)
-   uri (the path to the WebDAV directory like: /remote.php/webdav/)
-   port (as a general rule this is 80 or 443 for secure connections)
-   user
-   password (user password or app password)
-   authType (Basic or Digest)
-   sslFlag (a boolean, TRUE for a secure connection)
-   method (see the WebDav methods above)
-   agent (User-agent)
-   propertiesXML (the properties XML data inserted into a XML request body)
-   contentType (Content-type like application/xml; charset="utf-8")
-   contentLength
-   dataToUpload (the binary file data to upload)
-   nameSpace (WebDAV XML namespace like "http://www.w3.com/standards/z39.50/")
-   lockScope (exclusive or shared)
-   lockType (write)
-   lockOwner (any name)
-   lockToken (the cCurrentLockToken of stack "WebDavLib")
-   callBack (the name of a callback handler used by methods GET and PUT)
-   callbackTarget (the long ID of the object containing the callback handler)


Following are the available public handlers:

-   wdlSetupNewRequest tRequestDataA
-   wdlGetserverMethods(tReqID)
-   wdlGetFile(tReqID)
-   wdlWritePermission(tReqID)
-   wdlDeleteFileFolder(tReqID)
-   wdlPutFile(tReqID)
-   wdlGetFileList(tReqID)
-   wdlCreateFolder(tReqID)
-   wdlSetFileProps(tReqID, tSetPropsA, tRemovePropsA)
-   wdlGetFileProps(tReqID, tProps)
-   wdlGetCustomProps(tReqID, tProps)
-   wdlLock(tReqID)
-   wdlUnlock(tReqID)
-   wdlGetFileHeaders(tReqID)
-   wdlCleanup tReqID


**NOTE:** Be aware that if you use the LC Indy Edition or the LC Business Edition WebDavLib does not work if the tsNet external is loaded. So, to use the WebDavLib library you need to unload tsNetLibURL like:

```
if the environment is "development" and there is a stack "tsNetLibURL" then
    dispatch "revUnloadLibrary" to stack "tsNetLibURL"
end if
```

See button "requestBtn" in the enclosed sample stack.


### Meta

-   Version: 1.0.0
-   Author:  [Ralf Bitter](mailto:rabit@revigniter.com)
