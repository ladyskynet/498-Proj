// Events.h
// Grouper App

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@class Event;

@protocol EventModelDelegate <NSObject>

- (void) modelUpdated;

@end

@interface Events : NSObject

@property (nonatomic, weak) id<EventModelDelegate> delegate;

- (NSArray*) filteredEvents;
- (void) addEvent:(Event*)event;

- (void) import;
- (void) persist:(Event*)event;

- (void) runQuery:(NSString*)queryString;
- (void) queryRegion:(MKCoordinateRegion)region;
@end
