/*
 PicBrowserController.m
 NSObject subclass showing the use of NSNetServices to discover a lightweight thumbnail sharing service on the network.

 Chris Parker
 with additional changes from Marc Krochmal (DTS)

 Copyright (c) 2002, Apple Computer, Inc., all rights reserved.
 */

/*
 IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
 consideration of your agreement to the following terms, and your use, installation,
 modification or redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and subject to these
 terms, Apple grants you a personal, non-exclusive license, under Apple’s copyrights in
 this original Apple software (the "Apple Software"), to use, reproduce, modify and
 redistribute the Apple Software, with or without modifications, in source and/or binary
 forms; provided that if you redistribute the Apple Software in its entirety and without
 modifications, you must retain this notice and the following text and disclaimers in all
 such redistributions of the Apple Software.  Neither the name, trademarks, service marks
 or logos of Apple Computer, Inc. may be used to endorse or promote products derived from
 the Apple Software without specific prior written permission from Apple. Except as expressly
 stated in this notice, no other rights or licenses, express or implied, are granted by Apple
 herein, including but not limited to any patent rights that may be infringed by your
 derivative works or by other works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES,
 EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS
 USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
          OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE,
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND
 WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
 OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "PicBrowserController.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

@implementation PicBrowserController

- (IBAction)serviceClicked:(id)sender {
    // The row that was clicked corresponds to the object in services we wish to contact.
    int index = [sender selectedRow];
    
    // Make sure to cancel any previous resolves.
    if (serviceBeingResolved) {
        [serviceBeingResolved stop];
        [serviceBeingResolved release];
        serviceBeingResolved = nil;
    }
    
    [imageView setImage:nil];
    
    if(-1 == index) {
        [ipAddressField setStringValue:@""];
        [portField setStringValue:@""];
    } else {        
        serviceBeingResolved = [services objectAtIndex:index];
        [serviceBeingResolved retain];
        [serviceBeingResolved setDelegate:self];
        [serviceBeingResolved resolve];
    }
}


- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    if ([[sender addresses] count] > 0) {
        NSData * address;
        struct sockaddr * socketAddress;
        NSString * ipAddressString = nil;
        NSString * portString = nil;
        int socketToRemoteServer;
        char buffer[256];
        int index;
        
        // Iterate through addresses until we find an IPv4 address
        for (index = 0; index < [[sender addresses] count]; index++) {
            address = [[sender addresses] objectAtIndex:index];
            socketAddress = (struct sockaddr *)[address bytes];
            
            if (socketAddress->sa_len == sizeof(struct sockaddr_in))
                break;
        }
        
        if (socketAddress) {
            switch(socketAddress->sa_len) {
                case sizeof(struct sockaddr_in):
                    if (inet_ntop(AF_INET, &((struct sockaddr_in *)socketAddress)->sin_addr, buffer, sizeof(buffer)))
                        ipAddressString = [NSString stringWithCString:buffer];
                    portString = [NSString stringWithFormat:@"%d", ntohs(((struct sockaddr_in *)socketAddress)->sin_port)];
                    
                    // Cancel the resolve now that we have an IPv4 address.
                    [sender stop];
                    [sender release];
                    serviceBeingResolved = nil;
                    
                    break;
                case sizeof(struct sockaddr_in6):
                    // PictureSharing server doesn't support IPv6
                    return;
            }
        }   
             
        if (ipAddressString)
            [ipAddressField setStringValue:ipAddressString];
        
        if (portString)
            [portField setStringValue:portString];

        socketToRemoteServer = socket(AF_INET, SOCK_STREAM, 0);
        if(socketToRemoteServer > 0) {
            NSFileHandle * remoteConnection = [[NSFileHandle alloc] initWithFileDescriptor:socketToRemoteServer closeOnDealloc:YES];
            if(remoteConnection) {
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readAllTheData:) name:NSFileHandleReadToEndOfFileCompletionNotification object:remoteConnection];
                if(connect(socketToRemoteServer, (struct sockaddr *)socketAddress, sizeof(*socketAddress)) == 0) {
                [remoteConnection readToEndOfFileInBackgroundAndNotify];
                }
            } else {
                close(socketToRemoteServer);
            }
        }
    }
}


- (void)readAllTheData:(NSNotification *)aNotification {
    NSImage * theImage = [[NSImage alloc] initWithData:[[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem]];
    [imageView setImage:theImage];
    [theImage release];
}


- (void)awakeFromNib {
    browser = [[NSNetServiceBrowser alloc] init];
    services = [[NSMutableArray array] retain];
    [browser setDelegate:self];
    
    // Passing in "" for the domain causes us to browse in the default browse domain, which currently will always be the ".local" domain.
    [browser searchForServicesOfType:@"_wwdcpic._tcp." inDomain:@""];
    [ipAddressField setStringValue:@""];
    [portField setStringValue:@""];
}


// This object is the delegate of its NSNetServiceBrowser object. We're only interested in services-related methods, so that's what we'll call.
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    [services addObject:aNetService];

    if(!moreComing) {
        [pictureServiceList reloadData];
    }
}


- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    // This case is slightly more complicated. We need to find the object in the list and remove it.
    NSEnumerator * enumerator = [services objectEnumerator];
    NSNetService * currentNetService;

    while(currentNetService = [enumerator nextObject]) {
        if ([currentNetService isEqual:aNetService]) {
            [services removeObject:currentNetService];
            break;
        }
    }
    
    if (serviceBeingResolved && [serviceBeingResolved isEqual:aNetService]) {
        [serviceBeingResolved stop];
        [serviceBeingResolved release];
        serviceBeingResolved = nil;
    }

    if(!moreComing) {
        [pictureServiceList reloadData];        
    }
}


// This object is the data source of its NSTableView. servicesList is the NSArray containing all those services that have been discovered.
- (int)numberOfRowsInTableView:(NSTableView *)theTableView {
    return [services count];
}


- (id)tableView:(NSTableView *)theTableView objectValueForTableColumn:(NSTableColumn *)theColumn row:(int)rowIndex {
    return [[services objectAtIndex:rowIndex] name];
}
@end
