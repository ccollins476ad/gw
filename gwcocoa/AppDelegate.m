/**
 * Copyright (c) 2015 Runtime Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
//  AppDelegate.m
//  gwcocoa
//
//  Created by Christopher Collins on 10/15/15.
//  Copyright (c) 2015 Christopher Collins. All rights reserved.
//

#import <unistd.h>
#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>
#import "common/config.h"
#import "common/network.h"
#import "common/service.h"
#import "common/peripheral.h"
#import "common/characteristic.h"
#import "common/scan.h"
#import "common/persist.h"
#import "common/misc.h"
#import "common/logging.h"
#import "common/central.h"
#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSError *error;

    error = miscInit();
    if (error != nil) {
        logError(error.localizedDescription);
        /* XXX: Display error. */
        assert(0);
    }

    error = networkInit();
    if (error != nil) {
        logError(error.localizedDescription);
        /* XXX: Display error. */
        assert(0);
    }

    error = centralInit();
    if (error != nil) {
        logError(error.localizedDescription);
        /* XXX: Display error. */
        assert(0);
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

@end
