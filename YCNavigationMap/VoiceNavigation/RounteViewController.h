//
//  RounteViewController.h
//  SoudNavigation
//
//  Created by ChangWingchit on 16/1/26.
//  Copyright © 2016年 ChangWingchit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Positon.h"

//科大讯飞语音头文件
#import "iflyMSC/IFlySpeechSynthesizer.h"
#import "iflyMSC/IFlySpeechSynthesizerDelegate.h"
#import "iflyMSC/IFlySpeechConstant.h"
#import "iflyMSC/IFlySpeechUtility.h"
#import "iflyMSC/IFlySetting.h"
#import "iflyMSC/IFlySpeechError.h"
//高德导航头文件
#import <AMapNaviKit/AMapNaviKit.h>
#import <MAMapKit/MAMapKit.h>
#import <AMapSearchKit/AMapSearchKit.h>
#import <AMapLocationKit/AMapLocationKit.h>

@interface RounteViewController : UIViewController<MAMapViewDelegate,IFlySpeechSynthesizerDelegate,AMapNaviDriveManagerDelegate,AMapNaviDriveViewDelegate,AMapNaviWalkManagerDelegate,AMapNaviWalkViewDelegate>

@property (nonatomic, strong) MAMapView *mapView; //高德地图
@property (nonatomic, strong) IFlySpeechSynthesizer *iFlySpeechSynthesizer; //讯飞语音合成
@property (nonatomic, strong) AMapNaviDriveManager *driveManager; //地图导航管理器-车载
@property (nonatomic, strong) AMapNaviWalkManager *walkManager; //地图导航管理器-步行
@property (nonatomic, strong) AMapNaviDriveView *driveView; //车驾导航图
@property (nonatomic, strong) AMapNaviWalkView *walkView; //步行导航图

@property (nonatomic) Positon *origin;//保存起始点
@property (nonatomic) Positon *end;//保存目标点
@property (nonatomic) TravelType travel;//路线模式(步行或驾车)
@property (nonatomic) NavigationType naviType;//导航模式(模拟或实时)

//初始化
- (instancetype)initWithOrigin:(Positon*)origin end:(Positon*)end travel:(TravelType)travel;

@end
