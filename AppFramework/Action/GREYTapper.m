//
// Copyright 2017 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "GREYTapper.h"

#import "NSObject+GREYApp.h"
#import "GREYInteraction.h"
#import "GREYAppError.h"
#import "GREYSyntheticEvents.h"
#import "GREYSyncAPI.h"
#import "NSObject+GREYCommon.h"
#import "GREYThrowDefines.h"
#import "NSError+GREYCommon.h"
#import "GREYConstants.h"
#import "CGGeometry+GREYUI.h"

@implementation GREYTapper

+ (BOOL)tapOnElement:(id)element
        numberOfTaps:(NSUInteger)numberOfTaps
            location:(CGPoint)location
               error:(__strong NSError **)errorOrNil {
  GREYThrowOnFailedCondition(numberOfTaps > 0);

  __block UIView *viewToTap = nil;
  __block UIWindow *window = nil;
  grey_dispatch_sync_on_main_thread(^{
    viewToTap =
        ([element isKindOfClass:[UIView class]] ? element : [element grey_viewContainingSelf]);
    window = [viewToTap isKindOfClass:[UIWindow class]] ? (UIWindow *)viewToTap : viewToTap.window;
  });

  return [self tapOnWindow:window
              numberOfTaps:numberOfTaps
                  location:[self grey_tapPointForElement:element relativeLocation:location]
                     error:errorOrNil];
}

+ (BOOL)tapOnWindow:(UIWindow *)window
       numberOfTaps:(NSUInteger)numberOfTaps
           location:(CGPoint)location
              error:(__strong NSError **)errorOrNil {
  if (![GREYTapper grey_checkLocation:location
                     inBoundsOfWindow:window
                       forActionNamed:@"tap"
                                error:errorOrNil]) {
    return NO;
  }

  NSArray *touchPath = @[ [NSValue valueWithCGPoint:location] ];
  for (NSUInteger i = 1; i <= numberOfTaps; i++) {
    @autoreleasepool {
      [GREYSyntheticEvents touchAlongPath:touchPath relativeToWindow:window forDuration:0];
    }
  }
  return YES;
}

+ (BOOL)longPressOnElement:(id)element
                  location:(CGPoint)location
                  duration:(CFTimeInterval)duration
                     error:(__strong NSError **)errorOrNil {
  __block UIView *view =
      [element isKindOfClass:[UIView class]] ? element : [element grey_viewContainingSelf];
  __block UIWindow *window = nil;
  grey_dispatch_sync_on_main_thread(^{
    window = [view isKindOfClass:[UIWindow class]] ? (UIWindow *)view : view.window;
  });
  CGPoint resolvedLocation = [self grey_tapPointForElement:element relativeLocation:location];

  if (![GREYTapper grey_checkLocation:resolvedLocation
                     inBoundsOfWindow:window
                       forActionNamed:@"long press"
                                error:errorOrNil]) {
    return NO;
  }

  NSArray *touchPath = @[ [NSValue valueWithCGPoint:resolvedLocation] ];
  [GREYSyntheticEvents touchAlongPath:touchPath relativeToWindow:window forDuration:duration];
  return YES;
}

#pragma mark - Private

/**
 *  @return A tappable point that has the given @c location relative to the window of the
 *          @c element.
 */
+ (CGPoint)grey_tapPointForElement:(id)element relativeLocation:(CGPoint)location {
  __block CGPoint tapPoint;
  grey_dispatch_sync_on_main_thread(^{
    UIView *viewToTap =
        ([element isKindOfClass:[UIView class]] ? element : [element grey_viewContainingSelf]);
    UIWindow *window =
        ([viewToTap isKindOfClass:[UIWindow class]] ? (UIWindow *)viewToTap : viewToTap.window);

    if (viewToTap != element) {
      // Convert elementOrigin to parent's coordinates.
      CGPoint elementOrigin = [element accessibilityFrame].origin;
      elementOrigin = [window convertPoint:elementOrigin fromWindow:nil];
      elementOrigin = [viewToTap convertPoint:elementOrigin fromView:nil];
      elementOrigin.x += location.x;
      elementOrigin.y += location.y;
      tapPoint = [viewToTap convertPoint:elementOrigin toView:nil];
    } else {
      tapPoint = [viewToTap convertPoint:location toView:nil];
    }
  });
  return tapPoint;
}

/**
 *  If the specified @c location is not in the bounds of the specified @c window for performing the
 *  specified action, the mthod will return @c NO and if @ errorOrNil is provided, it is populated
 *  with appropriate error information. Otherwise @c YES is returned.
 *
 *  @param      location   The location of the touch.
 *  @param      window     The window in which the action is being performed.
 *  @param      name       The name of the action causing the touch.
 *  @param[out] errorOrNil The error set on failure. The error returned can be @c nil, signifying
 *                         success.
 *
 *  @return @c YES if the @c location is in the bounds of the @c window, @c NO otherwise.
 */
+ (BOOL)grey_checkLocation:(CGPoint)location
          inBoundsOfWindow:(UIWindow *)window
            forActionNamed:(NSString *)name
                     error:(__strong NSError **)errorOrNil {
  // Don't use frame because if transform property isn't identity matrix, the frame property is
  // undefined.
  __block NSString *windowBoundsString;
  grey_dispatch_sync_on_main_thread(^{
    if (!CGRectContainsPoint(window.bounds, location)) {
      windowBoundsString = NSStringFromCGRect(window.bounds);
    }
  });

  if (windowBoundsString) {
    NSString *nullLocationReason = @"";
    if (CGPointIsNull(location)) {
      nullLocationReason =
          @"The {nan, nan} point means that the element's frame does not have a point within "
          @"itself that a touch can be injected in as it is obscured. Consider adding the "
          @"grey_interactable() matcher to the selection matcher.";
    }
    NSString *description =
        [NSString stringWithFormat:@"Cannot perform %@ at %@ as it is outside window's bounds %@. "
                                   @"%@.",
                                   name, NSStringFromCGPoint(location), windowBoundsString,
                                   nullLocationReason];

    I_GREYPopulateError(errorOrNil, kGREYInteractionErrorDomain,
                        kGREYInteractionActionFailedErrorCode, description);

    return NO;
  }
  return YES;
}

@end
