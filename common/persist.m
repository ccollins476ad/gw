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
#import <CoreData/CoreData.h>
#import "peripheral.h"
#import "service.h"
#import "characteristic.h"
#import "misc.h"
#import "logging.h"
#import "persist.h"

static NSManagedObject *persistSavePeripheral(GWPeripheral *peripheral);
static NSManagedObject *persistSaveService(GWService *service);
static NSManagedObject *
persistSaveCharacteristic(GWCharacteristic *characteristic);

static NSManagedObjectModel *persistMom;
static NSManagedObjectContext *persistMoc;
static NSPersistentStoreCoordinator *persistPsc;
static NSEntityDescription *persistEntityPeripheral;
static NSEntityDescription *persistEntityService;
static NSEntityDescription *persistEntityCharacteristic;
static NSEntityDescription *persistEntityMessage;

static NSError *
persistCommit(void)
{
    NSError *error;
    BOOL rc;

    rc = [persistMoc save:&error];
    if (rc == NO) {
        return error;
    } else {
        return nil;
    }
}

static NSManagedObject *
persistFetchPeripheral(GWPeripheral *peripheral)
{
    NSFetchRequest *request;
    NSArray *results;
    NSError *error;

    request = [NSFetchRequest fetchRequestWithEntityName:@"PersistPeripheral"];
    [request setPredicate:
        [NSPredicate predicateWithFormat:@"uuid == %@", peripheral.cfg.uuid]]; 

    results = [persistMoc executeFetchRequest:request error:&error];
    if (results == nil) {
        logError(@"Error fetching peripheral with uuid %@: %@\n%@",
                 peripheral.cfg.uuid, error.localizedDescription,
                 error.userInfo);
        return nil;
    } 

    if (results.count > 1) {
        logError(@"Error fetching peripheral with uuid %@: multiple objects "
                  "returned",
                 peripheral.cfg.uuid);
        return nil;
    }

    return results.firstObject;
}

static NSManagedObject *
persistSavePeripheral(GWPeripheral *peripheral)
{
    NSManagedObject *moPeripheral;

    moPeripheral = [[NSManagedObject alloc]
                        initWithEntity:persistEntityPeripheral
        insertIntoManagedObjectContext:persistMoc]; 

    [moPeripheral setValue:peripheral.cfg.uuid forKey:@"uuid"];

    return moPeripheral;
}

static NSManagedObject *
persistFetchService(GWService *service)
{
    NSFetchRequest *request;
    NSArray *results;
    NSError *error;

    request = [NSFetchRequest fetchRequestWithEntityName:@"PersistService"];
    [request setPredicate:
        [NSPredicate predicateWithFormat:@"uuid == %@", service.cfg.uuid]]; 
    [request setPredicate:
        [NSPredicate
            predicateWithFormat:@"peripheral.uuid == %@",
                                service.peripheral.cfg.uuid]];

    results = [persistMoc executeFetchRequest:request error:&error];
    if (results == nil) {
        logError(@"Error fetching service with uuid %@: %@\n%@",
                 service.cfg.uuid, error.localizedDescription, error.userInfo);
        return nil;
    } 

    if (results.count > 1) {
        logError(@"Error fetching service with uuid %@: multiple objects "
                  "returned", service.cfg.uuid);
        return nil;
    }

    return results.firstObject;
}

static NSManagedObject *
persistSaveService(GWService *service)
{
    NSManagedObject *moPeripheral;
    NSManagedObject *moService;

    moPeripheral = persistFetchPeripheral(service.peripheral);
    if (moPeripheral == nil) {
        moPeripheral = persistSavePeripheral(service.peripheral);
    }

    moService = [[NSManagedObject alloc]
                        initWithEntity:persistEntityService
        insertIntoManagedObjectContext:persistMoc]; 

    [moService setValue:service.cfg.uuid forKey:@"uuid"];
    [moService setValue:moPeripheral     forKey:@"peripheral"];

    return moService;
}

static NSManagedObject *
persistFetchCharacteristic(GWCharacteristic *characteristic)
{
    NSFetchRequest *request;
    NSArray *results;
    NSError *error;

    request =
        [NSFetchRequest fetchRequestWithEntityName:@"PersistCharacteristic"];
    [request setPredicate:
        [NSPredicate predicateWithFormat:@"uuid == %@",
                     characteristic.cfg.uuid]];
    [request setPredicate:
        [NSPredicate
            predicateWithFormat:@"service.uuid == %@",
                                characteristic.service.cfg.uuid]];

    results = [persistMoc executeFetchRequest:request error:&error];
    if (results == nil) {
        logError(@"Error fetching characteristic with uuid %@: %@\n%@",
                 characteristic.cfg.uuid, error.localizedDescription,
                 error.userInfo);
        return nil;
    } 

    if (results.count > 1) {
        logError(@"Error fetching characteristic with uuid %@: multiple "
                  "objects returned", characteristic.cfg.uuid);
        return nil;
    }

    return results.firstObject;
}

