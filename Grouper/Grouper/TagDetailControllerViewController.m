// TagDetailControllerViewController.m
// Grouper App

#import "TagDetailControllerViewController.h"
#import "AppDelegate.h"
#import "Event.h"

#import "FilterListViewController.h"

#define kCategoryRow 2

@interface TagDetailControllerViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate, CategoryDelegate>
@property (nonatomic, strong) UIImage* picture;
@end

@implementation TagDetailControllerViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.descriptionTextField.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (self.isMovingFromParentViewController) {
        [self persistEvent];
    }
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.event) {
        self.titleTextField.text = self.event.name;
        self.descriptionTextField.text = self.event.details;
    }
}

#pragma mark - Table view data source

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == kCategoryRow) {
        FilterListViewController* flvc = [[FilterListViewController alloc] initWithSelectedCategories:self.event.categories deleagte:self];
        [self.navigationController pushViewController:flvc animated:YES];
    }
}

- (void)selectedCategories:(NSArray *)array
{
    [self.event.categories setArray:array];
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:kCategoryRow inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == kCategoryRow) {
        cell.detailTextLabel.text = [self.event.categories componentsJoinedByString:@", "];
    }
}
#pragma mark - Model
- (void) persistEvent
{
    if (!self.event) {
        self.event = [[Event alloc] init];
    }
    
    BOOL modified = ![self.event.name isEqualToString:self.titleTextField.text] || ![self.event.details isEqualToString:self.descriptionTextField.text] || ![self.event.image isEqual:self.picture];
    if (modified) {
        self.event.name = self.titleTextField.text;
        self.event.details = self.descriptionTextField.text;
        self.event.image = self.picture;
        self.event.configuredBySystem = NO;
        
        [[AppDelegate appDelegate].events persist:self.event];
    }
}

#pragma mark - Images
- (IBAction) takePicture:(id)sender
{
    UIImagePickerController* imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    } else {
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    }
    
    [self presentViewController:imagePicker animated:YES completion:^{
        
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo
{
    [self dismissViewControllerAnimated:YES completion:nil];
    self.picture = image;
    self.imageView.image = image;
}


#pragma mark - Text
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [textField resignFirstResponder];
    if (textField == self.descriptionTextField) {
        self.event.details = textField.text;
    }
}
@end
