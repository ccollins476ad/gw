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

#import <ctype.h>
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "misc.h"
#import "logging.h"
#import "config.h"

Cfg *cfg;

static NSManagedObjectModel *configMom;
static NSManagedObjectContext *configMoc;
static NSPersistentStoreCoordinator *configPsc;
static NSEntityDescription *configEntityPeripheral;
static NSEntityDescription *configEntityService;
static NSEntityDescription *configEntityCharacteristic;
static NSEntityDescription *configEntityCfg;

@implementation CfgCharacteristic
@dynamic uuid;
@dynamic notify;
@dynamic readFreqSecs;

- (id)
init
{
    self = [super      initWithEntity:configEntityCharacteristic
       insertIntoManagedObjectContext:configMoc]; 

    return self;
}

@end

@implementation CfgService
@dynamic uuid;
@dynamic characteristics;

- (id)
init
{
    self = [super      initWithEntity:configEntityService
       insertIntoManagedObjectContext:configMoc]; 

    return self;
}

@end

@implementation CfgPeripheral
@dynamic uuid;
@dynamic stayConnected;
@dynamic services;

- (id)
init
{
    self = [super      initWithEntity:configEntityPeripheral
       insertIntoManagedObjectContext:configMoc]; 

    return self;
}

@end

@implementation Cfg
@dynamic peripherals;

- (id)
init
{
    self = [super      initWithEntity:configEntityCfg
       insertIntoManagedObjectContext:configMoc]; 

    return self;
}

@end


static NSError *
configInitMom(void)
{
    NSURL *url;

    url = [[NSBundle mainBundle] URLForResource:@"configuration"
                                  withExtension:@"momd"];
    if (url == nil) {
        return miscError(1, @"Could not construct configuration URL");
    }

    configMom = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];

    return nil;
}

static NSError *
configInitPsc(void)
{
    NSPersistentStore *store;
    NSError *error;
    NSURL *url;

    assert(configMom != nil);

    url = [miscGwUrl URLByAppendingPathComponent:@"configuration.xml"];
    if (url == nil) {
        return miscError(1, @"Could not append configuration URL component");
    }

    configPsc = [[NSPersistentStoreCoordinator alloc]
                    initWithManagedObjectModel:configMom];

    store = [configPsc addPersistentStoreWithType:NSXMLStoreType
                                    configuration:nil
                                              URL:url
                                          options:nil
                                            error:&error];
    if (store == nil) {
        return error;
    }

    return nil;
}

static void
configInitMoc(void)
{
    assert(configPsc != nil);

    configMoc = [[NSManagedObjectContext alloc] init];
    [configMoc setPersistentStoreCoordinator:configPsc];
}

static NSError *
configInitEntities(void)
{
    assert(configMoc != nil);

    configEntityCfg = [NSEntityDescription entityForName:@"Cfg"
                                  inManagedObjectContext:configMoc];
    if (configEntityCfg == nil) {
        return miscError(1, @"Failed to load cfg config entity");
    }

    configEntityPeripheral =
        [NSEntityDescription entityForName:@"CfgPeripheral"
                    inManagedObjectContext:configMoc];
    if (configEntityPeripheral == nil) {
        return miscError(1, @"Failed to load peripheral config entity");
    }

    configEntityService = [NSEntityDescription entityForName:@"CfgService"
                                       inManagedObjectContext:configMoc];
    if (configEntityService == nil) {
        return miscError(1, @"Failed to load service config entity");
    }

    configEntityCharacteristic =
        [NSEntityDescription entityForName:@"CfgCharacteristic"
                    inManagedObjectContext:configMoc];
    if (configEntityCharacteristic == nil) {
        return miscError(1, @"Failed to load characteristic config entity");
    }

    return nil;
}

