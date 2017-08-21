//
//  RounteViewController.m
//  SoudNavigation
//
//  Created by ChangWingchit on 16/1/26.
//  Copyright © 2016年 ChangWingchit. All rights reserved.
//

#import "RounteViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "MBProgressHUD+NJ.h"

@interface RounteViewController ()

@end

@implementation RounteViewController

#pragma mark - Init
- (instancetype)initWithOrigin:(Positon*)origin end:(Positon*)end travel:(TravelType)travel {
    if (self = [super init]) {
        self.origin = origin;
        self.end = end;
        self.travel = travel;
    }
    return self;
}

#pragma mark - Life Cycle
- (void)dealloc
{
    //移除驾车导航
    [self.driveManager stopNavi];
    [self.driveView removeFromSuperview];
    self.driveView = nil;
    self.driveManager = nil;
    
    //移除步行导航
    [self.walkManager stopNavi];
    [self.walkView removeFromSuperview];
    self.walkView = nil;
    self.walkManager = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //设置导航栏
    [self setupNavigationBar];
    
    //设置子视图
    [self setupSubViews];
    
    //设置导航视图
    if (self.travel == TravelTypeCar) {
        [self initDriveView];
    }else{
        [self initWalkView];
    }
    //配置高德导航
    [self configNaviServices];
    //配置科大讯飞语音
    [self configIFlySpeech];
    //添加大头针(起始的，目标的)
    [self addAnnotation];
    //开始路径规划
    [self routeCal];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    //移除大头针
    [self.mapView removeAnnotations:self.mapView.annotations];
    //移除地图上规划路线路线
    [self.mapView removeOverlays:self.mapView.overlays];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private Method
/**设置导航栏*/
- (void)setupNavigationBar
{
    self.title = @"交通路线导航";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    UIBarButtonItem *leftItem = [UIBarButtonItem itemWithTarget:self action:@selector(leftItemClicked:) image:@"tongyong_back-button" selectImage:nil];
    UIBarButtonItem *negativeSpacer = [[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                       target:nil action:nil];
    negativeSpacer.width = -5;
    self.navigationItem.leftBarButtonItems = @[negativeSpacer,leftItem];
}

/**导航栏左边按钮点解时间*/
- (void)leftItemClicked:(UIBarButtonItem*)item
{
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView removeOverlays:self.mapView.overlays];
    self.mapView.delegate = nil;
    [self.navigationController popViewControllerAnimated:YES];
}

/**设置子视图*/
- (void)setupSubViews
{
    //创建高德地图
    self.mapView = [[MAMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height-50);
    self.mapView.showsUserLocation = NO;//不自动定位
    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];
    
    //模拟导航按钮
    UIButton *simuBtn = [self createButton:CGRectMake(10, self.mapView.height+5-64, self.view.bounds.size.width/2-15, 40)];
    [simuBtn setTitle:@"模拟导航" forState:UIControlStateNormal];
    [simuBtn addTarget:self action:@selector(simulatorNavi) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:simuBtn];
    
    //实时导航按钮
    UIButton *gpsBtn = [self createButton:CGRectMake(self.view.bounds.size.width-simuBtn.frame.size.width-10, simuBtn.frame.origin.y, simuBtn.frame.size.width, simuBtn.frame.size.height)];
    [gpsBtn setTitle:@"实时导航" forState:UIControlStateNormal];
    [gpsBtn addTarget:self action:@selector(gpsNavi) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:gpsBtn];
}

/**创建按钮*/
- (UIButton *)createButton:(CGRect)rect {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = rect;
    btn.backgroundColor = [UIColor colorWithRed:0.08 green:0.57 blue:0.57 alpha:1.00];
    btn.layer.cornerRadius = 5;
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize: 16.0];
    return btn;
}

/**创建导航视图*/
- (void)initDriveView
{
    if (self.driveView == nil)
    {
        self.driveView = [[AMapNaviDriveView alloc] initWithFrame:CGRectMake(0, -44, SCREEN_WIDTH, SCREEN_HEIGHT+44)];
        self.driveView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self.driveView setDelegate:self];
        [self.view addSubview:self.driveView];
        self.driveView.hidden = YES;
    }
}

