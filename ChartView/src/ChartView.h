//
//  ChartView.h
//  ChartView
//
//  Created by AirChen on 2020/8/18.
//  Copyright © 2020 AirChen. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    ChartViewType_zoom,
    ChartViewType_animate,
    ChartViewType_mask
} ChartViewType;

typedef void(^ScrollToDateBlock)(NSDate *, BOOL);// 日期,是否需要重算

@interface ChartView : UIView

- (instancetype)initWithDate:(NSDate *)date type:(ChartViewType)type;// 初始化二表格
- (void)reloadData:(int32_t *)etas beginTimestamp:(int64_t)beginT count:(int)count;// 调整表格
- (void)recalculateBarItemLayersHeight; //reload height 重新计算高度
- (void)resetDate:(NSDate *)date;
- (void)scrollToDate:(NSDate *)date; //scroll 的date必须在列表中

@property(nonatomic, copy) ScrollToDateBlock scrollToDateHandle;
@end

NS_ASSUME_NONNULL_END
