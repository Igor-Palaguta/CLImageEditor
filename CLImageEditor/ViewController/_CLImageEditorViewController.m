//
//  _CLImageEditorViewController.m
//
//  Created by sho yakushiji on 2013/11/05.
//  Copyright (c) 2013年 CALACULU. All rights reserved.
//

#import "_CLImageEditorViewController.h"

#import "CLImageToolBase.h"
#import "CLToolbarMenuItem.h"

@interface CLImageEditorAppearTransitioning: NSObject< UIViewControllerAnimatedTransitioning >

@property (nonatomic, strong) UIView* targetView;
@property (nonatomic, strong) UIImage* image;

-(instancetype)initWithTargetView:(UIView*)targetView image:(UIImage*)image;

@end

@interface CLImageEditorDisappearTransitioning: NSObject< UIViewControllerAnimatedTransitioning >

@property (nonatomic, strong) UIView* targetView;

-(instancetype)initWithTargetView:(UIView*)targetView;

@end

@implementation UINavigationBar (CLInheritAppearance)

-(void)cl_inheritAppearanceFromNavigationBar:(UINavigationBar*)navigationBar
{
    if (navigationBar)
    {
        [self setBackgroundImage: [navigationBar backgroundImageForBarMetrics: UIBarMetricsDefault]
                   forBarMetrics: UIBarMetricsDefault];

        self.shadowImage = navigationBar.shadowImage;
        self.translucent = navigationBar.translucent;
        self.barTintColor = navigationBar.barTintColor;
        self.backgroundColor = navigationBar.backgroundColor;
        self.titleTextAttributes = navigationBar.titleTextAttributes;
        self.tintColor = navigationBar.tintColor;
    }
}

@end

#pragma mark- _CLImageEditorViewController

@interface _CLImageEditorViewController()
<CLImageToolProtocol, UINavigationBarDelegate>

@property (nonatomic, weak) UINavigationBar *navigationBar;
@property (nonatomic, weak) UIScrollView *scrollView;

@property (nonatomic, strong) UIImage* originalImage;
@property (nonatomic, strong) CLImageToolBase *currentTool;
@property (nonatomic, strong, readwrite) CLImageToolInfo *toolInfo;
@property (nonatomic, assign) CGSize recentViewSize;
@end


@implementation _CLImageEditorViewController

@synthesize imageView = _imageView;
@synthesize toolInfo = _toolInfo;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.toolInfo = [CLImageToolInfo toolInfoForToolClass:[self class]];
    }
    return self;
}

- (id)init
{
    self = [self initWithNibName:nil bundle:nil];
    if (self){

    }
    return self;
}

- (id)initWithImage:(UIImage *)image
{
    return [self initWithImage:image delegate:nil];
}

- (id)initWithImage:(UIImage*)image delegate:(id<CLImageEditorDelegate>)delegate
{
    self = [self init];
    if (self){
        self.originalImage = image;
        self.delegate = delegate;
    }
    return self;
}

- (id)initWithDelegate:(id<CLImageEditorDelegate>)delegate
{
    self = [self init];
    if (self){
        self.delegate = delegate;
    }
    return self;
}

- (void)dealloc
{
    self.scrollView.delegate = nil;
    [self.navigationBar removeFromSuperview];
}

#pragma mark- Custom initialization

- (void)initNavigationBar
{
    UIBarButtonItem *rightBarButtonItem = nil;
    NSString *doneBtnTitle = [CLImageEditorTheme localizedString:@"CLImageEditor_DoneBtnTitle" withDefault:nil];

    if(![doneBtnTitle isEqualToString:@"CLImageEditor_DoneBtnTitle"]){
        rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:doneBtnTitle style:UIBarButtonItemStyleDone target:self action:@selector(pushedFinishBtn:)];
    }
    else{
        rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(pushedFinishBtn:)];
    }

    self.navigationItem.rightBarButtonItem = rightBarButtonItem;
    [self.navigationController setNavigationBarHidden:NO animated:NO];

    if(_navigationBar==nil){
        UINavigationItem *navigationItem  = [[UINavigationItem alloc] init];
        navigationItem.leftBarButtonItem  = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(pushedCloseBtn:)];
        navigationItem.rightBarButtonItem = rightBarButtonItem;

        CGFloat dy = ([UIDevice iosVersion]<7) ? 0 : MIN([UIApplication sharedApplication].statusBarFrame.size.height, [UIApplication sharedApplication].statusBarFrame.size.width);

        UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, dy, self.view.width, 44)];
        [navigationBar cl_inheritAppearanceFromNavigationBar: self.navigationController.navigationBar];
        [navigationBar pushNavigationItem:navigationItem animated:NO];
        navigationBar.delegate = self;

        if(self.navigationController){
            [self.navigationController.view addSubview:navigationBar];
        }
        else{
            [self.view addSubview:navigationBar];
        }
        _navigationBar = navigationBar;
    }

    if(self.navigationController!=nil){
        _navigationBar.frame  = self.navigationController.navigationBar.frame;
        _navigationBar.hidden = YES;
        [_navigationBar popNavigationItemAnimated:NO];
    }
    else{
        _navigationBar.topItem.title = self.title;
    }

    if([UIDevice iosVersion] < 7){
        _navigationBar.barStyle = UIBarStyleBlackTranslucent;
    }
}

