//
//  ChartView.m
//  ChartView
//
//  Created by AirChen on 2020/8/18.
//  Copyright © 2020 AirChen. All rights reserved.
//

#import "ChartView.h"

typedef NS_ENUM(NSUInteger, BarItemLayerColorType) {
    BarItemLayerColorType_invalid,
    BarItemLayerColorType_lowLight,
    BarItemLayerColorType_highLight,
};

static NSString *clockString(NSDate *date);
static CATextLayer *createTextLayer(CGFloat size, UIColor *color);
static CAShapeLayer *createShapeLayer(CGRect rect);
static UIColor *colorWithHex(NSUInteger color);
static inline UIColor *colorWithHexAlpha(NSUInteger color, CGFloat alpha);
static inline int getScrollBarIndex(UIScrollView *scrollView, BOOL isToday, BOOL isStrict);

@interface BarItemLayer : CALayer
@property(nonatomic, copy) NSString *numStr;
@property(nonatomic, copy) NSString *title;
@property(nonatomic) BarItemLayerColorType colorType;
@property(nonatomic) int32_t eta;
@property(nonatomic) BOOL enableThin;
@property(nonatomic) BOOL enableShape;
@end

@implementation BarItemLayer
{
    CAGradientLayer *_barItemLayer;
    CATextLayer *_textLayer;
    CATextLayer *_titleLayer;
}

- (void)drawInContext:(CGContextRef)ctx {
    CGRect rect = self.bounds;
    CGFloat textHeight = 20.0;
    CGFloat thinBarWidth = (_enableThin && _colorType != BarItemLayerColorType_highLight) ? 12.0 : 8.0;
    UIColor *grayColor = [UIColor colorWithRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1];
    
    if (!_textLayer) {
        _textLayer = createTextLayer(10.0, grayColor);
        _textLayer.wrapped = YES;
        [self addSublayer:_textLayer];
    }
    
    if (_numStr) {
        _textLayer.string = _numStr;
    }
    
    if (_numStr && _numStr.length > 4) {
        _textLayer.frame = CGRectMake(0, -textHeight, CGRectGetWidth(rect), 2.0 * textHeight);
    } else {
        _textLayer.frame = CGRectMake(0, 0, CGRectGetWidth(rect), textHeight);
    }
    
    if (!_barItemLayer) {
        _barItemLayer = [CAGradientLayer layer];
        _barItemLayer.type = kCAGradientLayerAxial;
        _barItemLayer.startPoint = CGPointMake(0, 0);
        _barItemLayer.endPoint = CGPointMake(0, 1);
        [self addSublayer:_barItemLayer];
    }
        
    if (_colorType == BarItemLayerColorType_invalid) {
        _barItemLayer.colors = @[(__bridge id)grayColor.CGColor, (__bridge id)grayColor.CGColor];
    }
    
    if (_colorType == BarItemLayerColorType_lowLight) {
        _barItemLayer.colors = @[(__bridge id)colorWithHex(0xa1b9ff).CGColor, (__bridge id)colorWithHex(0xd4e5ff).CGColor];
    }
    
    if (_colorType == BarItemLayerColorType_highLight) {
        _barItemLayer.colors = @[(__bridge id)colorWithHex(0x6189ff).CGColor, (__bridge id)colorWithHex(0xb8d4ff).CGColor];
    }
        
    _barItemLayer.locations = @[@(0.0), @(1)];
    _barItemLayer.frame = CGRectMake(thinBarWidth, textHeight, CGRectGetWidth(rect) - 2 * thinBarWidth, CGRectGetHeight(rect) - textHeight);
    if (_enableShape) {
        _barItemLayer.mask = createShapeLayer(_barItemLayer.bounds);
    }
    
    if (_titleLayer) {
        [_titleLayer removeFromSuperlayer];
    }
        
    _titleLayer = createTextLayer(12.0, (_colorType == BarItemLayerColorType_highLight) ? colorWithHex(0x3C78FF) : grayColor);
    [self addSublayer:_titleLayer];
    _titleLayer.frame = CGRectMake(0, CGRectGetHeight(rect) + 5, CGRectGetWidth(rect), textHeight);
    if (_title) {
        _titleLayer.string = _title;
    }
}
@end

