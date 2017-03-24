// TagDetailControllerViewController.h
// Grouper App
#import <UIKit/UIKit.h>

@class Event;

@interface TagDetailControllerViewController : UITableViewController

@property (strong, nonatomic) Event* event;
@property (weak, nonatomic) IBOutlet UIButton *cameraButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UITextField *titleTextField;
@property (weak, nonatomic) IBOutlet UITextField *descriptionTextField;
@end