- (void)initMenuScrollView
{
    if(self.menuView==nil){
        UIScrollView *menuScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 80)];
        menuScroll.top = self.view.height - menuScroll.height;
        menuScroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        menuScroll.showsHorizontalScrollIndicator = NO;
        menuScroll.showsVerticalScrollIndicator = NO;

        [self.view addSubview:menuScroll];
        self.menuView = menuScroll;
    }
    self.menuView.backgroundColor = [CLImageEditorTheme toolbarColor];
}

- (void)initImageScrollView
{
    if(self.scrollView==nil){
        UIScrollView *imageScroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
        imageScroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageScroll.showsHorizontalScrollIndicator = NO;
        imageScroll.showsVerticalScrollIndicator = NO;
        imageScroll.delegate = self;
        imageScroll.clipsToBounds = NO;

        CGFloat y = 0;
        if(self.navigationController){
            if(self.navigationController.navigationBar.translucent){
                y = self.navigationController.navigationBar.bottom;
            }
            y = ([UIDevice iosVersion] < 7) ? y-[UIApplication sharedApplication].statusBarFrame.size.height : y;
        }
        else{
            y = _navigationBar.bottom;
        }

        imageScroll.top = y;
        imageScroll.height = self.view.height - imageScroll.top - _menuView.height;

        [self.view insertSubview:imageScroll atIndex:0];
        self.scrollView = imageScroll;
    }
}

#pragma mark-
- (id<UIViewControllerAnimatedTransitioning>)presentTransitionFromView:(UIView*)view
{
    return [[CLImageEditorAppearTransitioning alloc] initWithTargetView:view image:self.originalImage];
}

- (id<UIViewControllerAnimatedTransitioning>)dismissTransitionToView:(UIView*)view
{
    return [[CLImageEditorDisappearTransitioning alloc] initWithTargetView:view];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = self.toolInfo.title;
    self.view.clipsToBounds = YES;
    self.view.backgroundColor = self.theme.backgroundColor;
    self.navigationController.view.backgroundColor = self.view.backgroundColor;

    if([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]){
        self.automaticallyAdjustsScrollViewInsets = NO;
    }

    if([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]){
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [ super viewWillAppear: animated ];

    if (!_navigationBar){
        [self initNavigationBar];
        [self initMenuScrollView];
        [self initImageScrollView];

        [self setMenuView];

        if(_imageView==nil){
            _imageView = [UIImageView new];
            [_scrollView addSubview:_imageView];
            [self refreshImageView];
        }
    }
}

#pragma mark- Properties

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.toolInfo.title = title;
}

#pragma mark- ImageTool setting

+ (NSString*)defaultIconImagePath
{
    return nil;
}

+ (CGFloat)defaultDockedNumber
{
    return 0;
}

+ (NSString*)defaultTitle
{
    return [CLImageEditorTheme localizedString:@"CLImageEditor_DefaultTitle" withDefault:@"Edit"];
}

+ (BOOL)isAvailable
{
    return YES;
}

+ (NSArray*)subtools
{
    return [CLImageToolInfo toolsWithToolClass:[CLImageToolBase class]];
}

+ (NSDictionary*)optionalInfo
{
    return nil;
}

#pragma mark-

