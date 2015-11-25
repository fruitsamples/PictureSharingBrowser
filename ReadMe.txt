### PictureSharingBrowser ###

===========================================================================
DESCRIPTION:

This sample demonstrates how to use NSNetServices to take advantage of Bonjour service discovery and name resolution on Mac OS X.  When used in conjunction with the PictureSharing sample, this sample shows how to browse for services being advertised by PictureSharing servers, and then shows how to connect and download the picture being shared.

===========================================================================
BUILD REQUIREMENTS:

Xcode 3.2 or later

===========================================================================
RUNTIME REQUIREMENTS:

Mac OS X v10.6 or later

===========================================================================
PACKAGING LIST:

PicBrowserController.h,m
NSObject subclass showing the use of NSNetServices to discover a lightweight thumbnail sharing service on the network.

===========================================================================
CHANGES FROM PREVIOUS VERSIONS:

Version 1.2
- Base SDK changed to 10.6

Version 1.1
- Upgraded project to use native Xcode target and fixed socket leak by releasing the NSFileHandle when file transfer is finshed.

Version 1.0
- First release

===========================================================================
Copyright (C) 2003-2009 Apple Inc. All rights reserved.
