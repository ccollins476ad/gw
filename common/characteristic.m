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
#import "persist.h"
#import "peripheral.h"
#import "service.h"
#import "characteristic.h"
#import "logging.h"

@interface GWCharacteristic (private)

- (void) restartTimer;
- (void) readTimerExp:(NSTimer *)timer;
- (void) read;

@end

@implementation GWCharacteristic
@synthesize cfg = _cfg;
@synthesize cbCharacteristic = _cbCharacteristic;
@synthesize state = _state;
@synthesize peripheral = _peripheral;
@synthesize service = _service;

- (id)
initFromCfg:(CfgCharacteristic *)cfgCharacteristic
 peripheral:(GWPeripheral *)gwPeripheral
    service:(GWService *)gwService
{
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _cfg = cfgCharacteristic;
    _cbCharacteristic = nil;
    _peripheral = gwPeripheral;
    _service = gwService;
    _state = GWCharacteristicStatePending;

    return self;
}

- (void)
wakeUp
{
    logDebug(@"Characteristic.wakeUp(); state=%d", (int)_state);
    switch (_state) {
    case GWCharacteristicStateSleep:
        [self restartTimer];
        break;

    case GWCharacteristicStatePending:
        if (_cbCharacteristic != nil) {
            [self read];
        } else {
            [_peripheral prepareForRead];
        }
        break;

    case GWCharacteristicStateSent:
        break;

    default:
        assert(0);
        break;
    }
}

- (void)
read
{
    logDebug(@"Characteristic.read()");

    assert(_state == GWCharacteristicStatePending);
    assert(_cbCharacteristic != nil);

    [_peripheral.cbPeripheral
        readValueForCharacteristic:self.cbCharacteristic];

    _state = GWCharacteristicStateSent;

    if (_cfg.notify && !_cbCharacteristic.isNotifying) {
        [_peripheral.cbPeripheral setNotifyValue:TRUE
                               forCharacteristic:_cbCharacteristic];
    }
}

- (void)
reset
{
    if (_state == GWCharacteristicStateSent) {
        logDebug(@"Aborting read of characteristic %@", _cfg.uuid);
        _state = GWCharacteristicStatePending;
    }

    _cbCharacteristic = nil;

    if (_state == GWCharacteristicStateSleep && _readTimer == nil) {
        [self restartTimer];
    }
}

- (void)
stop
{
    if (_readTimer != nil) {
        [_readTimer invalidate];
        _readTimer = nil;
    }
}

- (void)
restartTimer
{
    logDebug(@"Characteristic.restartTimer()");

    assert(_state == GWCharacteristicStateSleep);

    if (_readTimer != nil) {
        [_readTimer invalidate];
    }
    _readTimer =
        [NSTimer scheduledTimerWithTimeInterval:[_cfg.readFreqSecs doubleValue]
                                         target:self
                                       selector:@selector(readTimerExp:)
                                       userInfo:nil
                                        repeats:NO];
}

- (void)
readTimerExp:(NSTimer *)timer
{
    logDebug(@"Characteristic.readTimerExp()");

    assert(_state == GWCharacteristicStateSleep);

    _state = GWCharacteristicStatePending;
    [self wakeUp];
}

- (void)
onReadSuccess
{
    logInfo(@"Characteristic successfully read; uuid=%@ data=%@",
            _cfg.uuid, _cbCharacteristic.value);
    if (_state == GWCharacteristicStateSent) {
        _state = GWCharacteristicStateSleep;
    }

    persistSaveMessage(self, _cbCharacteristic.value);

    [_peripheral readComplete];

    [self restartTimer];
}

- (void)
onReadFailureWithError:(NSError *)error
{
    if (_state == GWCharacteristicStateSent) {
        _state = GWCharacteristicStateSleep;
        logNotice(@"Failed to read characteristic; uuid=%@ "
                   "peripheral=%@ error=%@", _cfg.uuid, _peripheral, error);
    }

    /* XXX: Retry? */
    [_peripheral readComplete];

    [self restartTimer];
}
@end