- (void)setMenuView
{
    CGFloat x = 0;
    CGFloat W = 70;
    CGFloat H = _menuView.height;

    int toolCount = 0;
    CGFloat padding = 0;
    for(CLImageToolInfo *info in self.toolInfo.sortedSubtools){
        if(info.available){
            toolCount++;
        }
    }

    CGFloat diff = _menuView.frame.size.width - toolCount * W;
    if (0<diff && diff<2*W) {
        padding = diff/(toolCount+1);
    }

    for(CLImageToolInfo *info in self.toolInfo.sortedSubtools){
        if(!info.available){
            continue;
        }

        CLToolbarMenuItem *view = [CLImageEditorTheme menuItemWithFrame:CGRectMake(x+padding, 0, W, H) target:self action:@selector(tappedMenuView:) toolInfo:info];
        [_menuView addSubview:view];
        x += W+padding;
    }
    _menuView.contentSize = CGSizeMake(MAX(x, _menuView.frame.size.width+1), 0);
}

- (void)resetImageViewFrame
{
    CGSize size = (_imageView.image) ? _imageView.image.size : _imageView.frame.size;
    if(size.width>0 && size.height>0){
        CGFloat ratio = MIN(_scrollView.frame.size.width / size.width, _scrollView.frame.size.height / size.height);
        CGFloat W = ratio * size.width * _scrollView.zoomScale;
        CGFloat H = ratio * size.height * _scrollView.zoomScale;

        _imageView.frame = CGRectMake(MAX(0, (_scrollView.width-W)/2), MAX(0, (_scrollView.height-H)/2), W, H);
    }
}

- (void)fixZoomScaleWithAnimated:(BOOL)animated
{
    CGFloat minZoomScale = _scrollView.minimumZoomScale;
    _scrollView.maximumZoomScale = 0.95*minZoomScale;
    _scrollView.minimumZoomScale = 0.95*minZoomScale;
    [_scrollView setZoomScale:_scrollView.minimumZoomScale animated:animated];
}

- (void)resetZoomScaleWithAnimated:(BOOL)animated
{
    CGFloat Rw = _scrollView.frame.size.width / _imageView.frame.size.width;
    CGFloat Rh = _scrollView.frame.size.height / _imageView.frame.size.height;

    //CGFloat scale = [[UIScreen mainScreen] scale];
    CGFloat scale = 1;
    Rw = MAX(Rw, _imageView.image.size.width / (scale * _scrollView.frame.size.width));
    Rh = MAX(Rh, _imageView.image.size.height / (scale * _scrollView.frame.size.height));

    _scrollView.contentSize = _imageView.frame.size;
    _scrollView.minimumZoomScale = 1;
    _scrollView.maximumZoomScale = MAX(MAX(Rw, Rh), 1);

    [_scrollView setZoomScale:_scrollView.minimumZoomScale animated:animated];
}

- (void)refreshImageView
{
    _imageView.image = _originalImage;

    [self resetImageViewFrame];
    [self resetZoomScaleWithAnimated:NO];
}

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar
{
    return UIBarPositionTopAttached;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return [[CLImageEditorTheme theme] statusBarStyle];
}

#pragma mark- Tool actions

- (void)setCurrentTool:(CLImageToolBase *)currentTool
{
    if(currentTool != _currentTool){
        [_currentTool cleanup];
        _currentTool = currentTool;
        [_currentTool setup];

        [self swapToolBarWithEditting:(_currentTool!=nil)];
    }
}

#pragma mark- Menu actions

- (void)swapMenuViewWithEditting:(BOOL)editting
{
    [UIView animateWithDuration:kCLImageToolAnimationDuration
                     animations:^{
                         if(editting){
                             _menuView.transform = CGAffineTransformMakeTranslation(0, self.view.height-_menuView.top);
                         }
                         else{
                             _menuView.transform = CGAffineTransformIdentity;
                         }
                     }
     ];
}

- (void)swapNavigationBarWithEditting:(BOOL)editting
{
    if(self.navigationController==nil){
        return;
    }

    if(editting){
        _navigationBar.hidden = NO;
        _navigationBar.transform = CGAffineTransformMakeTranslation(0, -_navigationBar.height);

        [UIView animateWithDuration:kCLImageToolAnimationDuration
                         animations:^{
                             self.navigationController.navigationBar.transform = CGAffineTransformMakeTranslation(0, -self.navigationController.navigationBar.height-20);
                             _navigationBar.transform = CGAffineTransformIdentity;
                         }
         ];
    }
    else{
        [UIView animateWithDuration:kCLImageToolAnimationDuration
                         animations:^{
                             self.navigationController.navigationBar.transform = CGAffineTransformIdentity;
                             _navigationBar.transform = CGAffineTransformMakeTranslation(0, -_navigationBar.height);
                         }
                         completion:^(BOOL finished) {
                             _navigationBar.hidden = YES;
                             _navigationBar.transform = CGAffineTransformIdentity;
                         }
         ];
    }
}

