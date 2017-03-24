// ViewController.m
// Grouper App

#import "MapViewController.h"

#import "MBProgressHUD.h"

#import "Events.h"
#import "Event.h"
#import "Categories.h"

#import "AppDelegate.h"
#import "TagDetailControllerViewController.h"
#import "FilterListViewController.h"

#define kDetailSegue @"tagdetail"

@interface MapViewController () <UIAlertViewDelegate, EventModelDelegate, CategoryDelegate>
@property (nonatomic) BOOL waitingForEvent;
@property (nonatomic, retain) Event* recentEvent;
@end

@implementation MapViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    UILongPressGestureRecognizer* longTap = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    [self.mapView addGestureRecognizer:longTap];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:kDetailSegue]) {
        TagDetailControllerViewController* detailController = segue.destinationViewController;
        detailController.event = self.recentEvent;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshAnnotations];
    [self events].delegate = self;
    [self refreshAnnotations];
}

- (void) refreshAnnotations
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mapView removeAnnotations:self.mapView.annotations];
        for (id<MKAnnotation> a in self.events.filteredEvents) {
            [self.mapView addAnnotation:a];
        }
        [self.view setNeedsLayout];
    });
}

#pragma mark - Model
- (void)modelUpdated
{
    [self refreshAnnotations];
}

- (Events*) events
{
    return [AppDelegate appDelegate].events;
}

- (void) setupAnnotationWithGeocoder:(Event*)tag event:(CLLocation*)location
{
    // Try to get the Local name for the user's location
    [[[CLGeocoder alloc] init] reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        NSString* message = nil;
        if (!error) {
            NSLog(@"%@",placemarks);
            MKPlacemark* mark = placemarks[0];
            tag.placeName = mark.name;
            [tag setLatitude:mark.location.coordinate.latitude longitude:mark.location.coordinate.longitude];
            message = mark.name;
        } else {
            //if the name can't be located, still create a tag with the less-ressed data.
            CLLocationCoordinate2D coordinate = location.coordinate;
            [tag setLatitude:coordinate.latitude longitude:coordinate.longitude];
            message = [NSString stringWithFormat:@"%4.2f,%4.2f", coordinate.latitude, coordinate.longitude];
        }
        tag.configuredBySystem = YES;

        tag.name = message;
        [self.events addEvent:tag];
        [self.mapView addAnnotation:tag];
        self.recentEvent = tag;
        
        [MBProgressHUD hideAllHUDsForView:self.view animated:NO];
        [self performSegueWithIdentifier:kDetailSegue sender:self];
    }];
}

- (void) addLocationAtCoordinate:(CLLocationCoordinate2D)coordinate
{
    CLLocation* location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    Event* newTag = [[Event alloc] init];
    [self setupAnnotationWithGeocoder:newTag event:location];
}

- (IBAction)addEvent:(id)sender {
    
    MBProgressHUD* hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [hud setDetailsLabelText:@"Locating..."];
    [hud setDimBackground:YES];

    CLLocationCoordinate2D centerCoord = self.mapView.centerCoordinate;
    [self addLocationAtCoordinate:centerCoord];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.firstOtherButtonIndex) {
        Event* t = [self.events.filteredEvents lastObject];
        NSString* title = [alertView textFieldAtIndex:0].text;
        if (!title) title = t.placeName;
        t.name = title;
        [self.events persist:t];
    }
}


#pragma mark - Map View

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    if (_waitingForEvent == YES) {
        _waitingForEvent = NO;
        [self addEvent:nil];
        MKCoordinateRegion reg = MKCoordinateRegionMakeWithDistance(userLocation.location.coordinate, 1500, 1500);
        [mapView setRegion:reg animated:YES];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[Event class]]) {
        MKPinAnnotationView* pin = (MKPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
        if (!pin) {
            pin = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"pin"];
            pin.canShowCallout = YES;
            UIButton* callout = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            pin.rightCalloutAccessoryView = callout;
            UIImageView* imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0., 0., 36., 36.)];
            pin.leftCalloutAccessoryView = imageView;
            pin.draggable = YES;
        }
        pin.annotation = annotation;
        [(UIImageView*)pin.leftCalloutAccessoryView setImage:[(Event*)annotation image]];
        return pin;
    }
    return nil;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    NSLog(@"hit %@", view.annotation);
    self.recentEvent = (Event*) view.annotation;
    [self performSegueWithIdentifier:kDetailSegue sender:self];
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState
{
    Event* annotation = (Event*) annotationView.annotation;
    if (newState == MKAnnotationViewDragStateEnding && annotation.configuredBySystem) {
        CLLocationCoordinate2D co = [(Event*) annotationView.annotation coordinate];
        CLLocation* cllocation = [[CLLocation alloc] initWithLatitude:co.latitude longitude:co.longitude];
        [self setupAnnotationWithGeocoder:annotation event:cllocation];
    }
}

- (void)mapView:(MKMapView *)mapView didFailToLocateUserWithError:(NSError *)error
{
    [MBProgressHUD hideAllHUDsForView:self.view animated:NO];
    if (_waitingForEvent == YES) {
        _waitingForEvent = NO;
    }
    
    NSLog(@"failed to get user location error: %@", error);
    if ([error code] == kCLErrorDenied && [[error domain] isEqualToString:kCLErrorDomain]) {
        //user disabled location
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Location Services Disabled"
                                                        message:@"Enable Location preferences in settings to tag new hot spots and find nearby ones."
                                                       delegate:self
                                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Could not locate you" message:@"Try again in a few minutes" delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles: nil] show];
    }
    
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateAfterMapRegion) object:nil];
    [self performSelector:@selector(updateAfterMapRegion) withObject:nil afterDelay:2];
}


#pragma mark - Actions

- (void) updateAfterMapRegion
{
    MKCoordinateRegion region = self.mapView.region;
    [self.events queryRegion:region];
}

- (IBAction)updateFilter:(id)sender {
    FilterListViewController* flvc = [[FilterListViewController alloc] initWithSelectedCategories:[Categories filteredCategories] deleagte:self];
    [self.navigationController pushViewController:flvc animated:YES];
}

- (void)selectedCategories:(NSArray *)array
{
    [Categories setFilteredCategories:array];
    [self.events runQuery:[Categories query]];
}

- (void) tapped:(UILongPressGestureRecognizer*)longPress
{
    if (longPress.state == UIGestureRecognizerStateRecognized) {
        CGPoint tapLocation = [longPress locationInView:self.mapView];
        CLLocationCoordinate2D mapLocation = [self.mapView convertPoint:tapLocation toCoordinateFromView:self.mapView];
        [self addLocationAtCoordinate:mapLocation];
    }
}
@end
