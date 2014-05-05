//
//  NAModalSheet.m
//  Note All
//
//  Created by Ken Worley on 11/17/13.
//
//

#import "NAModalSheet.h"
#import "UIImage+BoxBlur.h"
#import "UIImage+screenshot.h"

#define kBlurParameter 0.6
#define kViewAnimationDuration 0.4

static NSMutableArray *modalSheets = nil;

@interface NAModalSheet () <UIGestureRecognizerDelegate>
{
  UIViewController *childContentVC;

  UIWindow* prevWindow;
  UIWindow* myWindow;
  
  UIView *backgroundTint;
  UIView *childContainerContainer;
  UIView *childContainer;
  UIView *childView;
  UIView *blurredBackground;
  UIImageView *blurredImageView;
  
  CGRect childHiddenFrame;
  CGRect blurHiddenFrame;
}

@property (nonatomic, assign) NAModalSheetPresentationStyle presentationStyle;

@end

@implementation NAModalSheet

- (BOOL)shouldAutorotate
{
  if ([self.delegate respondsToSelector:@selector(modalSheetShouldAutorotate:)])
  {
    return [self.delegate modalSheetShouldAutorotate:self];
  }
  return [super shouldAutorotate];
}

- (NSUInteger)supportedInterfaceOrientations
{
  if ([self.delegate respondsToSelector:@selector(modalSheetSupportedInterfaceOrientations:)])
  {
    return [self.delegate modalSheetSupportedInterfaceOrientations:self];
  }
  return [super supportedInterfaceOrientations];
}

- (instancetype)initWithViewController:(UIViewController *)vc
                     presentationStyle:(NAModalSheetPresentationStyle)style
{
  self = [super initWithNibName:nil bundle:nil];
  if (self)
  {
    _animationDuration = kViewAnimationDuration;
    _presentationStyle = style;
    childContentVC = vc;
    prevWindow = [[UIApplication sharedApplication] keyWindow];
    self.backgroundTintColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    
    if (modalSheets == nil)
    {
      modalSheets = [NSMutableArray array];
    }
  }
  return self;
}

// Make sure the view gets laid out fullscreen prior to iOS 7
- (BOOL)wantsFullScreenLayout
{
  return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
  // Adjust all frames for the new orientation
  [self adjustFramesForBounds:self.view.bounds contentSize:childView.frame.size animated:NO];

  if (!self.disableBlurredBackground)
  {
    // Replace the snapshot of the screen with one in the correct orientation.
    UIImage *snapshot = [UIImage screenshotExcludingWindow:myWindow];
    NSData *imageData = UIImageJPEGRepresentation(snapshot, 0.01);
    blurredImageView.image = [[UIImage imageWithData:imageData] blurredImage:kBlurParameter];;
  }
}

- (void)adjustFramesForBounds:(CGRect)windowBounds contentSize:(CGSize)contentSize animated:(BOOL)animated
{
  if (animated)
  {
    [UIView animateWithDuration:self.animationDuration animations:^{
      [self adjustFramesForBounds:windowBounds contentSize:contentSize];
    }];
  }
  else
  {
    [self adjustFramesForBounds:windowBounds contentSize:contentSize];
  }
}