- (void)swapToolBarWithEditting:(BOOL)editting
{
    [self swapMenuViewWithEditting:editting];
    [self swapNavigationBarWithEditting:editting];

    if(self.currentTool){
        UINavigationItem *item  = [[UINavigationItem alloc] initWithTitle:self.currentTool.toolInfo.title];
        item.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[CLImageEditorTheme localizedString:@"CLImageEditor_OKBtnTitle" withDefault:@"OK"] style:UIBarButtonItemStyleDone target:self action:@selector(pushedDoneBtn:)];
        item.leftBarButtonItem  = [[UIBarButtonItem alloc] initWithTitle:[CLImageEditorTheme localizedString:@"CLImageEditor_BackBtnTitle" withDefault:@"Back"] style:UIBarButtonItemStylePlain target:self action:@selector(pushedCancelBtn:)];

        [_navigationBar pushNavigationItem:item animated:(self.navigationController==nil)];
    }
    else{
        [_navigationBar popNavigationItemAnimated:(self.navigationController==nil)];
    }
}

- (void)setupToolWithToolInfo:(CLImageToolInfo*)info
{
    if(self.currentTool){ return; }

    Class toolClass = NSClassFromString(info.toolName);

    if(toolClass){
        id instance = [toolClass alloc];
        if(instance!=nil && [instance isKindOfClass:[CLImageToolBase class]]){
            instance = [instance initWithImageEditor:self withToolInfo:info];
            self.currentTool = instance;
        }
    }
}

- (void)tappedMenuView:(UITapGestureRecognizer*)sender
{
    [self selectMenuItemView: sender.view];
}

- (void)selectMenuItemView:(UIView*)itemView
{
    itemView.alpha = 0.2;
    [UIView animateWithDuration:kCLImageToolAnimationDuration
                     animations:^{
                         itemView.alpha = 1;
                     }
     ];

    [self setupToolWithToolInfo:itemView.toolInfo];
}

- (void)selectMenuItemWithToolName:(NSString*)toolName
{
    for (UIView* subview in self.menuView.subviews)
    {
        if (![subview isKindOfClass: [CLToolbarMenuItem class]])
            continue;

        CLToolbarMenuItem* itemView = (CLToolbarMenuItem*)subview;
        if ([itemView.toolInfo.toolName isEqualToString:toolName])
        {
            [self selectMenuItemView:itemView];
        }
    }
}

- (IBAction)pushedCancelBtn:(id)sender
{
    _imageView.image = _originalImage;
    [self resetImageViewFrame];

    self.currentTool = nil;
}

