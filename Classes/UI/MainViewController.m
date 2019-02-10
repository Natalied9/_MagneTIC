//
//  MainViewController.h
//

#import "MainViewController.h"
#import "WebProjectInfo.h"

#import <AVFoundation/AVFoundation.h>

@interface MainViewController ()

@property (nonatomic, strong, readwrite) WebProjectInfo *projectInfo;

@property (nonatomic, assign) BOOL initializeCompleted;
@property (nonatomic, strong) NSURLRequest *delayedRequest;

@end

@implementation MainViewController

@synthesize projectInfo = _projectInfo;

@synthesize initializeCompleted = _initializeCompleted;
@synthesize delayedRequest = _delayedRequest;

#pragma mark - Lifecycle

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self == nil)
    {
        return nil;
    }
    
    _projectInfo = [[WebProjectInfo alloc] init];
    _initializeCompleted = NO;
    _delayedRequest = nil;
    
    return self;
}

- (instancetype)init
{
    return [self initWithNibName:nil bundle:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - View lifecycle

- (void)viewWillAppear:(BOOL)animated
{
    // View defaults to full size.  If you want to customize the view's size, or its subviews (e.g. webView),
    // you can do so here.
    
    [super viewWillAppear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self allowBackgroundAudioPlay];
    
    self.initializeCompleted = YES;
    if(self.delayedRequest != nil)
    {
        [self.webView loadRequest:self.delayedRequest];
        self.delayedRequest = nil;
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

#pragma mark - Override CDVViewController methods

- (NSArray *)parseInterfaceOrientations:(NSArray *)orientations
{
    if ((orientations == nil) || ([orientations count] == 0))
    {
        NSString* orientationString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UIInterfaceOrientation"];
        
        if (orientationString)
        {
            orientations = [NSArray arrayWithObject:orientationString];
        }
    }
    
    return [super parseInterfaceOrientations:orientations];
}

- (NSString *)wwwFolderName
{
    // If auto update not enabled use standard folder
    return [self.projectInfo.autoupdateEnabled boolValue] ? [self.projectInfo.folderURL copy] : [[super wwwFolderName] copy];
}

- (NSString *)startPage
{
    // If auto update not enabled use standard start page
    return [self.projectInfo.autoupdateEnabled boolValue] ? [self.projectInfo.startPageName copy] : [[super startPage] copy];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)theWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if(self.initializeCompleted)
    {
        return [super webView:theWebView shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    
    self.delayedRequest = request;
    return NO;
}

- (void)webView:(UIWebView*)theWebView didFailLoadWithError:(NSError*)error
{
    return [super webView:theWebView didFailLoadWithError:error];
}

#pragma mark - Utility methods

- (void)allowBackgroundAudioPlay
{
    NSError *setBackgroundAudioPlayError = nil;
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&setBackgroundAudioPlayError];
    if (setBackgroundAudioPlayError != nil)
    {
        NSLog(@"Cannot activate audio background playing due to error: %@.", setBackgroundAudioPlayError);
        return;
    }
}

@end