- (void)adjustFramesForBounds:(CGRect)mainBounds contentSize:(CGSize)contentSize
{
  CGFloat insetFromEdge = self.slideInset;
  
  // If full justification was specified, change the contentSize so the width fills the screen
  if (self.horizontalJustification == NAModalSheetHorizontalJustificationFull)
  {
    contentSize.width = CGRectGetWidth(mainBounds);
  }
  
  UIViewController *rootVC = prevWindow.rootViewController;
  if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderNavBar)
  {
    CGRect sbFrame = [[UIApplication sharedApplication] statusBarFrame];
    CGFloat statusBarHeight = UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]) ? sbFrame.size.height : sbFrame.size.width;
    CGFloat navBarHeight = 0;
    if ([rootVC isKindOfClass:[UINavigationController class]])
    {
      navBarHeight = ((UINavigationController*)rootVC).navigationBar.frame.size.height;
    }
    insetFromEdge = statusBarHeight + navBarHeight;
  }
  else if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderToolbar)
  {
    CGFloat toolbarHeight = 0;
    if ([rootVC isKindOfClass:[UINavigationController class]])
    {
      toolbarHeight = ((UINavigationController*)rootVC).toolbar.frame.size.height;
    }
    insetFromEdge = toolbarHeight;
  }
  
  // If the view is sliding on from somewhere other than the edge of the screen, then the darkening tint should exclude
  // that portion.
  CGRect tintRect = mainBounds;
  if (insetFromEdge > 0.0)
  {
    if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromBottom || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderToolbar)
    {
      tintRect.size.height -= insetFromEdge;
    }
    else if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromTop || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderNavBar)
    {
      tintRect.size.height -= insetFromEdge;
      tintRect.origin.y += insetFromEdge;
    }
  }
  
  // The child container view animates in/out when using a sliding presentation while a blurred version
  // of the screen snapshot animates within it to appear motionless in relation to the screen.
  CGRect childContainerRect = tintRect;
  childContainerRect.size = contentSize;
  switch (self.horizontalJustification)
  {
    default:
    case NAModalSheetHorizontalJustificationCentered:
      childContainerRect.origin.x = CGRectGetMidX(tintRect) - roundf(0.5 * contentSize.width);
      break;
      
    case NAModalSheetHorizontalJustificationLeft:
    case NAModalSheetHorizontalJustificationFull:
      childContainerRect.origin.x = CGRectGetMinX(tintRect);
      break;
      
    case NAModalSheetHorizontalJustificationRight:
      childContainerRect.origin.x = CGRectGetMaxX(tintRect) - contentSize.width;
      break;
  }

  if (self.presentationStyle == NAModalSheetPresentationStyleFadeInCentered)
  {
    childContainerRect.origin.y = CGRectGetMidY(tintRect) - roundf(0.5 * contentSize.height);
  }
  else if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromBottom || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderToolbar)
  {
    childContainerRect.origin.y = CGRectGetMaxY(tintRect) - contentSize.height;
  }
  else if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromTop || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderNavBar)
  {
    childContainerRect.origin.y = 0.0;
  }
  else
  {
    NSAssert(0, @"Unknown presentation style");
  }
  
  backgroundTint.frame = tintRect;
  childContainerContainer.frame = tintRect;
  childContainer.frame = childContainerRect;
  
  CGRect blurBgndRect;
  blurBgndRect.size = mainBounds.size;
  blurBgndRect.origin.x = -childContainerRect.origin.x;
  blurBgndRect.origin.y = -childContainerRect.origin.y;
  
  CGRect blurViewRect = blurBgndRect;
  blurViewRect.origin.x = blurViewRect.origin.y = 0.0;

  if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromBottom || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderToolbar)
  {
    blurBgndRect.size.height -= insetFromEdge;
  }
  else if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromTop || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderNavBar)
  {
    blurBgndRect.origin.y -= insetFromEdge;
  }
  
  blurredBackground.frame = blurBgndRect;
  blurredImageView.frame = blurViewRect;
  
  childView.frame = childContainer.bounds;
  
  [self adjustHiddenRectsForBounds:mainBounds contentSize:contentSize];
}

- (void)adjustHiddenRectsForBounds:(CGRect)mainBounds contentSize:(CGSize)contentSize
{
  childHiddenFrame = childContainer.frame;
  if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromBottom || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderToolbar)
  {
    childHiddenFrame.origin.y = CGRectGetMaxY(childContainerContainer.bounds);
  }
  else if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromTop || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderNavBar)
  {
    childHiddenFrame.origin.y = -CGRectGetHeight(childContainer.frame);
  }
  
  blurHiddenFrame = blurredBackground.frame;
  if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromBottom || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderToolbar)
  {
    blurHiddenFrame.origin.y -= CGRectGetHeight(childContainer.frame);
  }
  else if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromTop || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderNavBar)
  {
    blurHiddenFrame.origin.y += CGRectGetMaxY(childContainer.bounds);
  }
}

