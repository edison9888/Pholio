//
//  IPEditableTitleViewController.m
//  ipad-portfolio
//
//  Created by Brian Dewey on 4/29/11.
//  Copyright 2011 Brian Dewey. 
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "IPEditableTitleViewController.h"
#import "BDAssetsLibraryController.h"
#import "BDImagePickerController.h"
#import "IPSettingsController.h"
#import "IPAlert.h"
#import "IPUserDefaults.h"
#import "IPPortfolio.h"
#import "IPTutorialManager.h"
#import "BDOverlayViewController.h"

#define kDefaultBackgroundImageName       @"black.jpg"

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
//  Internal subclass that does what it says: It's a UITextField that tries
//  to stay centered horizontally relative to its superview. If the frame size
//  gets adjusted in a way that leaves the frame uncentered, it will adjust
//  the width and reset the center.
//

@interface IPAlwaysCenteredTextField: UITextField { }

@end

@implementation IPAlwaysCenteredTextField

////////////////////////////////////////////////////////////////////////////////
//
//  When the frame is set, look at the centerpoint. If we're not going to be
//  centered relative to our superview, adjust our width (to keep the left margin
//  in the same spot) and then ensure that the view remains centered.
//

- (void)setFrame:(CGRect)frame {
  
  CGFloat midX = CGRectGetMidX(frame);
  if (midX != self.superview.center.x) {
    
    //
    //  Adjust the frame to get the centers to align
    //
    
    frame.size.width += 0.5 * (self.superview.center.x - midX);
  }
  [super setFrame:frame];
  self.center = self.superview.center;
}

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
//  Private properties & methods.
//

@interface IPEditableTitleViewController ()

@property (nonatomic, copy) IPSetGridControllerDidPickImageBlock currentImagePickerBlock;

- (void)showSettings;
- (void)updateBackgroundImage;

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
//  And finally, the class.
//

@implementation IPEditableTitleViewController

@synthesize portfolio           = portfolio_;
@synthesize titleTextField      = titleTextField_;
@synthesize defaultPicker       = defaultPicker_;
@synthesize popoverController   = popoverController_;
@synthesize backgroundImage     = backgroundImage_;
@synthesize backgroundImageName = backgroundImageName_;
@synthesize tutorialManager     = tutorialManager_;
@synthesize overlayController   = overlayController_;
@synthesize alertManager        = alertManager_;
@synthesize userDefaults        = userDefaults_;
@synthesize currentImagePickerBlock = currentImagePickerBlock_;


////////////////////////////////////////////////////////////////////////////////
//
//  Initializer.
//

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    // Custom initialization
  }
  return self;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Dealloc.

////////////////////////////////////////////////////////////////////////////////
//
//  Release memory.
//

- (void)didReceiveMemoryWarning
{
  // Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];

  self.defaultPicker = nil;
}

#pragma mark - View lifecycle

/*
 // Implement loadView to create a view hierarchy programmatically, without using a nib.
 - (void)loadView
 {
 }
 */


////////////////////////////////////////////////////////////////////////////////
//
//  Set up the text field.
//

- (void)viewDidLoad {

  [super viewDidLoad];
  
  //
  //  Create the editable title field. 
  //
  
  self.titleTextField = [[IPAlwaysCenteredTextField alloc] init];
  self.titleTextField.textColor = [UIColor whiteColor];
  self.titleTextField.textAlignment = UITextAlignmentCenter;
  self.titleTextField.font = self.portfolio.titleFont;
  self.titleTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  if (self.navigationController != nil) {

    //
    //  Note, if we're not in a navigation controller then it's actively 
    //  harmful to execute this line. The rest of the lines are merely useless.
    //
    
    self.titleTextField.frame = self.navigationController.navigationBar.bounds;
  }
  self.titleTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
  self.titleTextField.delegate = self;
  self.titleTextField.returnKeyType = UIReturnKeyDone;
  self.navigationItem.titleView = self.titleTextField;
  self.navigationController.navigationBar.tintColor = self.portfolio.navigationColor;
  
  [self updateBackgroundImage];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Sets the right bar item depending on whether editing is enabled.
//

- (void)viewWillAppear:(BOOL)animated {

  if ([self.userDefaults editingEnabled] && 
      (self.navigationItem.rightBarButtonItem == nil)) {

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction 
                                                                                            target:self 
                                                                                            action:@selector(showSettings)];
    
  } else if (![self.userDefaults editingEnabled] && 
             (self.navigationItem.rightBarButtonItem != nil)) {
    
    self.navigationItem.rightBarButtonItem = nil;
  }
}