@interface ChartView () <UIScrollViewDelegate>
@property(nonatomic) UIScrollView *scrollView;
@end

@implementation ChartView
{
    NSMutableArray<BarItemLayer *> *_barItemLayers;
    NSMutableArray<BarItemLayer *> *_mirrorLayers;
    NSMutableArray<NSDate *> *_dateTabs;
        
    int32_t max_eta;
    int32_t min_eta;
        
    CGFloat _barItemH;
    BOOL _isToday;
    BOOL _isFirstDraw;
    
    CGFloat _prevX;
    BOOL _dragging;
    NSInteger _page;
    ChartViewType _type;
        
    CAScrollLayer *_scrollLayer;
}

- (instancetype)initWithDate:(NSDate *)date type:(ChartViewType)type {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];

        [self calculateDateTabs:date];
        _isFirstDraw = YES;
        _type = type;
    }
    return self;
}

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.delegate = self;
        [self.superview addSubview:_scrollView];
    }
    return _scrollView;
}

- (void)reloadData:(int32_t *)etas beginTimestamp:(int64_t)beginT count:(int)count {
    //计算 beginIndex;
    int beginIndex = 0;
    NSDate *beginDate = [NSDate dateWithTimeIntervalSince1970:beginT];    
    if ([_dateTabs containsObject:beginDate]) {
        beginIndex = (int)[_dateTabs indexOfObject:beginDate];
    } else {
        return;
    }
    
    //整理 eta
    int currentIndex = getScrollBarIndex(_scrollView, _isToday, NO);
    for (int i = 0; i < count && (beginIndex + i) < _barItemLayers.count; i++) {
        int32_t eta = *(etas + i);
        NSString *numStr = [self calcTimeFromSeconds:eta];
        
        BarItemLayer *itemLayer = _barItemLayers[beginIndex + i];
        itemLayer.colorType = BarItemLayerColorType_lowLight;
        itemLayer.colorType = ((beginIndex + i) == currentIndex) ? BarItemLayerColorType_highLight : BarItemLayerColorType_lowLight;
        itemLayer.numStr = numStr;
        itemLayer.eta = eta;
        
        if (_type == ChartViewType_mask) {
            itemLayer = _mirrorLayers[beginIndex + i];
            itemLayer.colorType = BarItemLayerColorType_highLight;
            itemLayer.numStr = numStr;
            itemLayer.eta = eta;
        }
        
        if (eta > max_eta) {
            max_eta = eta;
        }
        
        if (eta < min_eta) {
            min_eta = eta;
        }
    }
}

static inline CGFloat getRatioWithMaxNumber(NSInteger maxNumber, NSInteger minNumber)
{
    CGFloat ratio = (3*minNumber - maxNumber)/(2.0*minNumber);
    if (ratio < 0.8) {
        return ratio > 0 ? ratio:0;
    }
    return 0.8;
}