- (void)loadView
{
  myWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  myWindow.autoresizingMask = UIViewAutoresizingNone;
  myWindow.opaque = NO;

  UIView *mainView = [[UIView alloc] initWithFrame:myWindow.bounds];
  mainView.backgroundColor = [UIColor clearColor];

  UITapGestureRecognizer *mainViewTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTouched:)];
  [mainView addGestureRecognizer:mainViewTap];
  mainViewTap.delegate = self;

  self.view = mainView;
}

- (void)viewDidLoad
{
  CGFloat cornerRadius = self.presentationStyle == NAModalSheetPresentationStyleFadeInCentered ? self.cornerRadiusWhenCentered : 0.0;
  UIView *mainView = self.view;
  
  backgroundTint = [[UIView alloc] initWithFrame:mainView.bounds];
  backgroundTint.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  backgroundTint.backgroundColor = self.backgroundTintColor;
  backgroundTint.alpha = 0.0;
  [mainView addSubview:backgroundTint];
  
  // This view contains the child view container. Any animated motion of the child container is clipped
  // to these bounds.
  childContainerContainer = [[UIView alloc] initWithFrame:mainView.bounds];
  childContainerContainer.backgroundColor = [UIColor clearColor];
  childContainerContainer.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  childContainerContainer.clipsToBounds = YES;
  childContainerContainer.layer.cornerRadius = cornerRadius;
  [mainView addSubview:childContainerContainer];
  
  // Add the child controller as a sub view controller of this one
  [self addChildViewController:childContentVC];
  childView =childContentVC.view;
  
  childContainer = [[UIView alloc] initWithFrame:childView.bounds];
  if (self.presentationStyle == NAModalSheetPresentationStyleFadeInCentered)
  {
    childContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
  }
  else if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromBottom || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderToolbar)
  {
    childContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
  }
  else if (self.presentationStyle == NAModalSheetPresentationStyleSlideInFromTop || self.presentationStyle == NAModalSheetPresentationStyleSlideInFromUnderNavBar)
  {
    childContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
  }
  else
  {
    // ??? unknown presentation style
    childContainer.autoresizingMask = UIViewAutoresizingNone;
  }

  childContainer.clipsToBounds = YES;
  childContainer.layer.cornerRadius = cornerRadius;
  childContainer.backgroundColor = [UIColor clearColor];
  [childContainerContainer addSubview:childContainer];
  
  if (!self.disableBlurredBackground)
  {
    // The blurred background container holds the blurred image of the screen snapshot. It's sized to fit the child view
    // and also sized to clip out a portion of the snapshot if the child view is sliding in from somewhere other than
    // the edge of the screen.
    blurredBackground = [[UIView alloc] initWithFrame:mainView.bounds];
    blurredBackground.clipsToBounds = YES;
    blurredBackground.layer.cornerRadius = cornerRadius;
    [childContainer addSubview:blurredBackground];
    
    blurredImageView = [[UIImageView alloc] initWithFrame:blurredBackground.bounds];
    blurredImageView.layer.cornerRadius = cornerRadius;
    [blurredBackground addSubview:blurredImageView];
  }

  // The child view itself gets added last so it sits on top.
  childView.frame = childContainer.bounds;
  childView.layer.cornerRadius = cornerRadius;
  [childContainer addSubview:childView]; // should already be sized to fit
  childView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  
  CGRect mainBounds = [self mainBoundsForOrientation:self.interfaceOrientation];
  self.view.frame = mainBounds;
  [self adjustFramesForBounds:mainBounds contentSize:childView.frame.size];
}

- (CGRect)mainBoundsForOrientation:(UIInterfaceOrientation)orientation
{
  CGRect mainBounds = myWindow.bounds;
  if (UIInterfaceOrientationIsLandscape(orientation))
  {
    CGFloat h = mainBounds.size.height;
    mainBounds.size.height = mainBounds.size.width;
    mainBounds.size.width = h;
  }
  
  return mainBounds;
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
  return !(CGRectContainsPoint(childContentVC.view.bounds, [touch locationInView:childContentVC.view]));
}

