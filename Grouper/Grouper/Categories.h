
// Categories.h
// Grouper App

#import <Foundation/Foundation.h>

/** The Categories represents the list of available tag categories. Events can have multiple. */
@interface Categories : NSObject

+ (NSArray*) allCategories;
+ (NSArray*) activeCategories;

+ (NSArray*) filteredCategories;
+ (void) setFilteredCategories:(NSArray*)categories;


+ (BOOL) filterOnFor:(NSString*)category;
+ (void) setFilter:(NSString*)category on:(BOOL)on;

+ (NSString*) query;

@end