- (void)initWalkView
{
    if (self.walkView == nil)
    {
        self.walkView = [[AMapNaviWalkView alloc] initWithFrame:CGRectMake(0, -44, SCREEN_WIDTH, SCREEN_HEIGHT+44)];
        self.walkView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self.walkView setDelegate:self];
        [self.view addSubview:self.walkView];
        self.walkView.hidden = YES;
    }
}

/**配置高德导航*/
- (void)configNaviServices {
    
    [AMapServices sharedServices].apiKey = (NSString *)APIKey;
    [AMapServices sharedServices].enableHTTPS = YES;
    
    if (self.travel == TravelTypeCar) {
        //创建车载地图导航管理器
        if (self.driveManager == nil)
        {
            self.driveManager = [[AMapNaviDriveManager alloc] init];
            [self.driveManager setDelegate:self];
            
            [self.driveManager setAllowsBackgroundLocationUpdates:YES];
            [self.driveManager setPausesLocationUpdatesAutomatically:NO];
            
            //将driveView添加为导航数据的Representative，使其可以接收到导航诱导数据
            [self.driveManager addDataRepresentative:self.driveView];
        }
    }else{
        if (self.walkManager == nil) {
            self.walkManager = [[AMapNaviWalkManager alloc]init];
            [self.walkManager setDelegate:self];
            
            [self.walkManager setAllowsBackgroundLocationUpdates:YES];
            [self.walkManager setPausesLocationUpdatesAutomatically:NO];
            
            //将driveView添加为导航数据的Representative，使其可以接收到导航诱导数据
            [self.walkManager addDataRepresentative:self.walkView];
        }
    }
}

/**配置科大讯飞语音*/
- (void)configIFlySpeech {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [IFlySpeechUtility createUtility:[NSString stringWithFormat:@"appid=%@,timeout=%@",@"5565399b",@"20000"]];
        
        [IFlySetting setLogFile:LVL_NONE];
        [IFlySetting showLogcat:NO];
        
        // 设置语音合成的参数
        [[IFlySpeechSynthesizer sharedInstance] setParameter:@"50" forKey:[IFlySpeechConstant SPEED]];//合成的语速,取值范围 0~100
        [[IFlySpeechSynthesizer sharedInstance] setParameter:@"50" forKey:[IFlySpeechConstant VOLUME]];//合成的音量;取值范围 0~100
        
        // 发音人,默认为”xiaoyan”;可以设置的参数列表可参考个 性化发音人列表;
        [[IFlySpeechSynthesizer sharedInstance] setParameter:@"xiaoyan" forKey:[IFlySpeechConstant VOICE_NAME]];
        
        // 音频采样率,目前支持的采样率有 16000 和 8000;
        [[IFlySpeechSynthesizer sharedInstance] setParameter:@"8000" forKey:[IFlySpeechConstant SAMPLE_RATE]];
        
        // 当你再不需要保存音频时，请在必要的地方加上这行。
        [[IFlySpeechSynthesizer sharedInstance] setParameter:nil forKey:[IFlySpeechConstant TTS_AUDIO_PATH]];
        
        //创建语音合成
        self.iFlySpeechSynthesizer = [IFlySpeechSynthesizer sharedInstance];
        self.iFlySpeechSynthesizer.delegate = self;
    });
}

/**添加大头针(起始的，目标的)*/
- (void)addAnnotation {
    MAPointAnnotation *beginAnnotation = [[MAPointAnnotation alloc] init];
    beginAnnotation.coordinate = CLLocationCoordinate2DMake(self.origin.navi.latitude, self.origin.navi.longitude);
    beginAnnotation.title = self.origin.title;
    [self.mapView addAnnotation:beginAnnotation];
    
    MAPointAnnotation *endAnnotation = [[MAPointAnnotation alloc] init];
    endAnnotation.coordinate = CLLocationCoordinate2DMake(self.end.navi.latitude, self.end.navi.longitude);
    endAnnotation.title = self.end.title;
    [self.mapView addAnnotation:endAnnotation];
}

