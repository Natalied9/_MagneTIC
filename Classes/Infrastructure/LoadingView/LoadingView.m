//
//  LoadingView.m
//

#import "LoadingView.h"
#import "UIView+LayerManagement.h"
#import "UIColor+hexColor.h"

@interface LoadingView ()

//UIMotion Effects
@property(nonatomic, strong) UIMotionEffectGroup *motionEffects;

@property (nonatomic, strong) UIView *indicatorPlaceholder;
@property (nonatomic, strong) UIActivityIndicatorView *aIndicator;
@property (nonatomic, strong) UILabel *lText;

@property (nonatomic, assign) BOOL operating;

@end

@implementation LoadingView

@synthesize indicatorPlaceholder = _indicatorPlaceholder;
@synthesize aIndicator = _aIndicator;
@synthesize lText = _lText;
@synthesize motionEffects = _motionEffects;
@synthesize operating = _operating;

#pragma mark - Lifecycle

- (instancetype)initWithView:(UIView *)view text:(NSString *)text
{
    self = [self initWithFrame:view.bounds];
    if (nil == self)
    {
        return nil;
    }
    
    [self createInfrastructure];
    [view addSubview:self];

    [self updateText:text];
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (nil == self)
    {
        return nil;
    }

    [self createInfrastructure];
    return self;
}

#pragma mark - Public class logic

- (void)start
{
    if (self.operating)
    {
        return;
    }
        
    self.operating = YES;
    
    [self.aIndicator startAnimating];
	self.hidden = NO;
	[UIView animateWithDuration:0.3 animations:^{
		self.indicatorPlaceholder.alpha = 0.6;
	}];
}

- (void)stopAndDismiss
{
    if (!self.operating)
    {
        return;
    }
	
    [self.aIndicator stopAnimating];
	
	[UIView animateWithDuration:0.3 animations:^{
		self.indicatorPlaceholder.alpha = 0;
	} completion:^(BOOL finished) {
		#pragma unused(finished)
		self.hidden = YES;
		[self removeFromSuperview];
	}];
	
    self.operating = NO;
}

- (void)updateText:(NSString *)text
{
    self.lText.text = text;
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (BOOL)isOperating
{
    return self.operating;
}

#pragma mark - Private class logic

- (void)createInfrastructure
{
	[self setupMotionEffects];
	
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
    [v setCornerRadius:15.];
    [v setBackgroundColor:[UIColor colorFromHEXString:@"#323232"]];
    [v setAlpha:0];
    [self addSubview:v];
    self.indicatorPlaceholder = v;
    
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.textAlignment = NSTextAlignmentCenter;
    l.numberOfLines = 0;
    l.font = [UIFont boldSystemFontOfSize:14.0];
    l.textColor = [UIColor colorFromHEXString:@"#FFFFFF"];
    [self.indicatorPlaceholder addSubview:l];
    self.lText = l;
    
    UIActivityIndicatorView *ai = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.indicatorPlaceholder addSubview:ai];
    self.aIndicator = ai;
    
    self.hidden = YES;
    self.operating = NO;
}

- (void)setupMotionEffects
{
	UIInterpolatingMotionEffect *horisontalEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
	horisontalEffect.maximumRelativeValue = @20;
	horisontalEffect.minimumRelativeValue = @-20;
	
	UIInterpolatingMotionEffect *verticalEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
	verticalEffect.minimumRelativeValue = @-20;
	verticalEffect.maximumRelativeValue = @20;
	
	self.motionEffects = [[UIMotionEffectGroup alloc] init];
	self.motionEffects.motionEffects = @[horisontalEffect,verticalEffect];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect viewRect = self.bounds;
    
    // Find the size of label text.
    CGRect desiredRect = [self.lText.text boundingRectWithSize:CGSizeMake(viewRect.size.width - 40., 300.) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:14.] } context:nil];
    if (desiredRect.size.height < 30.)
    {
        desiredRect.size.height = 30.;
    }
    
    CGRect frm = self.indicatorPlaceholder.frame;
    frm.size.width = desiredRect.size.width + 20.;
    frm.size.height = viewRect.size.height - 40.;
    frm.origin.x = (viewRect.size.width - frm.size.width) / 2.;
    frm.origin.y = (viewRect.size.height - frm.size.height) / 2.;
    self.indicatorPlaceholder.frame = frm;
    
    frm = self.lText.frame;
    frm.size.width = desiredRect.size.width;
    frm.size.height = desiredRect.size.height;
    frm.origin.x = (self.indicatorPlaceholder.frame.size.width - frm.size.width) / 2.;
    frm.origin.y = 10.;
    self.lText.frame = frm;
    
    frm = self.aIndicator.frame;
    frm.origin.x = (self.indicatorPlaceholder.frame.size.width - frm.size.width) / 2.;
    frm.origin.y = self.lText.frame.origin.y + self.lText.frame.size.height + 10.;
    self.aIndicator.frame = frm;
    
    // Correct height for indicatorPlaceholder view
    frm = self.indicatorPlaceholder.frame;
    frm.size.height = self.lText.frame.size.height + self.aIndicator.frame.size.height + 30.;
    frm.origin.y = (viewRect.size.height - frm.size.height) / 2.;
    self.indicatorPlaceholder.frame = frm;
}

-(void)setIndicatorPlaceholder:(UIView *)indicatorPlaceholder
{
	_indicatorPlaceholder = indicatorPlaceholder;
	[_indicatorPlaceholder addMotionEffect:self.motionEffects];
}

@end