static NSManagedObject *
persistSaveCharacteristic(GWCharacteristic *characteristic)
{
    NSManagedObject *moCharacteristic;
    NSManagedObject *moService;

    moService = persistFetchService(characteristic.service);
    if (moService == nil) {
        moService = persistSaveService(characteristic.service);
    }

    moCharacteristic = [[NSManagedObject alloc]
                        initWithEntity:persistEntityCharacteristic
        insertIntoManagedObjectContext:persistMoc]; 

    [moCharacteristic setValue:characteristic.cfg.uuid
                        forKey:@"uuid"];
    [moCharacteristic setValue:moService
                        forKey:@"service"];

    return moCharacteristic;
}

void
persistSaveMessage(GWCharacteristic *characteristic, NSData *data)
{
    NSManagedObject *moCharacteristic;
    NSManagedObject *moMessage;
    NSError *error;

    moCharacteristic = persistFetchCharacteristic(characteristic);
    if (moCharacteristic == nil) {
        moCharacteristic = persistSaveCharacteristic(characteristic);
    }

    moMessage = [[NSManagedObject alloc]
                        initWithEntity:persistEntityMessage
        insertIntoManagedObjectContext:persistMoc]; 

    [moMessage setValue:moCharacteristic forKey:@"characteristic"];
    [moMessage setValue:[NSDate date] forKey:@"date"];
    [moMessage setValue:data forKey:@"data"];

    error = persistCommit();
    if (error != nil) {
        logError(@"Error committing data: %@", error.localizedDescription);
    }
}

static NSError *
persistInitMom(void)
{
    NSURL *url;

    url = [[NSBundle mainBundle] URLForResource:@"persistence"
                                  withExtension:@"momd"];
    if (url == nil) {
        return miscError(1, @"Could not construct persistence URL");
    }

    persistMom = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];

    return nil;
}

static NSError *
persistInitPsc(void)
{
    NSPersistentStore *store;
    NSError *error;
    NSURL *url;

    assert(persistMom != nil);

    url = [miscGwUrl URLByAppendingPathComponent:@"persistence.xml"];
    if (url == nil) {
        return miscError(1, @"Could not append persistence URL component");
    }

    persistPsc = [[NSPersistentStoreCoordinator alloc]
                    initWithManagedObjectModel:persistMom];

    store = [persistPsc addPersistentStoreWithType:NSXMLStoreType
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
persistInitMoc(void)
{
    assert(persistPsc != nil);

    persistMoc = [[NSManagedObjectContext alloc] init];
    [persistMoc setPersistentStoreCoordinator:persistPsc];
}

static NSError *
persistInitEntities(void)
{
    assert(persistMoc != nil);

    persistEntityPeripheral =
        [NSEntityDescription entityForName:@"PersistPeripheral"
                    inManagedObjectContext:persistMoc];
    if (persistEntityPeripheral == nil) {
        return miscError(1, @"Failed to load peripheral persist entity");
    }

    persistEntityService = [NSEntityDescription entityForName:@"PersistService"
                                       inManagedObjectContext:persistMoc];
    if (persistEntityService == nil) {
        return miscError(1, @"Failed to load service persist entity");
    }

    persistEntityCharacteristic =
        [NSEntityDescription entityForName:@"PersistCharacteristic"
                    inManagedObjectContext:persistMoc];
    if (persistEntityCharacteristic == nil) {
        return miscError(1, @"Failed to load characteristic persist entity");
    }

    persistEntityMessage = [NSEntityDescription entityForName:@"PersistMessage"
                                       inManagedObjectContext:persistMoc];
    if (persistEntityMessage == nil) {
        return miscError(1, @"Failed to load message persist entity");
    }

    return nil;
}

NSError *
persistInit(void)
{
    NSError *error;

    error = persistInitMom();
    if (error != nil) {
        return error;
    }

    error = persistInitPsc();
    if (error != nil) {
        return error;
    }

    persistInitMoc();

    error = persistInitEntities();
    if (error != nil) {
        return error;
    }

    return nil;
}