-(IBAction)backgroundTouched:(id)sender
{
  // Let the delegate know the user touched outside the child content area.
  if ([self.delegate respondsToSelector:@selector(modalSheetTouchedOutsideContent:)])
  {
    [self.delegate modalSheetTouchedOutsideContent:self];
  }
  else if (self.autoDismissWhenTouchedOutsideContent)
  {
    [self dismissWithCompletion:^{
      
    }];
  }
}

-(void)adjustContentSize:(CGSize)newSize animated:(BOOL)animated
{
  [self adjustFramesForBounds:self.view.bounds contentSize:newSize animated:YES];
}

-(void)presentWithCompletion:(void (^)(void))completion
{
  // Force my view to load now.
  if (self.view == nil)
    return;
  
  [modalSheets addObject:self];
  
  [myWindow makeKeyAndVisible];
  [myWindow setRootViewController:self];
  
  // Ensure frames are correct for current bounds after setting root view - otherwise orientation
  // changes mess this up.
  [self adjustFramesForBounds:self.view.bounds contentSize:childView.bounds.size animated:NO];
  
  // Take an immediate snapshot of the existing screen
  if (!self.disableBlurredBackground)
  {
    UIImage *snapshot = [UIImage screenshot];
    NSData *imageData = UIImageJPEGRepresentation(snapshot, 0.01);
    UIImage *blurredSnapshot = [[UIImage imageWithData:imageData] blurredImage:kBlurParameter];
    
    blurredImageView.image = blurredSnapshot;
  }
  
  // Make sure this is applied in case it changed between load and presentation.
  backgroundTint.backgroundColor = self.backgroundTintColor;

  // Position the child controller's view below the screen bottom (or above the top) if it's going to slide in.
  // This is its before-animation state.
  CGRect childContainerOrig = childContainer.frame;
  childContainer.frame = childHiddenFrame;
  
  // Position the blurred background view above the top or below the bottom edge of the
  // child container. At the same time the child view animates upward/downward, the blurred
  // background will animate downward/upward so the child view will appear to blur
  // the view behind it (for sliding presentations).
  CGRect blurredBackgroundOrig = blurredBackground.frame;
  blurredBackground.frame = blurHiddenFrame;
  
  if (self.presentationStyle == NAModalSheetPresentationStyleFadeInCentered)
  {
    self.view.alpha = 0.0;
    backgroundTint.alpha = 1.0;
  }
  else
  {
    self.view.alpha = 1.0;
    backgroundTint.alpha = 0.0;
  }
  
  // Present.
  [UIView animateWithDuration:self.animationDuration
                   animations:^{
                     childContainer.frame = childContainerOrig;
                     blurredBackground.frame = blurredBackgroundOrig;
                     backgroundTint.alpha = 1.0;
                     self.view.alpha = 1.0;
                   }
                   completion:^(BOOL finished) {
                     if (completion)
                     {
                       completion();
                     }
                   }];
}

- (void)dismissWithCompletion:(void (^)(void))completion
{
  NSUInteger sheetIndex = [modalSheets indexOfObject:self];
  NSAssert(sheetIndex != NSNotFound, @"Dismissing sheet not found in modalSheets");
  NSAssert(self == [modalSheets lastObject], @"Dismissing sheet not presented last");
  
  [modalSheets removeObject:self];
  
  // Animate the view away
  [UIView animateWithDuration:self.animationDuration
                   animations:^{
                     childContainer.frame = childHiddenFrame;
                     blurredBackground.frame = blurHiddenFrame;
                     backgroundTint.alpha = 0.0;
                     if (self.presentationStyle == NAModalSheetPresentationStyleFadeInCentered)
                     {
                       self.view.alpha = 0.0;
                     }
                   }
                   completion:^(BOOL finished) {
                     myWindow.hidden = YES;
                     myWindow = nil;
                     
                     // remove child view controller
                     [childContentVC.view removeFromSuperview];
                     [childContentVC removeFromParentViewController];
                     
                     // restore prev window key status
                     [prevWindow makeKeyAndVisible];
                     
                     if (completion)
                     {
                       completion();
                     }
                   }];
}

@end