- (IBAction)pushedDoneBtn:(id)sender
{
    self.view.userInteractionEnabled = NO;

    [self.currentTool executeWithCompletionBlock:^(UIImage *image, NSError *error, NSDictionary *userInfo) {
        if(error){
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
        else if(image){
            _originalImage = image;
            _imageView.image = image;

            [self resetImageViewFrame];
            self.currentTool = nil;
        }
        self.view.userInteractionEnabled = YES;
    }];
}

- (void)pushedCloseBtn:(id)sender
{
    if([self.delegate respondsToSelector:@selector(imageEditorDidCancel:)]){
        [self.delegate imageEditorDidCancel:self];
    }
    else{
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pushedFinishBtn:(id)sender
{
    if([self.delegate respondsToSelector:@selector(imageEditor:didFinishEdittingWithImage:)]){
        [self.delegate imageEditor:self didFinishEdittingWithImage:_originalImage];
    }
    else{
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark- ScrollView delegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return _imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    CGFloat Ws = _scrollView.frame.size.width - _scrollView.contentInset.left - _scrollView.contentInset.right;
    CGFloat Hs = _scrollView.frame.size.height - _scrollView.contentInset.top - _scrollView.contentInset.bottom;
    CGFloat W = _imageView.frame.size.width;
    CGFloat H = _imageView.frame.size.height;

    CGRect rct = _imageView.frame;
    rct.origin.x = MAX((Ws-W)/2, 0);
    rct.origin.y = MAX((Hs-H)/2, 0);
    _imageView.frame = rct;
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if(!CGSizeEqualToSize(self.recentViewSize, self.view.frame.size)){
        [self refreshImageView];
        self.recentViewSize = self.view.frame.size;
    }
}

@end

@implementation UIView (CLCopyViewInfo)

- (void)copyInfoToView:(UIView*)toView
{
    CGAffineTransform transform = self.transform;
    self.transform = CGAffineTransformIdentity;

    toView.transform = CGAffineTransformIdentity;
    toView.frame = [toView.superview convertRect:self.frame fromView:self.superview];
    toView.transform = transform;
    toView.clipsToBounds = self.clipsToBounds;

    self.transform = transform;
}

@end

@implementation CLImageEditorDisappearTransitioning

-(instancetype)initWithTargetView:(UIImageView*)targetView
{
    self = [super init];
    if (self){
        self.targetView = targetView;
    }
    return self;
}

-(NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return kCLImageToolAnimationDuration;
}

-(void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    _CLImageEditorViewController* editorController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];

    UIViewController* toController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];

    [transitionContext.containerView insertSubview: toController.view
                                      belowSubview: editorController.view];

    UIImageView *animateView = [[UIImageView alloc] initWithImage: editorController.originalImage];
    [transitionContext.containerView addSubview:animateView];
    [editorController.imageView copyInfoToView: animateView];
    animateView.contentMode = UIViewContentModeScaleAspectFill;

    self.targetView.hidden = YES;

    editorController.view.userInteractionEnabled = NO;
    editorController.imageView.hidden = YES;

    [UIView animateWithDuration:[self transitionDuration: transitionContext]
                     animations:^{
                         [self.targetView copyInfoToView:animateView];

                         editorController.view.backgroundColor = [UIColor clearColor];
                         editorController.menuView.alpha = 0;
                         editorController.navigationBar.alpha = 0;

                         editorController.menuView.transform = CGAffineTransformMakeTranslation(0, editorController.view.height-editorController.menuView.top);
                         editorController.navigationBar.transform = CGAffineTransformMakeTranslation(0, -editorController.navigationBar.height);
                     }
                     completion:^(BOOL finished) {
                         [animateView removeFromSuperview];
                         editorController.imageView.hidden = NO;
                         self.targetView.hidden = NO;
                         [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
                     }
     ];
}

@end

@implementation CLImageEditorAppearTransitioning

-(instancetype)initWithTargetView:(UIView*)targetView
                            image:(UIImage*)image
{
    self = [super init];
    if (self){
        self.targetView = targetView;
        self.image = image;
    }
    return self;
}

-(NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return kCLImageToolAnimationDuration;
}

-(void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    _CLImageEditorViewController* editorController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];

    UIViewController* fromController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];

    editorController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    editorController.view.frame = [transitionContext finalFrameForViewController: editorController];

    [transitionContext.containerView insertSubview: editorController.view
                                      aboveSubview: fromController.view];

    [editorController refreshImageView];
    UIImageView *animateView = [UIImageView new];
    [transitionContext.containerView addSubview:animateView];
    [self.targetView copyInfoToView:animateView];
    animateView.clipsToBounds = YES;
    animateView.contentMode = UIViewContentModeScaleAspectFill;
    animateView.image = self.image;

    self.targetView.hidden = YES;
    editorController.imageView.hidden = YES;
    editorController.navigationBar.transform = CGAffineTransformMakeTranslation(0, -editorController.navigationBar.bounds.size.height);
    editorController.menuView.transform = CGAffineTransformMakeTranslation(0, editorController.view.height-editorController.menuView.top);
    editorController.view.backgroundColor = [editorController.view.backgroundColor colorWithAlphaComponent:0];

    [UIView animateWithDuration:[self transitionDuration:transitionContext]
                     animations:^{
                         [editorController.imageView copyInfoToView: animateView];
                         editorController.view.backgroundColor = editorController.theme.backgroundColor;
                         editorController.navigationBar.transform = CGAffineTransformIdentity;
                         editorController.menuView.transform = CGAffineTransformIdentity;
                     }
                     completion:^(BOOL finished) {
                         self.targetView.hidden = NO;
                         editorController.imageView.hidden = NO;
                         [animateView removeFromSuperview];
                         [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
                     }
     ];
}

@end
