//
//  HSKEventEventStore.m
//  CardManage
//
//  Created by Sam on 2018/7/10.
//  Copyright © 2018 Carl. All rights reserved.
//
#import "HSKEventStore.h"
static EKEventStore *kstore = nil;
static NSString * const key = @"HSKEventStore";
static NSString *calendarIdentifier = @"HSKEventStoreCalendar";

#define KStoreDebug 1

@interface HSKEvent()
@property (nonatomic, strong) EKEvent *e;
@end

@interface EKEventStore(db)
@property (nonatomic, readonly) NSUserDefaults *db;
@property (nonatomic, readonly) EKCalendar *localCalendar;
@end

@implementation EKEventStore(db)
- (NSUserDefaults *)db
{
    return [NSUserDefaults standardUserDefaults];
}
- (EKCalendar *)localCalendar
{
    if ([[self.db objectForKey:calendarIdentifier] length] == 0)
    {
        EKCalendar *c = [EKCalendar calendarForEntityType:EKEntityTypeEvent eventStore:self];
        c.title = @"账单提醒";
        for (EKSource *s in self.sources)
        {
            if (s.sourceType == EKSourceTypeCalDAV)
            {
                c.source = s;
                break;
            }
            if (s.sourceType == EKSourceTypeLocal)
            {
                c.source = s;
                break;
            }
        }
        NSError *error = nil;
        [self saveCalendar:c commit:YES error:&error];
        if (!error)
        {
            [self.db setObject:c.calendarIdentifier forKey:calendarIdentifier];
        }
    }
    NSString *identitfier = [self.db objectForKey:calendarIdentifier];
    __block EKCalendar *c = nil;
    [[self calendarsForEntityType:EKEntityTypeEvent] enumerateObjectsUsingBlock:^(EKCalendar * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
       if ([obj.calendarIdentifier isEqualToString:identitfier])
       {
           c = obj;
           *stop = YES;
       }
    }];
    return c;
}
@end

@interface HSKEventStore()
@end
@implementation HSKEventStore
+ (void)auth:(void (^)(BOOL))block
{
    if (!kstore)
    {
        kstore = [[EKEventStore alloc] init];
    }
    [kstore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError * _Nullable error) {
        EKAuthorizationStatus type = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (type == EKAuthorizationStatusAuthorized)
            {
                block(YES);
            }
            else if (type == EKAuthorizationStatusNotDetermined)
            {
                block(NO);
            }
            else
            {
                block(NO);
            }
        });
    }];
}

+ (void)deleteAllEvent
{
    NSString *str = [kstore.db valueForKey:key];
    NSArray *arr = [str componentsSeparatedByString:@"|"];
    [arr enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        EKEvent *item = [kstore eventWithIdentifier:obj];
        [kstore removeEvent:item span:EKSpanFutureEvents commit:YES error:nil];
    }];
    [kstore commit:nil];
    [kstore.db setObject:@"" forKey:key];
}

+ (void)deleteEventFor:(NSString *)identifier
{
    NSString *str = [kstore.db valueForKey:key];
    if (![str containsString:identifier]) return;
    EKEvent *item = [kstore eventWithIdentifier:identifier];
    [kstore removeEvent:item span:EKSpanFutureEvents commit:YES error:nil];
    NSMutableArray *arr = [str componentsSeparatedByString:@"|"].mutableCopy;
    [arr removeObject:identifier];
    NSString *updateStr = [arr componentsJoinedByString:@"|"];
    [kstore.db setObject:updateStr forKey:key];
}

+ (NSString *)addEvent:(HSKEvent *)event
{

    NSError *error = nil;
    event.e.calendar = kstore.localCalendar;
    [kstore saveEvent:event.e span:EKSpanFutureEvents error:&error];
#if KStoreDebug
    if (!error) {
        [HSKHUD showToastToView:nil title:@"提醒添加成功"];
    } else {
        [HSKHUD showToastToView:nil title:@"提醒添加失败"];
    }
#endif
    
    NSString *idntifier = event.identifier;
    if (![kstore.db valueForKey:key]) [kstore.db setObject:@"" forKey:key];
    if ([[kstore.db valueForKey:key] length] == 0)
    {
        [kstore.db setObject:idntifier forKey:key];
    }
    else
    {
        NSString *str = [kstore.db valueForKey:key];
        str = [str stringByAppendingString:[NSString stringWithFormat:@"|%@",idntifier]];
        [kstore.db setValue:str forKey:key];
    }
    
    return idntifier;
}