- (void)recalculateBarItemLayersHeight {
    if (max_eta == min_eta) {
        max_eta++;
    }
    
    CGFloat radio = getRatioWithMaxNumber(max_eta, min_eta);
    CGFloat diffMaxMinIntegerValue = max_eta - min_eta * radio;
    for (int i = 0; i < _barItemLayers.count; i++) {
        BarItemLayer *layer = _barItemLayers[i];
        BarItemLayer *mirrorLayer;
        if (_type == ChartViewType_mask) {
            mirrorLayer = _mirrorLayers[i];
        }
        if (layer.colorType != BarItemLayerColorType_invalid) {
            CGRect(^calculateRect)(CGRect) = ^(CGRect rect) {
                CGFloat barBottom = CGRectGetMinY(rect) + CGRectGetHeight(rect);
                CGFloat process = (layer.eta - self->min_eta * radio)/diffMaxMinIntegerValue;
                CGFloat newHeight = (self->_barItemH * 0.8) * process + self->_barItemH * 0.2;
                CGRect newFrame = CGRectMake(CGRectGetMinX(rect), barBottom - newHeight, CGRectGetWidth(rect), newHeight);
                return newFrame;
            };
            
            layer.frame = calculateRect(layer.frame);
            [layer setNeedsDisplay];
         
            if (mirrorLayer) {
                mirrorLayer.frame = calculateRect(mirrorLayer.frame);
                [mirrorLayer setNeedsDisplay];
            }
        }
    }
}

- (void)resetDate:(NSDate *)date {
    [self calculateDateTabs:date];
    [self setNeedsDisplay];
}

- (void)calculateDateTabs:(NSDate *)date {
    max_eta = INT_MIN;
    min_eta = INT_MAX;
  
    if (_dateTabs) {
        [_dateTabs removeAllObjects];
    } else {
        _dateTabs = [NSMutableArray array];
    }
    
    int64_t timestamp = [date timeIntervalSince1970];
    int64_t t = (timestamp + 28800) % 86400; // 东八区

    // if Needed.
//    if ([self isToDay:date]) {
//        timestamp -= 5400;
//        t -= 5400;
//        _isToday = YES;
//    } else {
        timestamp -= t;
        t = 0;
        _isToday = NO;
//    }
   
    for (; t < 86400;) {
        NSDate *temp = [NSDate dateWithTimeIntervalSince1970:timestamp];
        [_dateTabs addObject:temp];
        timestamp += 1800;
        t += 1800;
    }
}

- (void)scrollToDate:(NSDate *)date {
    int index = (int)[_dateTabs indexOfObject:date];
    if (_isToday) {
        index -= 3;
    }
    CGFloat calOffsetX = (CGFloat)index * CGRectGetWidth(self.scrollView.bounds);
    [_scrollView setContentOffset:CGPointMake(calOffsetX, 0) animated:YES];
}