////////////////////////////////////////////////////////////////////////////////
//
//  Make sure any popover is also gone.
//

- (void)viewWillDisappear:(BOOL)animated {

  [self.popoverController dismissPopoverAnimated:animated];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Release views.
//

- (void)viewDidUnload {

  [super viewDidUnload];

  self.titleTextField = nil;
  self.popoverController = nil;
  self.defaultPicker = nil;
  self.backgroundImage = nil;
}

////////////////////////////////////////////////////////////////////////////////
//
//  We support all orientations by default.
//

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {

  // Return YES for supported orientations
  return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)shouldAutorotate {
  
  return YES;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Lazy initializer for |defaultPicker|.
//

- (UIImagePickerController *)defaultPicker {
  
  if (defaultPicker_ == nil) {
    defaultPicker_ = [[UIImagePickerController alloc] init];
    defaultPicker_.delegate = self;
  }
  return defaultPicker_;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Lazy initializer for |alertManager|.
//

- (IPAlert *)alertManager {
  
  if (alertManager_ == nil) {
    alertManager_ = [IPAlert defaultAlert];
  }
  return alertManager_;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Lazy initializer for |userDefaults|.
//

- (IPUserDefaults *)userDefaults {
  
  if (userDefaults_ == nil) {
    
    userDefaults_ = [IPUserDefaults defaultSettings];
  }
  return userDefaults_;
}

#pragma mark - Properties

////////////////////////////////////////////////////////////////////////////////
//
//  Getter -- lazy initialize to |kDefaultBackgroundImageName|.
//

- (NSString *)backgroundImageName {
  
  if (backgroundImageName_ == nil) {
    
    backgroundImageName_ = kDefaultBackgroundImageName;
  }
  return backgroundImageName_;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Sets the background image name... and the background image.
//

- (void)setBackgroundImageName:(NSString *)backgroundImageName {
  
  backgroundImageName_ = [backgroundImageName copy];
  [self updateBackgroundImage];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Updates the background image.
//

- (void)updateBackgroundImage {
  
  self.backgroundImage.image = [UIImage imageNamed:self.backgroundImageName];
}

////////////////////////////////////////////////////////////////////////////////

- (IPTutorialManager *)tutorialManager {
  
  if (tutorialManager_ == nil) {
    
    tutorialManager_ = [IPTutorialManager sharedManager];
  }
  return tutorialManager_;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Potentially animate replacing the overlay controller.
//

- (void)setOverlayController:(BDOverlayViewController *)overlayController animated:(BOOL)animated {

  if (overlayController == self.overlayController) {
    
    return;
  }
  
  BDOverlayViewController *oldController = overlayController_;
  overlayController_ = overlayController;
  overlayController.view.alpha = 0.0;
  [self.view addSubview:overlayController.view];
  NSTimeInterval duration = (animated) ? 0.2 : 0.0;
  
  [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
    
    overlayController.view.alpha = 1.0;
    oldController.view.alpha = 0.0;
    
  } completion:^(BOOL finished) {
    
    [oldController.view removeFromSuperview];
  }];
}

////////////////////////////////////////////////////////////////////////////////

- (void)setOverlayController:(BDOverlayViewController *)overlayController {
  
  [self setOverlayController:overlayController animated:NO];
}

#pragma mark - Image picking

////////////////////////////////////////////////////////////////////////////////
//
//  Presents an image picker and invokes the custom block upon successful 
//  completion.
//

- (void)presentImagePickerFromRect:(CGRect)rect
                            inView:(UIView *)view
                   andPerformBlock:(IPSetGridControllerDidPickImageBlock)block {
  
  self.currentImagePickerBlock = block;
  [self dismissPopover];
  self.popoverController = [[UIPopoverController alloc] initWithContentViewController:self.defaultPicker];
  [self.popoverController presentPopoverFromRect:rect 
                                          inView:view 
                        permittedArrowDirections:UIPopoverArrowDirectionAny 
                                        animated:YES];
}

- (void)presentBDImagePickerFromRect:(CGRect)rect
                              inView:(UIView *)view
                     andPerformBlock:(BDImagePickerControllerImageBlock)block {
  
  
}

////////////////////////////////////////////////////////////////////////////////
//
//  An image was picked.... perform |currentImagePickerBlock|.
//

- (void)imagePickerController:(UIImagePickerController *)picker 
didFinishPickingMediaWithInfo:(NSDictionary *)info {
  
  [self dismissPopover];
  UIImage *image = info[UIImagePickerControllerOriginalImage];
  if (self.currentImagePickerBlock != nil) {
    
    self.currentImagePickerBlock(image, info);
  }
}

////////////////////////////////////////////////////////////////////////////////
//
//  Dismiss popovers on cancel.
//

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  
  [self dismissPopover];
}

#pragma mark - UITextFieldDelegate

////////////////////////////////////////////////////////////////////////////////
//
//  *Should* we allow editing?
//

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
  
  return [self.userDefaults editingEnabled];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Select all text when start editing.
//

- (void)textFieldDidBeginEditing:(UITextField *)textField {
  
  [textField selectAll:nil];
}

////////////////////////////////////////////////////////////////////////////////
//
//  "Return" equals "done editing."
//

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  
  [textField resignFirstResponder];
  return NO;
}

#pragma mark - Settings

////////////////////////////////////////////////////////////////////////////////

- (UIPopoverController *)settingsPopover {
  
  IPSettingsController *settingsController = [[IPSettingsController alloc] init];
  settingsController.delegate = self;
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsController];
  nav.navigationBar.tintColor = self.portfolio.navigationColor;
  nav.navigationBar.translucent = NO;
  return [[UIPopoverController alloc] initWithContentViewController:nav];
}

////////////////////////////////////////////////////////////////////////////////

- (void)showSettings {
  
  [self dismissPopover];
  self.popoverController = [self settingsPopover];
  [self.popoverController presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem 
                                 permittedArrowDirections:UIPopoverArrowDirectionAny 
                                                 animated:YES];
}

#pragma mark - Popover controller methods

////////////////////////////////////////////////////////////////////////////////
//
//  The popover is going away. We can release our reference.
//

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
  
  _GTMDevAssert(popoverController == self.popoverController, 
                @"Got a dismiss notification for a popover controller we don't own!");
  
  //
  //  Setting the property to nil will release it, AND make sure we don't 
  //  send an extraneous |dismissPopoverAnimated:| message on |dismissPopover|.
  //
  
  self.popoverController = nil;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Gets rid of any active popover controller.
//

- (void)dismissPopover {
  
  [self.popoverController dismissPopoverAnimated:YES];
  self.popoverController = nil;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Make ourselves the delegate of any popover.
//

- (void)setPopoverController:(UIPopoverController *)popoverController {

  popoverController_ = popoverController;
  
  _GTMDevAssert(self.popoverController.delegate == nil,
                @"Popover controller should not already have a delegate");
  self.popoverController.delegate = self;
}

#pragma mark - MFMailComposeControllerDelegate

////////////////////////////////////////////////////////////////////////////////
//
//  The user is done working on mail.
//

- (void)mailComposeController:(MFMailComposeViewController *)controller 
          didFinishWithResult:(MFMailComposeResult)result 
                        error:(NSError *)error {
  
  [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - BDGridViewDelegate

////////////////////////////////////////////////////////////////////////////////
//
//  Do we allow editing?
//

- (BOOL)gridViewShouldEdit:(BDGridView *)gridView {
  
  return [self.userDefaults editingEnabled];
}

#pragma mark - IPSettingsControllerDelegate

////////////////////////////////////////////////////////////////////////////////
//
//  Should we allow emailing the photo?
//

- (BOOL)ipSettingsShouldMailCurrentPhoto {
  
  return NO;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Email the current photo. Subclass will need to override.
//

- (void)ipSettingsMailCurrentPhoto {
  
  //
  //  NOTHING
  //
}

////////////////////////////////////////////////////////////////////////////////
//
//  Let the user mail the developer.
//

- (void)ipSettingsMailDeveloper {
  
  Class mailClass = (NSClassFromString(@"MFMailComposeViewController"));
  [self dismissPopover];  
  if (mailClass != nil) {
    if ([mailClass canSendMail]) {
      MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
      picker.mailComposeDelegate = self;
      
      //
      //  Get a good subject for the mail
      //
      
      NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
      NSString *version = info[@"CFBundleShortVersionString"];
      NSString *build   = info[@"CFBundleVersion"];
      NSString *subject = [NSString stringWithFormat:@"Feedback on %@ %@ (%@)", 
                           __PRODUCT_NAME__, 
                           version,
                           build,
                           nil];
      [picker setSubject:subject];
      [picker setToRecipients:@[@"thebrain@brians-brain.org"]];
      
      [self presentModalViewController:picker animated:YES];
      
    } else {
      
      [self.alertManager showErrorMessage:kErrorEmail];
    }
  }
}

////////////////////////////////////////////////////////////////////////////////
//
//  Show the user guide.
//

- (void)ipSettingsShowUserGuide {
  
  [self dismissPopover];
  self.tutorialManager.state = IPTutorialManagerStateWelcome;
  [self startTutorial];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Gets the background image name.
//

- (NSString *)ipSettingsBackgroundImageName {
  
  return self.backgroundImageName;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Sets the background image name.
//

- (void)ipSettingsSetBackgroundImageName:(NSString *)backgroundImageName {
  
  self.backgroundImageName = backgroundImageName;
  self.portfolio.backgroundImageName = backgroundImageName;
  [self.portfolio savePortfolioToPath:[IPPortfolio defaultPortfolioPath]];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Gets the current navigation color.
//

- (UIColor *)ipSettingsNavigationColor {
  
  return self.portfolio.navigationColor;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Sets the navigation color.
//

- (void)ipSettingsSetNavigationColor:(UIColor *)navigationColor {
  
  self.portfolio.navigationColor = navigationColor;
  [self.portfolio savePortfolioToPath:[IPPortfolio defaultPortfolioPath]];
  
  self.navigationController.navigationBar.tintColor = navigationColor;
  self.navigationController.navigationBar.translucent = YES;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Gets the current color used for text.
//

- (UIColor *)ipSettingsGridTextColor {

  return self.portfolio.fontColor;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Save the new text color.
//

- (void)ipSettingsSetGridTextColor:(UIColor *)gridTextColor {
  
  self.portfolio.fontColor = gridTextColor;
  [self.portfolio savePortfolioToPath:[IPPortfolio defaultPortfolioPath]];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Get the title font.
//

- (NSString *)ipSettingsTitleFontFamily {
  
  return [self.portfolio.titleFont familyName];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Title font changed.
//

- (void)ipSettingsDidSetTitleFontFamily:(NSString *)fontFamily {

  UIFont *font = [UIFont fontWithName:fontFamily size:kIPPortfolioTitleFontSize];
  self.portfolio.titleFont = font;
  self.titleTextField.font = font;
  [self.portfolio savePortfolioToPath:[IPPortfolio defaultPortfolioPath]];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Get the text font.
//

- (NSString *)ipSettingsTextFontFamily {
  
  return [self.portfolio.textFont familyName];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Text font changed.
//

- (void)ipSettingsDidSetTextFontFamily:(NSString *)fontFamily {
  
  UIFont *font = [UIFont fontWithName:fontFamily size:[UIFont labelFontSize]];
  self.portfolio.textFont = font;
  [self.portfolio savePortfolioToPath:[IPPortfolio defaultPortfolioPath]];
}

////////////////////////////////////////////////////////////////////////////////

- (BOOL)ipSettingsUseTiles {
  
  return self.portfolio.layoutStyle == IPPortfolioLayoutStyleTiles;
}

////////////////////////////////////////////////////////////////////////////////

- (void)ipSettingsSetUseTiles:(BOOL)useTiles {
  
  if (useTiles) {
    
    self.portfolio.layoutStyle = IPPortfolioLayoutStyleTiles;
    
  } else {
    
    self.portfolio.layoutStyle = IPPortfolioLayoutStyleStacks;
  }
  [self.portfolio savePortfolioToPath:[IPPortfolio defaultPortfolioPath]];
}

#pragma mark - BDOverlayViewControllerDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)startTutorial {
  
  if (self.overlayController != nil) {
    
    //
    //  Abort if there's already an active tutorial.
    //
    
    return;
  }
  self.tutorialManager.state = IPTutorialManagerStateWelcome;
  [self.navigationController popToRootViewControllerAnimated:YES];
}

////////////////////////////////////////////////////////////////////////////////

- (BDOverlayViewController *)overlayControllerForCurrentState {
  
  if (self.tutorialManager.state == IPTutorialManagerStateNoTutorial) {
    
    return nil;
  }
  BDOverlayViewController *overlay = [[BDOverlayViewController alloc] initWithDelegate:self];
  overlay.overlayTitleText = self.tutorialManager.tutorialTitle;
  overlay.descriptionText  = self.tutorialManager.tutorialDescription;
  overlay.view.center      = self.view.center;
  overlay.view.frame       = CGRectOffset(overlay.view.frame, 
                                          0, 
                                          CGRectGetMaxY(self.view.bounds) - 20 - CGRectGetMaxY(overlay.view.frame));
  overlay.view.alpha       = 0.0;
  [overlay setSkipDisabled:self.tutorialManager.isLastState];
  return overlay;
}

////////////////////////////////////////////////////////////////////////////////

- (void)overlayViewController:(BDOverlayViewController *)controller didFinishWithSwipeDirection:(UISwipeGestureRecognizerDirection)direction {
  
  if (controller != self.overlayController) {
    
    _GTMDevAssert(NO, @"Got notification from unexpected controller");
    return;
  }
  CGRect finalFrame;
  switch (direction) {
      
    case UISwipeGestureRecognizerDirectionUp:
      
      finalFrame = CGRectOffset(controller.view.frame, 0, CGRectGetMaxY(controller.view.frame) * -1);
      break;
      
    case UISwipeGestureRecognizerDirectionDown:
      finalFrame = CGRectOffset(controller.view.frame, 0, CGRectGetMinY(controller.view.frame));
      break;
      
    case UISwipeGestureRecognizerDirectionLeft:
      finalFrame = CGRectOffset(controller.view.frame, CGRectGetMaxX(controller.view.frame) * -1, 0);
      break;
      
    case UISwipeGestureRecognizerDirectionRight:
      finalFrame = CGRectOffset(controller.view.frame, 
                                CGRectGetMaxX(self.view.bounds) - CGRectGetMinX(controller.view.frame), 
                                0);
      break;
  }
  self.tutorialManager.state = IPTutorialManagerStateNoTutorial;
  [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
    
    controller.view.frame = finalFrame;
    
  } completion:^(BOOL finished) {
    
    self.overlayController = nil;
  }];
}

////////////////////////////////////////////////////////////////////////////////

- (void)overlayViewControllerDidSkip:(BDOverlayViewController *)controller {
  
  if ([self.tutorialManager updateTutorialStateForEvent:IPTutorialManagerEventNext]) {
    
    [self setOverlayController:[self overlayControllerForCurrentState] animated:YES];
  }
}

@end
