//
//  CLImageEditor.m
//
//  Created by sho yakushiji on 2013/10/17.
//  Copyright (c) 2013年 CALACULU. All rights reserved.
//

#import "CLImageEditor.h"

#import "_CLImageEditorViewController.h"

@interface CLImageEditor ()

@end


@implementation CLImageEditor

- (UIImageView*)imageView
{
   NSParameterAssert(false);
   return nil;
}

- (CLImageEditorTheme*)theme
{
   return [CLImageEditorTheme theme];
}


- (CLImageToolInfo*)toolInfo
{
   NSParameterAssert(false);
   return nil;
}

- (id)init
{
    return [_CLImageEditorViewController new];
}

- (id)initWithImage:(UIImage*)image
{
    return [self initWithImage:image delegate:nil];
}

- (id)initWithImage:(UIImage*)image delegate:(id<CLImageEditorDelegate>)delegate
{
    return [[_CLImageEditorViewController alloc] initWithImage:image delegate:delegate];
}

- (id)initWithDelegate:(id<CLImageEditorDelegate>)delegate
{
    return [[_CLImageEditorViewController alloc] initWithDelegate:delegate];
}

- (id<UIViewControllerAnimatedTransitioning>)presentTransitionFromView:(UIView*)view
{
   return nil;
}

- (id<UIViewControllerAnimatedTransitioning>)dismissTransitionToView:(UIView*)view
{
   return nil;
}

- (void)selectMenuItemWithToolName:(NSString*)toolName
{
    
}

@end