- (void)drawRect:(CGRect)rect {
    if (_scrollView && [UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }
    
    if (!_barItemLayers) {
        _barItemLayers = [NSMutableArray array];
    }
    
    if (_type == ChartViewType_mask && !_mirrorLayers) {
        _mirrorLayers = [NSMutableArray array];
    }
    
    if (!_scrollLayer) {
        _scrollLayer = [CAScrollLayer layer];
        _scrollLayer.frame = self.bounds;
        _scrollLayer.masksToBounds = YES;
        _scrollLayer.backgroundColor = [UIColor clearColor].CGColor;
        [_scrollLayer setScrollMode:kCAScrollHorizontally];
        [self.layer addSublayer:_scrollLayer];
    }
        
    int spareCount = 4;
    CGFloat spareHeight = CGRectGetHeight(rect)/spareCount;
    
    // base lines
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1);
    for (int i = 0; i < spareCount; i++) {
        CGContextMoveToPoint(ctx, 0, spareHeight * (i + 1));
        CGContextAddLineToPoint(ctx, CGRectGetWidth(rect) * 4, spareHeight * (i + 1));
    }
    
    CGFloat a[] = {2.0, 2.0};
    CGContextSetLineDash(ctx, 2, a, 2);
    CGContextSetStrokeColorWithColor(ctx, colorWithHex(0xe9ebed).CGColor);
    CGContextStrokePath(ctx);    
        
    // bar item
    CGFloat barBottom = 3.0 * spareHeight, barWidth = 41.0, barInterval = CGRectGetWidth(rect)/7.0 - barWidth;
    CGFloat barHeight = 30.0;// item Height
    _barItemH = barHeight + 2.0 * spareHeight - 10;
        
    if (!_scrollView) {
        CGFloat mx = (CGRectGetWidth(rect) - barWidth - barInterval)/2.0;
        if (_type == ChartViewType_mask) {
            self.scrollView.frame = CGRectMake(mx + CGRectGetMinX(self.frame), CGRectGetMinY(self.frame), barWidth + barInterval, CGRectGetHeight(rect));
            self.scrollView.backgroundColor = [UIColor clearColor];
        } else {
            self.scrollView.frame = CGRectMake(mx + CGRectGetMinX(self.frame), barBottom + CGRectGetMinY(self.frame), barWidth + barInterval, 25.0);
            self.scrollView.backgroundColor = [UIColor whiteColor];
        }
        
        if (_type == ChartViewType_zoom) {
            self.scrollView.layer.cornerRadius = CGRectGetHeight(_scrollView.bounds) / 2.0;
            self.scrollView.layer.borderColor = colorWithHex(0xcccccc).CGColor;
            self.scrollView.layer.borderWidth = 1.0f;
        }
    } else {
        [_barItemLayers enumerateObjectsUsingBlock:^(BarItemLayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj removeFromSuperlayer];
        }];
        [_barItemLayers removeAllObjects];
        
        if (_mirrorLayers) {
            [_mirrorLayers enumerateObjectsUsingBlock:^(BarItemLayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [obj removeFromSuperlayer];
            }];
            [_mirrorLayers removeAllObjects];
            
            NSMutableArray *array = [NSMutableArray array];
            [_scrollView.layer.sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj isMemberOfClass:[CATextLayer class]]) {
                    [array addObject:obj];
                }
            }];
            [array enumerateObjectsUsingBlock:^(CATextLayer *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [obj removeFromSuperlayer];
            }];
            [array removeAllObjects];
        }
    }

    CGFloat spacePartLength = _isToday ? 0.0 : (CGRectGetWidth(rect) - barWidth - barInterval)/2.0;
    CGFloat totalWidth = spacePartLength;
    for (int i = 0; i < _dateTabs.count; i++) {
        CGFloat mX = barInterval / 2.0 + (barInterval + barWidth)*(CGFloat)i;
        
        BarItemLayer *barItemLayer = [BarItemLayer layer];
        barItemLayer.frame = CGRectMake(mX, barBottom - barHeight, barWidth, barHeight);
        barItemLayer.colorType = BarItemLayerColorType_invalid;
        barItemLayer.enableThin = (_type == ChartViewType_animate);
        barItemLayer.enableShape = (_type == ChartViewType_zoom);
        barItemLayer.numStr = @"--分钟";
        NSDate *tabDate = _dateTabs[i];
        barItemLayer.title = clockString(tabDate);
        [barItemLayer setNeedsDisplay];
        [_scrollLayer addSublayer:barItemLayer];
        [_barItemLayers addObject:barItemLayer];
        
        if (_type == ChartViewType_mask) {
            BarItemLayer *mirrorItemLayer = [BarItemLayer layer];
            mirrorItemLayer.frame = CGRectMake(mX - CGRectGetMinX(_scrollView.frame) + CGRectGetMinX(self.frame), barBottom - barHeight, barWidth, barHeight);
            mirrorItemLayer.colorType = BarItemLayerColorType_invalid;
            mirrorItemLayer.title = barItemLayer.title;
            [mirrorItemLayer setNeedsDisplay];
            [_scrollView.layer addSublayer:mirrorItemLayer];
            [_mirrorLayers addObject:mirrorItemLayer];
        } else {
            CATextLayer *textLayer = createTextLayer(13, colorWithHex(0x3C78FF));
            textLayer.string = barItemLayer.title;
            textLayer.frame = CGRectMake(mX - CGRectGetMinX(_scrollView.frame) + CGRectGetMinX(self.frame) - 9.0, 5.0, barWidth + 18.0, 15.0);
            [_scrollView.layer addSublayer:textLayer];
        }
        
        totalWidth += (barWidth + barInterval);
    }
    if (_type == ChartViewType_mask) {
        _scrollView.contentSize = CGSizeMake(totalWidth - CGRectGetMinX(_scrollView.frame) + CGRectGetMinX(self.frame), _barItemH);
    } else {
        _scrollView.contentSize = CGSizeMake(totalWidth - CGRectGetMinX(_scrollView.frame) + CGRectGetMinX(self.frame), 25.0);
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (CGRectContainsPoint(self.bounds, point)) {
        return self.scrollView;
    }
    
    return [super hitTest:point withEvent:event];
}

