//
//  HSKEventStore.h
//  CardManage
//
//  Created by Sam on 2018/7/10.
//  Copyright © 2018 Carl. All rights reserved.
//

#import <HSKBasic/HSKBasic.h>
#import <EventKit/EventKit.h>



@interface HSKEvent : HSKBaseModel
@property (nonatomic, readonly) NSString *time; // yyyy-M-d-H-mm
@property (nonatomic, readonly) NSString *beforeDay;
@property (nonatomic, readonly) EKRecurrenceFrequency repeatType;
@property (nonatomic, readonly) NSString *thing;
@property (nonatomic, readonly) NSString *identifier;

+ (instancetype)eventFor:(NSString *)something
                  before:(NSString *)beforeDay
                      at:(NSString *)time
                     end:(NSString *)endTime
               repeatFor:(EKRecurrenceFrequency)repeatType
                interval:(NSInteger)interval;

+ (instancetype)otherBillEventFor:(NSString *)something at:(NSString *)time before:(NSString *)beforeDay;
+ (instancetype)otherBillEventFor:(NSString *)something at:(NSString *)time;

@end

@interface HSKEventStore : HSKBaseModel
+ (void)auth:(void(^)(BOOL status))block;
+ (void)deleteAllEvent;
+ (NSString *)addEvent:(HSKEvent *)Event;
+ (void)deleteEventFor:(NSString *)identifier;
@end