#if 0
static void
tempfakecfg(void)
{
    CfgCharacteristic *ch;
    CfgService *se;
    CfgPeripheral *pe;

    ch = [CfgCharacteristic new];
    ch.uuid = @"2A19";
    ch.notify = @0;
    ch.readFreqSecs = @60;

    se = [CfgService new];
    se.uuid = @"180F";
    [se addCharacteristicsObject:ch];

    pe = [CfgPeripheral new];
    pe.uuid = @"6974A8E5-808A-4A2A-9943-A31394B7C374";
    pe.stayConnected = @1;
    [pe addServicesObject:se];

    [cfg addPeripheralsObject:pe];
}
#endif

static Cfg *
configFetchCfg(void)
{
    NSFetchRequest *request;
    NSArray *results;
    NSError *error;

    request = [NSFetchRequest fetchRequestWithEntityName:@"Cfg"];
    results = [configMoc executeFetchRequest:request error:&error];
    if (results == nil) {
        logError(@"Error fetching configuration: %@\n%@",
                 error.localizedDescription, error.userInfo);
        return nil;
    }

    if (results.count > 1) {
        logError(@"Error fetching configureation: multiple objects returned");
        return nil;
    }

    return results.firstObject;
#if 0
    cfg = [Cfg new];
    tempfakecfg();
    return cfg;
#endif
}

NSSet *
cfgPeripherals(void)
{
    return cfg.peripherals;
}

static bool
cfgNsUuidIsValid(NSString *str)
{
    return [[NSUUID alloc] initWithUUIDString:str] != nil;
}

static bool
cfgCbUuidIsValid(NSString *str)
{
    char ch;
    int i;

    /* Check for a 128-bit UUID. */
    if (cfgNsUuidIsValid(str)) {
        return TRUE;
    }

    /* Check for a 16-bit UUID. */
    str = [str stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];

    if (str.length != 4) {
        return FALSE;
    }

    for (i = 0; i < 4; i++) {
        ch = tolower([str characterAtIndex:i]);
        if (!((ch >= '0' && ch <= '9') ||
              ch == 'a' ||
              ch == 'b' ||
              ch == 'c' ||
              ch == 'd' ||
              ch == 'e' ||
              ch == 'f')) {

            return FALSE;
        }
    }

    return TRUE;
}

static NSError *
cfgValidate(void)
{
    CfgCharacteristic *characteristic;
    CfgPeripheral *peripheral;
    CfgService *service;

    for (peripheral in cfg.peripherals) {
        if (!cfgNsUuidIsValid(peripheral.uuid)) {
            return miscError(1, @"configuration contains invalid peripheral "
                                 "UUID: %@", peripheral.uuid);
        }

        for (service in peripheral.services) {
            if (!cfgCbUuidIsValid(service.uuid)) {
                return miscError(1, @"configuration contains invalid service "
                                     "UUID: %@", service.uuid);
            }

            for (characteristic in service.characteristics) {
                if (!cfgCbUuidIsValid(characteristic.uuid)) {
                    return miscError(1, @"configuration contains invalid "
                                         "characteristic UUID: %@",
                                         characteristic.uuid);
                }
            }
        }
    }

    return nil;
}

NSError *
cfgSave(void)
{
    NSError *error;
    BOOL rc;

    rc = [configMoc save:&error];
    if (rc == NO) {
        logError(@"Error saving configuration: %@",
                 error.localizedDescription);
        return error;
    }

    return nil;
}

NSError *
cfgInit(void)
{
    NSError *error;
    BOOL rc;

    error = configInitMom();
    if (error != nil) {
        return error;
    }

    error = configInitPsc();
    if (error != nil) {
        return error;
    }

    configInitMoc();

    error = configInitEntities();
    if (error != nil) {
        return error;
    }

    cfg = configFetchCfg();
    if (cfg == nil) {
        cfg = [Cfg new];
        error = cfgSave();
        if (error != nil) {
            logError(@"Error saving configuration: %@",
                     error.localizedDescription);
            return error;
        }
    }

    error = cfgValidate();
    if (error != nil) {
        return error;
    }

    return nil;
}