#pragma mark -- UIScrollViewDelegate
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [ChartView cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(scrollEndAction) withObject:nil afterDelay:0.6];
}

- (void)scrollEndAction {
    int index = getScrollBarIndex(_scrollView, _isToday, NO);
    if (_scrollToDateHandle) {
        _scrollToDateHandle(_dateTabs[index], (_barItemLayers[index].colorType == BarItemLayerColorType_invalid));
    }
    
    if (_type != ChartViewType_mask) {
        [_barItemLayers enumerateObjectsUsingBlock:^(BarItemLayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx == index && obj.colorType == BarItemLayerColorType_lowLight) {
                obj.colorType = BarItemLayerColorType_highLight;
                [obj setNeedsDisplay];
            }
            
            if (idx != index && obj.colorType == BarItemLayerColorType_highLight) {
                obj.colorType = BarItemLayerColorType_lowLight;
                [obj setNeedsDisplay];
            }
        }];
    }
}

static NSInteger getClosestPage(UIScrollView *scrollView) {
    CGFloat x = scrollView.contentOffset.x;
    CGFloat w = scrollView.frame.size.width;
    NSInteger nbrOfPages = scrollView.contentSize.width / w;
    for (int i = 0; i < nbrOfPages; i++) {
        CGFloat dx1 = x - i*w;
        CGFloat dx2 = (i+1)*w - x;
        if (dx1 > 0 && dx2 > 0) {
            if (dx1 >= dx2) {
                return i;
            } else {
                return (i+1 < nbrOfPages ? i+1 : i);
            }
        }
    }
    return 0;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_type != ChartViewType_mask) {
        // animate
        int index = getScrollBarIndex(scrollView, _isToday, YES);
        index = MIN(index, (int)_dateTabs.count-1);
        [_barItemLayers enumerateObjectsUsingBlock:^(BarItemLayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx == index && obj.colorType == BarItemLayerColorType_lowLight) {
                obj.colorType = BarItemLayerColorType_highLight;
                [obj setNeedsDisplay];
            }
            
            if (idx != index && obj.colorType == BarItemLayerColorType_highLight) {
                obj.colorType = BarItemLayerColorType_lowLight;
                [obj setNeedsDisplay];
            }
        }];
    }
    
    // handle event
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    [_scrollLayer scrollToPoint:CGPointMake(scrollView.contentOffset.x, _scrollLayer.position.y)];
    [CATransaction commit];
    
    // scroll func
    static const CGFloat SPEED_MIN = 2;
    static const CGFloat SPEED_MAX = 10;
    
    CGFloat nextX = scrollView.contentOffset.x;
    CGFloat speedX = nextX - _prevX;
    speedX = ABS(speedX);
    _prevX = nextX;
    if (_dragging) {
        if (speedX < SPEED_MIN && _page < 0) {
            _page = getClosestPage(scrollView);
            [scrollView setContentOffset:CGPointMake(_page * scrollView.frame.size.width, 0) animated:YES];
        } else if (scrollView.contentOffset.x == _page * scrollView.frame.size.width) {
            _page = -1;
            _dragging = false;
        }
    } else {
        _dragging = speedX > SPEED_MAX;
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    CGSize pageSize = scrollView.bounds.size;
    targetContentOffset->x = pageSize.width * round(targetContentOffset->x / pageSize.width);
    targetContentOffset->y = pageSize.height * round(targetContentOffset->y / pageSize.height);
}

