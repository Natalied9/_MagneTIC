//
//  SetupViewController.m
//

#import "SetupViewController.h"
#import "NSObject+Utils.h"
#import "DeviceModelInfo.h"
#import "UIDevice+System.h"

@interface SetupViewController ()

@property (nonatomic, weak) IBOutlet UIImageView* ivImage;

@end

@implementation SetupViewController

@synthesize ivImage = _ivImage;

#pragma mark - Lifecycle

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self == nil)
    {
        return nil;
    }
    
    return self;
}

#pragma mark - View management

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.autoresizesSubviews = NO;
    self.ivImage.image = [self properImageForCurrentDevice];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    UIImage* img = self.ivImage.image;
    CGRect __block imgBounds = (img) ? CGRectMake(0, 0, img.size.width, img.size.height) : CGRectZero;
    
    CGSize screenSize = [self.view convertRect:[UIScreen mainScreen].bounds fromView:nil].size;
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    CGAffineTransform imgTransform = CGAffineTransformIdentity;
    
    if (UIInterfaceOrientationIsLandscape(orientation) && !(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad))
    {
        imgTransform = CGAffineTransformMakeRotation(M_PI / 2);
        imgBounds.size = CGSizeMake(imgBounds.size.height, imgBounds.size.width);
    }
    
    if (CGSizeEqualToSize(screenSize, imgBounds.size))
    {
        CGRect statusFrame = [self.view convertRect:[UIApplication sharedApplication].statusBarFrame fromView:nil];
        [UIDevice executeUnderIOS7AndHigher:^{
            imgBounds.origin.y -= statusFrame.size.height;
        }];
    }
    else if (imgBounds.size.width > 0)
    {
        CGRect viewBounds = self.view.bounds;
        CGFloat imgAspect = imgBounds.size.width / imgBounds.size.height;
        CGFloat viewAspect = viewBounds.size.width / viewBounds.size.height;
        CGFloat ratio;
        if (viewAspect > imgAspect)
        {
            ratio = viewBounds.size.width / imgBounds.size.width;
        }
        else
        {
            ratio = viewBounds.size.height / imgBounds.size.height;
        }
        imgBounds.size.height *= ratio;
        imgBounds.size.width *= ratio;
    }
    
    self.ivImage.transform = imgTransform;
    self.ivImage.frame = imgBounds;
}

- (BOOL)shouldAutorotate {
    return NO;
}

#pragma mark - Private class logic

- (UIImage *)properImageForCurrentDevice
{
    NSString *imageName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UILaunchImageFile"];
    NSUInteger supportedOrientations = [self supportedInterfaceOrientations];
    
    BOOL supportsLandscape = (supportedOrientations & UIInterfaceOrientationMaskLandscape);
    BOOL supportsPortrait = (supportedOrientations & UIInterfaceOrientationMaskPortrait || supportedOrientations & UIInterfaceOrientationMaskPortraitUpsideDown);

    BOOL isOrientationLocked = !(supportsPortrait && supportsLandscape);
    
    if (imageName.length > 0)
    {
        imageName = [imageName stringByDeletingPathExtension];
    }
    else
    {
        imageName = @"Default";
    }
    
    if ([[DeviceModelInfo iPhone5Family] boolValue])
    {
        imageName = [imageName stringByAppendingString:@"-568h"];
    }
    else if ([[DeviceModelInfo iPhone6] boolValue])
    {
        imageName = [imageName stringByAppendingString:@"-667h"];
    }
    else if ([[DeviceModelInfo iPhone6Plus] boolValue])
    {
        if (isOrientationLocked)
        {
            imageName = [imageName stringByAppendingString:(supportsLandscape ? @"-Landscape" : @"")];
        }
        else
        {
            switch (self.interfaceOrientation)
            {
                case UIInterfaceOrientationLandscapeLeft:
                case UIInterfaceOrientationLandscapeRight:
                    imageName = [imageName stringByAppendingString:@"-Landscape"];
                    break;
                default:
                    break;
            }
        }
        imageName = [imageName stringByAppendingString:@"-736h"];
        
    }
    else if ([[DeviceModelInfo iPadFamily] boolValue] || [[DeviceModelInfo iPadRetinaFamily] boolValue])
    {
        if (isOrientationLocked)
        {
            imageName = [imageName stringByAppendingString:(supportsLandscape ? @"-Landscape" : @"-Portrait")];
        }
        else
        {
            switch (self.interfaceOrientation)
            {
                case UIInterfaceOrientationLandscapeLeft:
                case UIInterfaceOrientationLandscapeRight:
                    imageName = [imageName stringByAppendingString:@"-Landscape"];
                    break;
                    
                case UIInterfaceOrientationPortrait:
                case UIInterfaceOrientationPortraitUpsideDown:
                default:
                    imageName = [imageName stringByAppendingString:@"-Portrait"];
                    break;
            }
        }
    }
    
    if (imageName.length == 0)
    {
        return nil;
    }
    return [UIImage imageNamed:imageName];
}

@end
