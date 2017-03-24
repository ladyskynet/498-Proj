// ViewController.h
// Grouper App


#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface MapViewController : UIViewController <MKMapViewDelegate>
@property (nonatomic, weak) IBOutlet MKMapView *mapView;
- (IBAction)updateFilter:(id)sender;

@end