@end

@interface HSKEvent()
@property (nonatomic, copy) NSString *time; // yyyy-M-d-H
@property (nonatomic, copy) NSString *endTime;
@property (nonatomic, copy) NSString *beforeDay;

@property (nonatomic, assign) EKRecurrenceFrequency repeatType;
@property (nonatomic, copy) NSString *thing;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) NSInteger interval;
@property (nonatomic, assign) NSInteger repeatCount;
@end
@implementation HSKEvent
+ (instancetype)otherBillEventFor:(NSString *)something at:(NSString *)time
{
    NSMutableArray *timeComponents = [[self dateArrayfor:time] mutableCopy];
    [timeComponents removeObjectsInRange:NSMakeRange(timeComponents.count - 2, 2)];
    [timeComponents addObjectsFromArray:@[@"23", @"00"]];
    NSString *endtime = [timeComponents componentsJoinedByString:@"-"];
    return [self eventFor:something before:@"0" at:time end:endtime repeatFor:EKRecurrenceFrequencyDaily interval:1];
}

+ (instancetype)otherBillEventFor:(NSString *)something at:(NSString *)time before:(NSString *)beforeDay;
{
    NSMutableArray *timeComponents = [[self dateArrayfor:time] mutableCopy];
    [timeComponents removeObjectsInRange:NSMakeRange(timeComponents.count - 2, 2)];
    [timeComponents addObjectsFromArray:@[@"23", @"00"]];
    NSString *endtime = [timeComponents componentsJoinedByString:@"-"];
    return [self eventFor:something before:beforeDay at:time end:endtime repeatFor:EKRecurrenceFrequencyDaily interval:1];
}
+ (instancetype)eventFor:(NSString *)something
                  before:(NSString *)beforeDay
                      at:(NSString *)time
                     end:(NSString *)endTime
               repeatFor:(EKRecurrenceFrequency)repeatType
                interval:(NSInteger)interval
{
    NSString *regStr = @"\\d{4}-\\d{1,2}-\\d{1,2}-\\d{1,2}-\\d{2}";
    NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",regStr];
    if (![p evaluateWithObject:time])
    {
        NSAssert(nil, @"起始时间格式不合法");
        return nil;
    }
    

    if (![p evaluateWithObject:endTime])
    {
        NSAssert(nil, @"结束时间格式不合法");
        return nil;
    }
    
    HSKEvent *r = [HSKEvent new];
    r.thing = something;
    r.time = time;
    r.endTime = endTime;
    r.beforeDay = beforeDay;
    r.repeatType = repeatType;
    r.interval = interval;
    return r;
}

- (EKEvent *)e
{
   
    return _e ?: ({
        _e = [EKEvent eventWithEventStore:kstore];
       
        
        _e.startDate = [NSDate dateFromString:self.time formater:@"yyyy-M-d-H-mm"];
        _e.endDate = [NSDate dateFromString:self.endTime formater:@"yyyy-M-d-H-mm"];
        _e.title = self.thing;
        EKRecurrenceRule *r = [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:self.repeatType interval:self.interval end:[EKRecurrenceEnd recurrenceEndWithEndDate:_e.endDate]];
        EKAlarm *a = [EKAlarm alarmWithRelativeOffset:-(self.beforeDay.integerValue * 24 * 3600)];
        [_e addRecurrenceRule:r];
        [_e addAlarm:a];
        _e;
    });
    return nil;
}

+ (NSArray *)dateArrayfor:(NSString *)date
{
    NSArray *_ = [date componentsSeparatedByString:@"-"];
    return _;
}
- (NSString *)identifier
{
   return self.e.eventIdentifier;
}
@end