/**根据 路线模式 开始路径规划*/
- (void)routeCal {
    NSArray *startPoints = @[self.origin.navi];
    NSArray *endPoints   = @[self.end.navi];
    
    if (self.travel == TravelTypeCar) {
        [self.driveManager calculateDriveRouteWithStartPoints:startPoints
                                                    endPoints:endPoints
                                                    wayPoints:nil
                                              drivingStrategy:0];
    } else {
        [self.walkManager calculateWalkRouteWithStartPoints:startPoints
                                                  endPoints:endPoints];
    }
}

/**显示两点之间的路线*/
- (void)showRouteWithNaviRoute:(AMapNaviRoute *)naviRoute {
    if (naviRoute != nil) {
        [self.mapView removeOverlays:self.mapView.overlays];// 清除旧的overlays
        //画线
        NSUInteger coordianteCount = [naviRoute.routeCoordinates count];
        CLLocationCoordinate2D coordinates[coordianteCount];
        for (int i = 0; i < coordianteCount; i++)
        {
            AMapNaviPoint *aCoordinate = [naviRoute.routeCoordinates objectAtIndex:i];
            coordinates[i] = CLLocationCoordinate2DMake(aCoordinate.latitude, aCoordinate.longitude);
        }
        
        MAPolyline *polyline = [MAPolyline polylineWithCoordinates:coordinates count:coordianteCount];
        [self.mapView addOverlay:polyline];
        
        self.mapView.visibleMapRect = polyline.boundingMapRect;//显示画线区域
        if (self.mapView.zoomLevel >= 10) {//设置地图放大比例用于显示完整的大头针
            [self.mapView setZoomLevel:self.mapView.zoomLevel-0.5 animated:NO];
        }
    }
}

#pragma mark - Button Method
/**模拟导航*/
- (void)simulatorNavi {
    self.naviType = NavigationTypeSimulator;
    self.navigationController.navigationBar.hidden = YES;
    //添加导航视图
    if (self.travel == TravelTypeCar) {
        [self.driveManager startEmulatorNavi];
        [self.driveManager addDataRepresentative:self.driveView];
        self.driveView.hidden = NO;
    }else{
        [self.walkManager startEmulatorNavi];
        [self.walkManager addDataRepresentative:self.walkView];
        self.walkView.hidden = NO;
    }
}

/**实时导航*/
- (void)gpsNavi {
    self.naviType = NavigationTypeGPS;
    self.navigationController.navigationBar.hidden = YES;
    if (self.travel == TravelTypeCar) {
        [self.driveManager startGPSNavi];
        [self.driveManager addDataRepresentative:self.driveView];
        self.driveView.hidden = NO;
    }else{
        [self.walkManager startGPSNavi];
        [self.walkManager addDataRepresentative:self.walkView];
        self.walkView.hidden = NO;
    }
}

#pragma mark - AMapNaviDriveManagerDelegate
/**
 * @brief 驾车路径规划成功后的回调函数
 * @param driveManager 驾车导航管理类
 */
- (void)driveManagerOnCalculateRouteSuccess:(AMapNaviDriveManager *)driveManager
{
    NSLog(@"onCalculateRouteSuccess");
    [self showRouteWithNaviRoute:[[driveManager naviRoute] copy]];
}

/**
 * @brief 驾车路径规划失败后的回调函数
 * @param error 错误信息,error.code参照 AMapNaviCalcRouteState .
 * @param driveManager 驾车导航管理类
 */
- (void)driveManager:(AMapNaviDriveManager *)driveManager onCalculateRouteFailure:(NSError *)error
{
    [MBProgressHUD showTestMessage:@"路线规划失败,请重新规划"];
    [self.navigationController performSelector:@selector(popViewControllerAnimated:) withObject:nil afterDelay:1.0f];
}

/**
 * @brief 导航播报信息回调函数,此回调函数需要和driveManagerIsNaviSoundPlaying:配合使用
 * @param driveManager 驾车导航管理类
 * @param soundString 播报文字
 * @param soundStringType 播报类型,参考 AMapNaviSoundType .
 */
