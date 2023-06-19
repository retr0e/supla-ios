/*
 Copyright (C) AC SOFTWARE SP. Z O.O.
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import <CoreData/CoreData.h>

#import "Database.h"
#import "SuplaApp.h"
#import "_SALocation+CoreDataClass.h"
#import "SAChannel+CoreDataClass.h"
#import "SAChannelGroupRelation+CoreDataClass.h"
#import "SAColorListItem+CoreDataClass.h"
#import "SAUserIcon+CoreDataClass.h"
#import "SUPLA-Swift.h"

@interface SADatabase ()
@end

@implementation SADatabase {
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
    NSManagedObjectContext *_managedObjectContext;
}

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"SUPLA" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (void)removeIfExists:(NSString *)dbFileName {
    NSURL *storeURL = [[SAApp applicationDocumentsDirectory] URLByAppendingPathComponent:dbFileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[storeURL path]]) {
        NSError *error = nil;
        [fileManager removeItemAtURL:storeURL error:&error];
    }
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it.
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSError *error = nil;
    NSDictionary *opts = nil;
    NSURL *storeURL = [[SAApp applicationDocumentsDirectory] URLByAppendingPathComponent:@"SUPLA_DB14.sqlite"];
    
#ifdef DEBUG
    NSLog(@"Database path: %@", storeURL.absoluteString);
#endif
    
    // Create the coordinator and store
again:
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil URL:storeURL
                                                         options:opts error:&error]) {
        // Migration allowed only in CoreDataManager.swift file
        abort();
    }
    
    return _persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    [_managedObjectContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
    return _managedObjectContext;
}


- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
 
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (void)initSaveObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managedObjectContextDidSaveNotification:) name:NSManagedObjectContextDidSaveNotification object:nil];
}

- (void)releaseSaveObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
}

- (void)managedObjectContextDidSaveNotification:(NSNotification *)n {
    
    if ( _managedObjectContext
        && _managedObjectContext != n.object ) {
        [_managedObjectContext performSelectorOnMainThread:@selector(mergeChangesFromContextDidSaveNotification:) withObject:n waitUntilDone:NO];
    };
    
}

-(NSArray *) fetchByPredicate:(NSPredicate *)predicate entityName:(NSString*)en limit:(int)l sortDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors {
    
    NSSet *entitiesWithProfile = [
        NSSet setWithObjects:
            @"SALocation", @"SAChannel", @"SAChannelValue",
            @"SAChannelExtendedValue", @"SAChannelGroup",
            @"SAElectricityMeasurementItem", @"SAImpulseCounterMeasurementItem",
            @"SATemperatureMeasurementItem", @"SATempHumidityMeasurementItem",
            @"SAThermostatMeasurementItem", @"SAScene", @"SAChannelGroupRelation",
            @"SAUserIcon", @"SAColorListItem", nil
    ];
    
    NSMutableArray *predicateArray = [NSMutableArray array];
    [predicateArray addObject:predicate];
    
    if ([entitiesWithProfile containsObject: en]) {
        AuthProfileItem *profile = self.currentProfile;
        if (profile == nil) {
            [predicateArray addObject:[NSPredicate predicateWithFormat:@"profile.isActive = true"]];
        } else {
            [predicateArray addObject:[NSPredicate predicateWithFormat:@"profile = %@", profile]];
        }
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates: predicateArray];;
  
    fetchRequest.sortDescriptors = sortDescriptors;
    
    if ( l > 0 ) {
        [fetchRequest setFetchLimit:l];
    }
    
    [fetchRequest setEntity:[NSEntityDescription entityForName:en inManagedObjectContext: self.managedObjectContext]];
    NSError *error = nil;
    NSArray *r = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    if ( error == nil && r.count > 0 ) {
        return r;
    }
    
    return nil;
};

-(NSArray *) fetchByPredicate:(NSPredicate *)predicate entityName:(NSString*)en limit:(int)l {
    return [self fetchByPredicate:predicate entityName:en limit:l sortDescriptors:nil];
}

-(id) fetchItemByPredicate:(NSPredicate *)predicate entityName:(NSString*)en sortDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors {
    
    NSArray *r = [self fetchByPredicate:predicate entityName:en limit:1 sortDescriptors:sortDescriptors];
    if ( r != nil && r.count > 0 ) {
        return [r objectAtIndex:0];
    }
    
    return nil;
};

-(id) fetchItemByPredicate:(NSPredicate *)predicate entityName:(NSString*)en {
    return [self fetchItemByPredicate:predicate entityName:en sortDescriptors:nil];
}

-(NSUInteger) getCountByPredicate:(NSPredicate *)predicate entityName:(NSString *)en {
    NSSet *entitiesWithProfile = [
        NSSet setWithObjects:
            @"SALocation", @"SAChannel", @"SAChannelValue",
            @"SAChannelExtendedValue", @"SAChannelGroup",
            @"SAElectricityMeasurementItem", @"SAImpulseCounterMeasurementItem",
            @"SATemperatureMeasurementItem", @"SATempHumidityMeasurementItem",
            @"SAThermostatMeasurementItem", @"SAScene", @"SAChannelGroupRelation",
            @"SAUserIcon", @"SAColorListItem", nil
    ];
    
    NSMutableArray *predicateArray = [NSMutableArray array];
    [predicateArray addObject:predicate];
    
    if ([entitiesWithProfile containsObject: en]) {
        AuthProfileItem *profile = self.currentProfile;
        if (profile == nil) {
            [predicateArray addObject:[NSPredicate predicateWithFormat:@"profile.isActive = true"]];
        } else {
            [predicateArray addObject:[NSPredicate predicateWithFormat:@"profile = %@", profile]];
        }
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates: predicateArray];
    
    [fetchRequest setEntity:[NSEntityDescription entityForName:en inManagedObjectContext: self.managedObjectContext]];
    [fetchRequest setIncludesSubentities:NO];
    
    NSError *fetchError = nil;
    NSUInteger count = [self.managedObjectContext countForFetchRequest:fetchRequest error:&fetchError];
    
    if(count == NSNotFound || fetchError != nil ) {
        count = 0;
    }
    
    return count;
}

- (NSDictionary *) sumValesOfEntitiesWithProperties:(NSArray *)props predicate:(NSPredicate *)predicate entityName:(NSString *)en {
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.predicate = predicate;
    fetchRequest.propertiesToFetch = props;
    [fetchRequest setResultType:NSDictionaryResultType];
    
    [fetchRequest setEntity:[NSEntityDescription entityForName:en inManagedObjectContext: self.managedObjectContext]];
    NSError *error = nil;
    NSArray *r = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    if ( error == nil && r.count > 0 ) {
        return [r objectAtIndex:0];
    }
    
    return nil;
}

- (NSDate *) lastSecondInMonthWithOffset:(int)offset {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier: NSCalendarIdentifierGregorian];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear
                                    | NSCalendarUnitMonth
                                    | NSCalendarUnitDay
                                    | NSCalendarUnitHour
                                    | NSCalendarUnitMinute
                                    | NSCalendarUnitSecond fromDate:[NSDate date]];
    
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    [components setDay:1];
    NSDate *date = [calendar dateFromComponents:components];
    
    components = [[NSDateComponents alloc] init];
    [components setMonth:1+offset];
    date = [calendar dateByAddingComponents:components toDate:date options:0];
    
    components = [[NSDateComponents alloc] init];
    [components setSecond:-1];
    date = [calendar dateByAddingComponents:components toDate:date options:0];
    
    return date;
}

#pragma mark Locations
-(_SALocation*) fetchLocationById:(int)location_id {
    return [self fetchItemByPredicate:[NSPredicate predicateWithFormat:@"location_id = %i", location_id] entityName:@"SALocation"];
};

#pragma mark Channels

-(SAChannel*) fetchChannelById:(int)channel_id {
    return [self fetchItemByPredicate:[NSPredicate predicateWithFormat:@"remote_id = %i", channel_id] entityName:@"SAChannel"];
};

-(NSUInteger) getChannelCount {
    return [self getCountByPredicate:[NSPredicate predicateWithFormat:@"func > 0 AND visible > 0"] entityName:@"SAChannel"];
}

#pragma mark Channel Groups

-(SAChannelGroup*) fetchChannelGroupById:(int)remote_id {
    return [self fetchItemByPredicate:[NSPredicate predicateWithFormat:@"remote_id = %i", remote_id] entityName:@"SAChannelGroup"];
};

#pragma mark Color List

-(SAColorListItem *) getColorListItemForRemoteId:(int)remote_id andIndex:(int)idx forGroup:(BOOL)group {
 
    SAColorListItem *item = [self fetchItemByPredicate:[NSPredicate predicateWithFormat:@"remote_id = %i AND group = %@ AND idx = %i", remote_id, [NSNumber numberWithBool:group], idx] entityName:@"SAColorListItem"];
    
    if ( item == nil ) {
        
        item = [[SAColorListItem alloc] initWithEntity:[NSEntityDescription entityForName:@"SAColorListItem" inManagedObjectContext:self.managedObjectContext] insertIntoManagedObjectContext:self.managedObjectContext];
    
        item.remote_id = remote_id;
        item.group = group;
        item.idx = [NSNumber numberWithInt:idx];
        item.profile = self.currentProfile;
        
        
        [self.managedObjectContext insertObject:item];
        [self saveContext];
    }
    
    return item;
}

-(void) updateColorListItem:(SAColorListItem *)item {
    
    [self saveContext];
}

#pragma mark Measurements - Common

-(NSArray *) getMeasurementsForChannelId:(int)channel_id dateFrom:(NSDate *)dateFrom dateTo:(NSDate *)dateTo entityName:(NSString*)entityName {
    AuthProfileItem *profile = self.currentProfile;
    if (profile == nil) {
        return nil;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:self.managedObjectContext];
    
    [fetchRequest setEntity:entity];
    [fetchRequest setResultType:NSDictionaryResultType];
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"channel_id = %i AND (%@ = nil OR date >= %@) AND (%@ = nil OR date <= %@) AND profile = %@", channel_id, dateFrom, dateFrom, dateTo, dateTo, profile];
    
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    
    NSError *error = nil;
    NSArray *r = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    if ( error == nil && r.count > 0 ) {
        return r;
    }
    
    return nil;
}

-(long) getTimestampOfMeasurementItemWithChannelId:(int)channel_id minimum:(BOOL)min entityName:(NSString*)en {
    SAIncrementalMeasurementItem *item = [
        self
        fetchItemByPredicate:[NSPredicate predicateWithFormat:@"channel_id = %i", channel_id]
        entityName: en
        sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:min]]
    ];
    
    return item ? [item.date timeIntervalSince1970] : 0;
}

-(void) deleteAllMeasurementsForChannelId:(int)channel_id entityName:(NSString *)en {
    AuthProfileItem *profile = self.currentProfile;
    if (profile == nil) {
        return;
    }
    
    BOOL del = YES;
    do {
        del = NO;
        NSArray *arr = [self fetchByPredicate:[NSPredicate predicateWithFormat:@"channel_id = %i AND profile = %@", channel_id, profile] entityName:en limit:1000];
        
        if (arr && arr.count) {
            del = YES;
            for(int a=0;a<arr.count;a++) {
                [self.managedObjectContext deleteObject:[arr objectAtIndex:a]];
            }
            [self saveContext];
        }
        
    } while (del);
    
}

-(NSUInteger) getIncrementalMeasurementItemCountWithoutComplementForChannelId:(int)channel_id entityName:(NSString *)en {
    return [self getCountByPredicate:[NSPredicate predicateWithFormat:@"channel_id = %i AND complement = NO", channel_id] entityName:en];
}

-(BOOL) timestampStartsWithTheCurrentMonth:(long)timestamp {
    if (timestamp == 0) {
        return YES;
    };
    
    NSDateComponents *dc1 = [[NSCalendar currentCalendar] components:NSCalendarUnitMonth | NSCalendarUnitYear fromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
    
    NSDateComponents *dc2 = [[NSCalendar currentCalendar] components:NSCalendarUnitMonth | NSCalendarUnitYear fromDate:[NSDate date]];
    
    return dc1.month == dc2.month && dc1.year == dc2.year;
}

- (void) addGroupByProperty:(GroupBy)gb toMutableArray:(NSMutableArray*)props entity:(NSEntityDescription *)entity {
    switch (gb) {
        case gbMinute:
            [props addObject:[entity.propertiesByName objectForKey:@"minute"]];
            break;
        case gbHour:
            [props addObject:[entity.propertiesByName objectForKey:@"hour"]];
            break;
        case gbDay:
            [props addObject:[entity.propertiesByName objectForKey:@"day"]];
            break;
        case gbWeekday:
            [props addObject:[entity.propertiesByName objectForKey:@"weekday"]];
            break;
        case gbMonth:
            [props addObject:[entity.propertiesByName objectForKey:@"month"]];
            break;
        case gbYear:
            [props addObject:[entity.propertiesByName objectForKey:@"year"]];
            break;
        default:
            break;
    }
}

-(NSArray *) getIncrementalMeasurementsForChannelId:(int)channel_id fields:(NSArray*)fields entityName:(NSString*)en dateFrom:(NSDate *)dateFrom dateTo:(NSDate *)dateTo  groupBy:(GroupBy)gb groupingDepth:(GroupingDepth)gd {
    AuthProfileItem *profile = self.currentProfile;
    if (profile == nil) {
        return nil;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:en inManagedObjectContext:self.managedObjectContext];
    
    [fetchRequest setEntity:entity];
    [fetchRequest setResultType:NSDictionaryResultType];
    
    NSMutableArray *propertiesToFetch = [[NSMutableArray alloc] init];
    
    NSExpressionDescription *ed = [[NSExpressionDescription alloc] init];
    [ed setName:@"date"];
    [ed setExpression:[NSExpression expressionForFunction:@"max:" arguments:[NSArray arrayWithObject:[NSExpression expressionForKeyPath:@"date"]]]];
    [ed setExpressionResultType:NSDateAttributeType];
    
    [propertiesToFetch addObject:ed];
    
    for(int a=0;a<fields.count;a++) {
        ed = [[NSExpressionDescription alloc] init];
        [ed setName:[fields objectAtIndex:a]];
        [ed setExpression:[NSExpression expressionForFunction:@"sum:" arguments:[NSArray arrayWithObject:[NSExpression expressionForKeyPath:[fields objectAtIndex:a]]]]];
        [ed setExpressionResultType:NSDoubleAttributeType];
        [propertiesToFetch addObject:ed];
    }
    
    fetchRequest.propertiesToFetch = propertiesToFetch;
    NSMutableArray *propertiesToGroupBy = [[NSMutableArray alloc] init];
    
    if (gd != gdNone) {
        switch (gd) {
            case gdMinutes:
                [self addGroupByProperty:gbMinute toMutableArray:propertiesToGroupBy entity:entity];
            case gdHours:
                [self addGroupByProperty:gbHour toMutableArray:propertiesToGroupBy entity:entity];
            case gdDays:
                [self addGroupByProperty:gbDay toMutableArray:propertiesToGroupBy entity:entity];
            case gdMonths:
                [self addGroupByProperty:gbMonth toMutableArray:propertiesToGroupBy entity:entity];
            case gdYears:
                [self addGroupByProperty:gbYear toMutableArray:propertiesToGroupBy entity:entity];
                break;
            default:
                break;
        }
    } else if (gb != gbNone) {
        [self addGroupByProperty:gb toMutableArray:propertiesToGroupBy entity:entity];
    }

    fetchRequest.propertiesToGroupBy = propertiesToGroupBy.count ? propertiesToGroupBy : nil;
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"channel_id = %i AND (%@ = nil OR date >= %@) AND (%@ = nil OR date <= %@) AND profile = %@", channel_id, dateFrom, dateFrom, dateTo, dateTo, profile];
    
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    
    NSError *error = nil;
    NSArray *r = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    if ( error == nil && r.count > 0 ) {
        return r;
    }
    
    return nil;
    
}

#pragma mark Electricity Measurements

-(SAElectricityMeasurementItem*) newElectricityMeasurementItemWithManagedObjectContext:(BOOL)moc {
    SAElectricityMeasurementItem *item = [[SAElectricityMeasurementItem alloc] initWithEntity:[NSEntityDescription entityForName:@"SAElectricityMeasurementItem" inManagedObjectContext:self.managedObjectContext] insertIntoManagedObjectContext:moc ? self.managedObjectContext : nil];
    if (moc) {
        item.profile = self.currentProfile;
        [self.managedObjectContext insertObject:item];
    }
    return item;
}

-(long) getTimestampOfElectricityMeasurementItemWithChannelId:(int)channel_id minimum:(BOOL)min {
    return [self getTimestampOfMeasurementItemWithChannelId:channel_id minimum:min entityName:@"SAElectricityMeasurementItem"];
}

-(void) deleteAllElectricityMeasurementsForChannelId:(int)channel_id {
    [self deleteAllMeasurementsForChannelId:channel_id entityName:@"SAElectricityMeasurementItem"];
}

-(NSUInteger) getElectricityMeasurementItemCountWithoutComplementForChannelId:(int)channel_id {
    return [self getIncrementalMeasurementItemCountWithoutComplementForChannelId:channel_id entityName:@"SAElectricityMeasurementItem"];
}


-(BOOL) electricityMeterMeasurementsStartsWithTheCurrentMonthForChannelId:(int)channel_id {
    long ts = [self getTimestampOfElectricityMeasurementItemWithChannelId:channel_id minimum:YES];
    return [self timestampStartsWithTheCurrentMonth:ts];
}

- (double) sumActiveEnergyForChannelId:(int)channel_id monthLimitOffset:(int) offset forwarded:(BOOL)fwd {
    
    double result = 0;
    int a;
    
    NSString *field = fwd ? @"fae" : @"rae";
    NSMutableArray *props = [[NSMutableArray alloc] init];
    for(a=1;a<=3;a++) {
        NSExpressionDescription *ed = [[NSExpressionDescription alloc] init];
        [ed setName:[NSString stringWithFormat:@"%@%i", field, a]];
        [ed setExpression:[NSExpression expressionForFunction:@"sum:" arguments:[NSArray arrayWithObject:[NSExpression expressionForKeyPath:[NSString stringWithFormat:@"phase%i_%@", a, field]]]]];
        [ed setExpressionResultType:NSDoubleAttributeType];
        [props addObject:ed];
    }
    

    NSDate *date = [self lastSecondInMonthWithOffset: offset];
    
    AuthProfileItem *profile = self.currentProfile;
    NSPredicate *predicate;
    if (profile == nil) {
        predicate = [NSPredicate predicateWithFormat:@"channel_id = %i AND date <= %@ AND profile.isActive = true", channel_id, date];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"channel_id = %i AND date <= %@ AND profile = %@", channel_id, date, profile];
    }
    NSDictionary *sum = [self sumValesOfEntitiesWithProperties:props predicate:predicate entityName:@"SAElectricityMeasurementItem"];
    
    if (sum && sum.count == 3) {
        for(a=1;a<=3;a++) {
            result += [[sum objectForKey:[NSString stringWithFormat:@"%@%i", field, a]] doubleValue];
        }
    }
    
    return result;
}

-(NSArray *) getElectricityMeasurementsForChannelId:(int)channel_id dateFrom:(NSDate *)dateFrom dateTo:(NSDate *)dateTo groupBy:(GroupBy)gb groupingDepth:(GroupingDepth)gd fields:(NSArray*)fields {
    return [self getIncrementalMeasurementsForChannelId:channel_id fields:fields entityName:@"SAElectricityMeasurementItem" dateFrom:dateFrom dateTo:dateTo groupBy:gb groupingDepth:gd];
}

#pragma mark Impulse Counter Measurements

-(SAImpulseCounterMeasurementItem*) newImpulseCounterMeasurementItemWithManagedObjectContext:(BOOL)moc {
    SAImpulseCounterMeasurementItem *item = [[SAImpulseCounterMeasurementItem alloc] initWithEntity:[NSEntityDescription entityForName:@"SAImpulseCounterMeasurementItem" inManagedObjectContext:self.managedObjectContext] insertIntoManagedObjectContext:moc ? self.managedObjectContext : nil];
    
    if (moc) {
        item.profile = self.currentProfile;
        [self.managedObjectContext insertObject:item];
    }
    return item;
}

-(long) getTimestampOfImpulseCounterMeasurementItemWithChannelId:(int)channel_id minimum:(BOOL)min {
    return [self getTimestampOfMeasurementItemWithChannelId:channel_id minimum:min entityName:@"SAImpulseCounterMeasurementItem"];
}

-(void) deleteAllImpulseCounterMeasurementsForChannelId:(int)channel_id {
    [self deleteAllMeasurementsForChannelId:channel_id entityName:@"SAImpulseCounterMeasurementItem"];
}

-(NSUInteger) getImpulseCounterMeasurementItemCountWithoutComplementForChannelId:(int)channel_id {
    return [self getIncrementalMeasurementItemCountWithoutComplementForChannelId:channel_id entityName:@"SAImpulseCounterMeasurementItem"];
}

-(BOOL) impulseCounterMeasurementsStartsWithTheCurrentMonthForChannelId:(int)channel_id {
    long ts = [self getTimestampOfImpulseCounterMeasurementItemWithChannelId:channel_id minimum:YES];
    return [self timestampStartsWithTheCurrentMonth:ts];
}

- (double) calculatedValueSumForChannelId:(int)channel_id monthLimitOffset:(int)offset {
    
    double result = 0;
    AuthProfileItem *profile = self.currentProfile;
    if (profile == nil) {
        return result;
    }

    NSMutableArray *props = [[NSMutableArray alloc] init];
    NSExpressionDescription *ed = [[NSExpressionDescription alloc] init];
    [ed setName:@"calculated_value"];
    [ed setExpression:[NSExpression expressionForFunction:@"sum:" arguments:[NSArray arrayWithObject:[NSExpression expressionForKeyPath:@"calculated_value"]]]];
    [ed setExpressionResultType:NSDoubleAttributeType];
    [props addObject:ed];

    NSDate *date = [self lastSecondInMonthWithOffset: offset];
    NSPredicate *predicte = [NSPredicate predicateWithFormat:@"channel_id = %i AND date <= %@ && profile = %@", channel_id, date, profile];
    NSDictionary *sum = [self sumValesOfEntitiesWithProperties:props predicate:predicte entityName:@"SAImpulseCounterMeasurementItem"];
    
    if (sum && sum.count == 1) {
        result = [[sum objectForKey:@"calculated_value"] doubleValue];
    }
    
    return result;
}

-(NSArray *) getImpulseCounterMeasurementsForChannelId:(int)channel_id dateFrom:(NSDate *)dateFrom dateTo:(NSDate *)dateTo groupBy:(GroupBy)gb groupingDepth:(GroupingDepth)gd {
    return [self getIncrementalMeasurementsForChannelId:channel_id fields:@[@"calculated_value"] entityName:@"SAImpulseCounterMeasurementItem" dateFrom:dateFrom dateTo:dateTo groupBy:gb groupingDepth:gd];
}

#pragma mark Thermometer Measurements

-(SATemperatureMeasurementItem*) newTemperatureMeasurementItem {
    SATemperatureMeasurementItem *item = [[SATemperatureMeasurementItem alloc] initWithEntity:[NSEntityDescription entityForName:@"SATemperatureMeasurementItem" inManagedObjectContext:self.managedObjectContext] insertIntoManagedObjectContext:self.managedObjectContext];
    
    item.profile = self.currentProfile;
    [self.managedObjectContext insertObject:item];
    return item;
}

-(long) getTimestampOfTemperatureMeasurementItemWithChannelId:(int)channel_id minimum:(BOOL)min {
    return [self getTimestampOfMeasurementItemWithChannelId:channel_id minimum:min entityName:@"SATemperatureMeasurementItem"];
}

-(NSUInteger) getTemperatureMeasurementItemCountForChannelId:(int)channel_id {
    return [self getCountByPredicate:[NSPredicate predicateWithFormat:@"channel_id = %i", channel_id] entityName:@"SATemperatureMeasurementItem"];
}

-(void) deleteAllTemperatureMeasurementsForChannelId:(int)channel_id {
    [self deleteAllMeasurementsForChannelId:channel_id entityName:@"SATemperatureMeasurementItem"];
}

-(NSArray *) getTemperatureMeasurementsForChannelId:(int)channel_id dateFrom:(NSDate *)dateFrom dateTo:(NSDate *)dateTo {
    return [self getMeasurementsForChannelId:channel_id dateFrom:dateFrom dateTo:dateTo entityName:@"SATemperatureMeasurementItem"];
}

#pragma mark Temperature and Humidity Measurements

-(SATempHumidityMeasurementItem*) newTempHumidityMeasurementItem {
    SATempHumidityMeasurementItem *item = [[SATempHumidityMeasurementItem alloc] initWithEntity:[NSEntityDescription entityForName:@"SATempHumidityMeasurementItem" inManagedObjectContext:self.managedObjectContext] insertIntoManagedObjectContext:self.managedObjectContext];
    
    item.profile = self.currentProfile;
    [self.managedObjectContext insertObject:item];
    return item;
}

-(long) getTimestampOfTempHumidityMeasurementItemWithChannelId:(int)channel_id minimum:(BOOL)min {
    return [self getTimestampOfMeasurementItemWithChannelId:channel_id minimum:min entityName:@"SATempHumidityMeasurementItem"];
}

-(NSUInteger) getTempHumidityMeasurementItemCountForChannelId:(int)channel_id {
    return [self getCountByPredicate:[NSPredicate predicateWithFormat:@"channel_id = %i", channel_id] entityName:@"SATempHumidityMeasurementItem"];
}

-(void) deleteAllTempHumidityMeasurementsForChannelId:(int)channel_id {
    [self deleteAllMeasurementsForChannelId:channel_id entityName:@"SATempHumidityMeasurementItem"];
}

-(NSArray *) getTempHumidityMeasurementsForChannelId:(int)channel_id dateFrom:(NSDate *)dateFrom dateTo:(NSDate *)dateTo {
    return [self getMeasurementsForChannelId:channel_id dateFrom:dateFrom dateTo:dateTo entityName:@"SATempHumidityMeasurementItem"];
}

#pragma mark Thermostat Measurements

-(SAThermostatMeasurementItem*) newThermostatMeasurementItem {
    SAThermostatMeasurementItem *item = [[SAThermostatMeasurementItem alloc] initWithEntity:[NSEntityDescription entityForName:@"SAThermostatMeasurementItem" inManagedObjectContext:self.managedObjectContext] insertIntoManagedObjectContext:self.managedObjectContext];
    
    item.profile = self.currentProfile;
    [self.managedObjectContext insertObject:item];
    return item;
}

-(long) getTimestampOfThermostatMeasurementItemWithChannelId:(int)channel_id minimum:(BOOL)min {
    return [self getTimestampOfMeasurementItemWithChannelId:channel_id minimum:min entityName:@"SAThermostatMeasurementItem"];
}

-(NSUInteger) getThermostatMeasurementItemCountForChannelId:(int)channel_id {
    return [self getCountByPredicate:[NSPredicate predicateWithFormat:@"channel_id = %i", channel_id] entityName:@"SAThermostatMeasurementItem"];
}

-(void) deleteAllThermostatMeasurementsForChannelId:(int)channel_id {
    [self deleteAllMeasurementsForChannelId:channel_id entityName:@"SAThermostatMeasurementItem"];
}

-(NSArray *) getThermostatMeasurementsForChannelId:(int)channel_id dateFrom:(NSDate *)dateFrom dateTo:(NSDate *)dateTo {
    return [self getMeasurementsForChannelId:channel_id dateFrom:dateFrom dateTo:dateTo entityName:@"SAThermostatMeasurementItem"];
}

#pragma mark HomePlus groups

-(NSFetchedResultsController*) getHomePlusGroupFrcWithGroupId:(int)groupId {
    NSArray *r = [self fetchByPredicate:[NSPredicate predicateWithFormat:@"group_id = %i AND visible > 0", groupId] entityName:@"SAChannelGroupRelation" limit:0];
    
    NSMutableArray *ids = [[NSMutableArray alloc] init];
    
    if ( r != nil ) {
        for(int a=0;a<r.count;a++) {
            [ids addObject:[NSNumber numberWithInt:((SAChannelGroupRelation*)[r objectAtIndex:a]).channel_id]];
        }
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    AuthProfileItem *profile = self.currentProfile;
    if (profile == nil) {
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"func > 0 AND visible > 0 AND remote_id IN %@ AND profile.isActive = true", ids];
    } else {
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"func > 0 AND visible > 0 AND remote_id IN %@ AND profile = %@", ids, profile];
    }
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"SAChannel" inManagedObjectContext: self.managedObjectContext]];
    
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:
                                [[NSSortDescriptor alloc] initWithKey:@"caption" ascending:NO],
                                nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *frc = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    
    NSError *error;
    [frc performFetch:&error];
    
    if ( error ) {
        NSLog(@"%@", error);
    }
    
    return frc;
}

-(NSArray*) zwaveBridgeChannelsWithLimit:(int)limit {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"visible > 0 AND type = %i AND (flags & %i) > 0", SUPLA_CHANNELTYPE_BRIDGE, SUPLA_CHANNEL_FLAG_ZWAVE_BRIDGE];
    return [self fetchByPredicate: predicate entityName:@"SAChannel" limit:limit];
}

-(BOOL) zwaveBridgeChannelAvailable {
    NSArray *r = [self zwaveBridgeChannelsWithLimit:1];
    return r && r.count == 1;
}

-(NSArray*) zwaveBridgeChannels {
    return [self zwaveBridgeChannelsWithLimit:0];
}

- (void)deleteObject:(NSManagedObject *)object {
    [self.managedObjectContext deleteObject:object];
}

#pragma mark Profile
- (AuthProfileItem *)currentProfile {
    id<ProfileManager> pm = [[MultiAccountProfileManager alloc] init];
    return [pm getCurrentProfileWithContext: self.managedObjectContext];
}

@end

