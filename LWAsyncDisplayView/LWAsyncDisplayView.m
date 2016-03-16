//
//  The MIT License (MIT)
//  Copyright (c) 2016 Wayne Liu <liuweself@126.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//　　The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
////
//  LWLabel.m
//  LWAsyncLayerDemo
//
//  Created by 刘微 on 16/2/1.
//  Copyright © 2016年 Wayne Liu. All rights reserved.
//  https://github.com/waynezxcv/LWAsyncDisplayView
//  See LICENSE for this sample’s licensing information
//

#import "LWAsyncDisplayView.h"
#import "LWAsyncDisplayLayer.h"
#import "LWRunLoopObserver.h"

@interface LWAsyncDisplayView ()
<LWAsyncDisplayLayerDelegate,UIGestureRecognizerDelegate>

@property (nonatomic,strong) UITapGestureRecognizer* tapGestureRecognizer;

@end

@implementation LWAsyncDisplayView

#pragma mark - Initialization

/**
 *  “default is [CALayer class]. Used when creating the underlying layer for the view.”
 *
 */
+ (Class)layerClass {
    return [LWAsyncDisplayLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.opaque = NO;
        self.layer.contentsScale = [UIScreen mainScreen].scale;
        ((LWAsyncDisplayLayer *)self.layer).asyncDisplayDelegate = self;
        [self addGestureRecognizer:self.tapGestureRecognizer];
    }
    return self;
}

#pragma mark - Setter & Getter

- (void)setLayouts:(NSArray *)layouts {
    if ([_layouts isEqual:layouts] || _layouts == layouts) {
        return;
    }
    _layouts = layouts;
    [(LWAsyncDisplayLayer *)self.layer drawContent];
}




- (UITapGestureRecognizer *)tapGestureRecognizer {
    if (!_tapGestureRecognizer) {
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(_didSingleTapThisView:)];
        _tapGestureRecognizer.delegate = self;
    }
    return _tapGestureRecognizer;
}

#pragma mark - LWAsyncDisplayLayerDelegate

- (BOOL)willBeginAsyncDisplay:(LWAsyncDisplayLayer *)layer {
    return YES;
}

- (void)didAsyncDisplay:(LWAsyncDisplayLayer *)layer context:(CGContextRef)context size:(CGSize)size {
    if ([self.delegate respondsToSelector:@selector(extraAsyncDisplayIncontext:size:)] &&
        [self.delegate conformsToProtocol:@protocol(LWAsyncDisplayViewDelegate)]) {
        [self.delegate extraAsyncDisplayIncontext:context size:size];
    }
    for (LWTextLayout* layout in self.layouts) {
        [layout drawInContext:context];
    }
}

#pragma mark - SignleTapGesture

- (void)_didSingleTapThisView:(UITapGestureRecognizer *)tapGestureRecognizer {
    CGPoint touchPoint = [tapGestureRecognizer locationInView:self];
    for (LWTextLayout* layout in self.layouts) {
        CTFrameRef textFrame = layout.frame;
        //获取每一行
        CFArrayRef lines = CTFrameGetLines(textFrame);
        CGPoint origins[CFArrayGetCount(lines)];
        //获取每行的原点坐标
        CTFrameGetLineOrigins(textFrame, CFRangeMake(0, 0), origins);
        //翻转坐标系
        CGPathRef path = CTFrameGetPath(textFrame);
        //获取整个CTFrame的大小
        CGRect boundsRect = CGPathGetBoundingBox(path);
        CGAffineTransform transform = CGAffineTransformIdentity;
        transform = CGAffineTransformMakeTranslation(0, boundsRect.size.height);
        transform = CGAffineTransformScale(transform, 1.f, -1.f);
        for (int i= 0; i < CFArrayGetCount(lines); i++) {
            CGPoint linePoint = origins[i];
            CTLineRef line = CFArrayGetValueAtIndex(lines, i);
            // 获得每一行的 CGRect 信息
            CGRect flippedRect = [self _getLineBounds:line point:linePoint];
            CGRect rect = CGRectApplyAffineTransform(flippedRect, transform);

            CGRect adjustRect = CGRectMake(rect.origin.x + boundsRect.origin.x,
                                           rect.origin.y + boundsRect.origin.y,
                                           rect.size.width,
                                           rect.size.height);

            if (CGRectContainsPoint(adjustRect, touchPoint)) {
                // 将点击的坐标转换成相对于当前行的坐标
                CGPoint relativePoint = CGPointMake(touchPoint.x - CGRectGetMinX(adjustRect),
                                                    touchPoint.y - CGRectGetMinY(adjustRect));
                // 获得当前点击坐标对应的字符串偏移
                CFIndex index = CTLineGetStringIndexForPosition(line, relativePoint);
                //获取点击的Run
                CTRunRef touchedRun;
                NSArray* runObjArray = (NSArray *)CTLineGetGlyphRuns(line);
                for (NSInteger i = 0; i < runObjArray.count; i ++) {
                    CTRunRef runObj = (__bridge CTRunRef)[runObjArray objectAtIndex:i];
                    CFRange range = CTRunGetStringRange((CTRunRef)runObj);
                    if (NSLocationInRange(index, NSMakeRange(range.location, range.length))) {
                        touchedRun = runObj;
                        NSDictionary* runAttribues = (NSDictionary *)CTRunGetAttributes(touchedRun);
                        if ([runAttribues objectForKey:kLWTextLinkAttributedName]) {
                            if ([self.delegate respondsToSelector:@selector(lwAsyncDicsPlayView:didCilickedLinkWithfData:)] &&
                                [self.delegate conformsToProtocol:@protocol(LWAsyncDisplayViewDelegate)]) {
                                [self.delegate lwAsyncDicsPlayView:self didCilickedLinkWithfData:[runAttribues objectForKey:kLWTextLinkAttributedName]];
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
}

- (CGRect)_getLineBounds:(CTLineRef)line point:(CGPoint)point {
    CGFloat ascent = 0.0f;
    CGFloat descent = 0.0f;
    CGFloat leading = 0.0f;
    CGFloat width = (CGFloat)CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    CGFloat height = ascent + descent;
    return CGRectMake(point.x, point.y - descent, width, height);
}

- (void)_layout:(LWTextLayout *)layout drawHighLightWithAttach:(LWTextAttach *)attach {

}

#pragma mark - UIGestrueRecognizer

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

@end