- (void)driveManager:(AMapNaviDriveManager *)driveManager playNaviSoundString:(NSString *)soundString soundStringType:(AMapNaviSoundType)soundStringType
{
    NSLog(@"播报：%@", soundString);
    if (soundStringType == AMapNaviSoundTypePassedReminder)
    {
        //用系统自带的声音做简单例子，播放其他提示音需要另外配置
        AudioServicesPlaySystemSound(1009);
    }
    else
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self.iFlySpeechSynthesizer startSpeaking:soundString];
        });
    }
}
#pragma mark - AMapNaviDriveViewDelegate
/**
 * @brief 导航界面关闭按钮点击时的回调函数
 * @param driveView 驾车导航界面
 */
- (void)driveViewCloseButtonClicked:(AMapNaviDriveView *)driveView
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.iFlySpeechSynthesizer stopSpeaking];
    });
    self.navigationController.navigationBar.hidden = NO;
    [self.driveManager stopNavi];
    [self.driveManager removeDataRepresentative:self.driveView];
//    [self.driveView removeFromSuperview];
//    self.driveView = nil;
//    self.driveManager = nil;
    self.driveView.hidden = YES;
}

/**
 * @brief 导航界面更多按钮点击时的回调函数
 * @param driveView 驾车导航界面
 */
- (void)driveViewMoreButtonClicked:(AMapNaviDriveView *)driveView
{
    
}

/**
 * @brief 导航界面转向指示View点击时的回调函数
 * @param driveView 驾车导航界面
 */
- (void)driveViewTrunIndicatorViewTapped:(AMapNaviDriveView *)driveView
{
    [self.driveManager readNaviInfoManual];
}

#pragma mark - AMapNaviWalkManagerDelegate
- (void)walkManagerOnCalculateRouteSuccess:(AMapNaviWalkManager *)walkManager
{
    NSLog(@"onCalculateRouteSuccess");
    [self showRouteWithNaviRoute:[[walkManager naviRoute] copy]];
}

#pragma mark - AMapNaviWalkViewDelegate
/**
 * @brief 导航界面关闭按钮点击时的回调函数
 * @param walkView 步行导航界面
 */
- (void)walkViewCloseButtonClicked:(AMapNaviWalkView *)walkView
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.iFlySpeechSynthesizer stopSpeaking];
    });
     self.navigationController.navigationBar.hidden = NO;
    [self.walkManager stopNavi];
    [self.walkManager removeDataRepresentative:self.walkView];
    self.walkView.hidden = YES;
}

/**
 * @brief 导航界面更多按钮点击时的回调函数
 * @param walkView 步行导航界面
 */
- (void)walkViewMoreButtonClicked:(AMapNaviWalkView *)walkView
{

}

/**
 * @brief 导航界面转向指示View点击时的回调函数
 * @param walkView 步行导航界面
 */
- (void)walkViewTrunIndicatorViewTapped:(AMapNaviWalkView *)walkView
{
     [self.walkManager readNaviInfoManual];
}


#pragma mark - MAMapViewDelegate
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation {
    static NSString *identifier = @"annotationIdentifier";
    MAPinAnnotationView *pointAnnotationView = (MAPinAnnotationView*)[self.mapView dequeueReusableAnnotationViewWithIdentifier:identifier];
    if (pointAnnotationView == nil)  {
        pointAnnotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation
                                                              reuseIdentifier:identifier];
        pointAnnotationView.animatesDrop   = NO;
        pointAnnotationView.canShowCallout = YES;
        pointAnnotationView.draggable      = NO;
        [pointAnnotationView setPinColor:MAPinAnnotationColorRed];
    }
    return pointAnnotationView;
}

//绘图回调的方法
- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id <MAOverlay>)overlay
{
    if ([overlay isKindOfClass:[MAPolyline class]])
    {
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        
        polylineRenderer.lineWidth    = 8.f;
        polylineRenderer.strokeColor  = [UIColor colorWithRed:0 green:1 blue:0 alpha:0.6];
        polylineRenderer.lineJoinType = kMALineJoinRound;
        polylineRenderer.lineCapType  = kMALineCapRound;
        
        return polylineRenderer;
    }
    
    return nil;
}

#pragma mark - IFlySpeechSynthesizerDelegate
- (void)onCompleted:(IFlySpeechError *)error {
    NSLog(@"Speak：{%d:%@}", error.errorCode, error.errorDesc);
}

@end
