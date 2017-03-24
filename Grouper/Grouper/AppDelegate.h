// AppDelegate.h
// Grouper App

#import <UIKit/UIKit.h>

#import "Events.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

/** Singleton data model */
@property (strong, nonatomic) Events* events;

/** Helper to get static instance */
+ (AppDelegate*) appDelegate;

@end