#pragma mark -- utils
- (NSCalendar *)calendar {
    static NSCalendar *g_calendar;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]; // 指定日历的算
        [g_calendar setTimeZone:[NSTimeZone localTimeZone]];
    });
    return g_calendar;
}

- (BOOL)isToDay:(NSDate *)date {
    return [[self calendar] isDateInToday:date];
}

- (NSString *)calcTimeFromSeconds:(int)seconds {
    int totalMinute = ceil(seconds / 60.0);
    int timeHour = totalMinute / 60;
    int timeMinute = totalMinute % 60;

    if (timeHour == 0) {
        return [NSString stringWithFormat:@"%d分钟", timeMinute];
    } else if (timeMinute == 0) {
        return [NSString stringWithFormat:@"%d小时",timeHour];
    } else {
        return [NSString stringWithFormat:@"%d小时%d分钟", timeHour, timeMinute];
    }
}

@end

static UIColor *colorWithHex(NSUInteger color) {
    return colorWithHexAlpha(color, 1);
}

static inline UIColor *colorWithHexAlpha(NSUInteger color, CGFloat alpha) {
    unsigned char r, g, b;
    b = color & 0xFF;
    g = (color >> 8) & 0xFF;
    r = (color >> 16) & 0xFF;
    return [UIColor colorWithRed:(float)r/255.0f green:(float)g/255.0f blue:(float)b/255.0f alpha:alpha];
}

static CATextLayer *createTextLayer(CGFloat size, UIColor *color)
{
    CATextLayer *textLayer = [CATextLayer layer];
    UIFont *font = [UIFont boldSystemFontOfSize:size];
    CFStringRef fontName = (__bridge CFStringRef)font.fontName;
    CGFontRef fontRef =CGFontCreateWithFontName(fontName);
    textLayer.font = fontRef;
    textLayer.fontSize = font.pointSize;
    
    textLayer.foregroundColor = color.CGColor;
    textLayer.alignmentMode = kCAAlignmentCenter;
    textLayer.contentsScale = [UIScreen mainScreen].scale;
    return textLayer;
}

static CAShapeLayer *createShapeLayer(CGRect rect)
{
    CGFloat radius = CGRectGetWidth(rect)/2.0, height = CGRectGetHeight(rect), width = CGRectGetWidth(rect);
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(0, height)];
    [path addLineToPoint:CGPointMake(0, radius)];
    [path addArcWithCenter:CGPointMake(radius, radius) radius:radius startAngle:M_PI endAngle:0 clockwise:YES];
    [path addLineToPoint:CGPointMake(width, radius)];
    [path addLineToPoint:CGPointMake(width, height)];
    [path closePath];
    
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    [shapeLayer setPath:path.CGPath];
    return shapeLayer;;
}

static inline NSDateFormatter *getDateFormatter()
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
    });
    return formatter;
}

static NSString *clockString(NSDate *date) {
    NSDateFormatter *formatter = getDateFormatter();
    [formatter setDateFormat:@"HH:mm"];
    return [formatter stringFromDate:date];
}

static inline int getScrollBarIndex(UIScrollView *scrollView, BOOL isToday, BOOL isStrict)
{
    int index = -1;
    if (isStrict) {
        CGFloat cIndex = scrollView.contentOffset.x / CGRectGetWidth(scrollView.bounds);
        if ((cIndex - (CGFloat)(int)cIndex) < 0.9) {
            index = cIndex;
        } else {
            index = cIndex + 1;
        }
    } else {
        index = (int)scrollView.contentOffset.x / (int)CGRectGetWidth(scrollView.bounds);
    }
    
    if (index != -1) {
        index += 3;
    }
        
    return index;
}
