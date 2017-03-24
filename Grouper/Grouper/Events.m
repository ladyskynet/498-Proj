//  Events.m
//  Grouper App


#import "Events.h"
#import "Event.h"

static NSString* const kBaseURL = @"http://localhost:3000/";
static NSString* const kEvents = @"events";
static NSString* const kFiles = @"files";


@interface Events ()
@property (nonatomic, strong) NSMutableArray* objects;
@end

@implementation Events

- (id)init
{
    self = [super init];
    if (self) {
        _objects = [NSMutableArray array];
    }
    return self;
}

- (NSArray*) filteredEvents
{
    return [self objects];
}

- (void) addEvent:(Event*)event
{
    [self.objects addObject:event];
}

- (void)loadImage:(Event*)event
{
    NSURL* url = [NSURL URLWithString:[[kBaseURL stringByAppendingPathComponent:kFiles] stringByAppendingPathComponent:event.imageId]]; //1
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDownloadTask* task = [session downloadTaskWithURL:url completionHandler:^(NSURL *fileLocation, NSURLResponse *response, NSError *error) { //2
        if (!error) {
            NSData* imageData = [NSData dataWithContentsOfURL:fileLocation]; //3
            UIImage* image = [UIImage imageWithData:imageData];
            if (!image) {
                NSLog(@"unable to build image");
            }
            event.image = image;
            if (self.delegate) {
                [self.delegate modelUpdated];
            }
        }
    }];
    
    [task resume]; //4
}

- (void)import
{
    NSURL* url = [NSURL URLWithString:[kBaseURL stringByAppendingPathComponent:kEvents]]; //1
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET"; //2
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"]; //3
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration]; //4
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask* dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { //5
        if (error == nil) {
            NSArray* responseArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]; //6
            [self parseAndAddEvents:responseArray toArray:self.objects]; //7
        }
    }];
    
    [dataTask resume]; //8
}

- (void)parseAndAddEvents:(NSArray*)events toArray:(NSMutableArray*)eventArray
{
    for (NSDictionary* item in events) {
        Event* event = [[Event alloc] initWithDictionary:item];
        [eventArray addObject:event];
        
        if (event.imageId) { //1
            [self loadImage:event];
        }
    }
    
    if (self.delegate) {
        [self.delegate modelUpdated];
    }
}

- (void) runQuery:(NSString *)queryString
{
    NSString* urlStr = [[kBaseURL stringByAppendingPathComponent:kEvents] stringByAppendingString:queryString]; //1
    NSURL* url = [NSURL URLWithString:urlStr];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask* dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error == nil) {
            [self.objects removeAllObjects]; //2
            NSArray* responseArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            NSLog(@"received %lu items", (unsigned long)responseArray.count);
            [self parseAndAddEvents:responseArray toArray:self.objects];
        }
    }];
    [dataTask resume];
}

- (void) queryRegion:(MKCoordinateRegion)region //1
{
    //not assumes the NE hemisphere. This logic should really check first.
    //also note that searches across hemisphere lines are not interpreted properly by Mongo
    CLLocationDegrees x0 = region.center.longitude - region.span.longitudeDelta; //2
    CLLocationDegrees x1 = region.center.longitude + region.span.longitudeDelta;
    CLLocationDegrees y0 = region.center.latitude - region.span.latitudeDelta;
    CLLocationDegrees y1 = region.center.latitude + region.span.latitudeDelta;
    
    NSString* boxQuery = [NSString stringWithFormat:@"{\"$geoWithin\":{\"$box\":[[%f,%f],[%f,%f]]}}",x0,y0,x1,y1]; //3
    NSString* locationInBox = [NSString stringWithFormat:@"{\"location\":%@}", boxQuery]; //4
    NSString* escBox = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                             (CFStringRef) locationInBox,
                                                                                             NULL,
                                                                                             (CFStringRef) @"!*();':@&=+$,/?%#[]{}",
                                                                                             kCFStringEncodingUTF8)); //5
    NSString* query = [NSString stringWithFormat:@"?query=%@", escBox]; //6
    [self runQuery:query]; //7
}

- (void) saveNewEventImageFirst:(Event*)event
{
    NSURL* url = [NSURL URLWithString:[kBaseURL stringByAppendingPathComponent:kFiles]]; //1
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST"; //2
    [request addValue:@"image/png" forHTTPHeaderField:@"Content-Type"]; //3
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
    
    NSData* bytes = UIImagePNGRepresentation(event.image); //4
    NSURLSessionUploadTask* task = [session uploadTaskWithRequest:request fromData:bytes completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { //5
        if (error == nil && [(NSHTTPURLResponse*)response statusCode] < 300) {
            NSDictionary* responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            event.imageId = responseDict[@"_id"]; //6
            [self persist:event]; //7
        }
    }];
    [task resume];
}


- (void) persist:(Event*)event
{
    // Input validation
    if (!event || event.name == nil || event.name.length == 0) {
        return;
    }
    
    // If there is an image, save it first
    if (event.image != nil && event.imageId == nil) {
        [self saveNewEventImageFirst:event];
        return;
    }
    
    NSString* events = [kBaseURL stringByAppendingPathComponent:kEvents];
    
    BOOL isExistingEvent = event._id != nil;
    NSURL* url = isExistingEvent ? [NSURL URLWithString:[events stringByAppendingPathComponent:event._id]] :
    [NSURL URLWithString:events];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = isExistingEvent ? @"PUT" : @"POST";
    
    NSData* data = [NSJSONSerialization dataWithJSONObject:[event toDictionary] options:0 error:NULL]; //3
    request.HTTPBody = data;
    
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; //4
    
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask* dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { //5
        if (!error) {
            NSArray* responseArray = @[[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]];
            [self parseAndAddEvents:responseArray toArray:self.objects];
        }
    }];
    [dataTask resume];
}
@end
