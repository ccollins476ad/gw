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

#import <Foundation/Foundation.h>
#import "peripheral.h"
#import "service.h"
#import "characteristic.h"
#import "config.h"
#import "misc.h"
#import "network.h"

NSMutableArray *networkPeripherals;

static BOOL networkStarted;

GWPeripheral *
networkFindPeripheral(NSUUID *uuid)
{
    GWPeripheral *periph;
    NSUInteger numPeriphs;
    NSUInteger i;

    numPeriphs = networkPeripherals.count;
    for (i = 0; i < numPeriphs; i++) {
        periph = [networkPeripherals objectAtIndex:i];
        if (periph.cfg != nil) {
            if ([periph.cfg.uuid isEqualToString:uuid.UUIDString]) {
                return periph;
            }
        } else if (periph.cbPeripheral != nil) {
            if ([periph.cbPeripheral.identifier.UUIDString
                    isEqualToString:uuid.UUIDString]) {

                return periph;
            }
        }
    }

    return nil;
}

void
networkStop(void)
{
    GWPeripheral *peripheral;

    if (networkStarted) {
        for (peripheral in networkPeripherals) {
            [peripheral stop];
        }
        networkStarted = FALSE;
    }
}

void
networkStart(void)
{
    if (!networkStarted) {
        networkStarted = TRUE;
        for (GWPeripheral *gwPeripheral in networkPeripherals) {
            for (GWService *gwService in gwPeripheral.services) {
                for (GWCharacteristic *gwCharacteristic in
                     gwService.characteristics) {

                    [gwCharacteristic wakeUp];
                }
            }
        }
    }
}

NSError *
networkInit(void)
{
    CfgPeripheral *cfgPeripheral;
    GWPeripheral *gwPeripheral;

    networkPeripherals = [NSMutableArray new];

    if (cfg != nil) {
        for (cfgPeripheral in cfg.peripherals) {
            gwPeripheral = [[GWPeripheral alloc] initFromCfg:cfgPeripheral];
            if (gwPeripheral == nil) {
                return miscError(1, @"Failed to construct network peripheral");
            }

            [networkPeripherals addObject:gwPeripheral];
        }
    }

    return nil;
}
