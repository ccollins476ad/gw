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
#import <IOBluetooth/IOBluetooth.h>

@interface CfgCharacteristic : NSManagedObject
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSNumber *notify; 
@property (nonatomic, strong) NSNumber *readFreqSecs; 
@end

@interface CfgService : NSManagedObject
@property (nonatomic, retain) NSString *uuid;
@property (nonatomic, retain) NSSet *characteristics;
@end

@interface CfgService (CoreDataGeneratedAccessors)
- (void)addCharacteristicsObject:(CfgCharacteristic *)value;
- (void)removeCharacteristicsObject:(CfgCharacteristic *)value;
- (void)addCharacteristics:(NSSet *)values;
- (void)removeCharacteristics:(NSSet *)values;
@end

@interface CfgPeripheral : NSManagedObject
@property (nonatomic, retain) NSString *uuid;
@property (nonatomic, retain) NSNumber *stayConnected;
@property (nonatomic, retain) NSSet *services;
@end

@interface CfgPeripheral (CoreDataGeneratedAccessors)
- (void)addServicesObject:(NSManagedObject *)value;
- (void)removeServicesObject:(NSManagedObject *)value;
- (void)addServices:(NSSet *)values;
- (void)removeServices:(NSSet *)values;
@end

@interface Cfg : NSManagedObject
@property (nonatomic, retain) NSSet *peripherals;
@end

@interface Cfg (CoreDataGeneratedAccessors)
- (void)addPeripheralsObject:(CfgPeripheral *)value;
- (void)removePeripheralsObject:(CfgPeripheral *)value;
- (void)addPeripherals:(NSSet *)values;
- (void)removePeripherals:(NSSet *)values;
@end

extern Cfg* cfg;

NSError *cfgInit(void);
NSError *cfgSave(void);
