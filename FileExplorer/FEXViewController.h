//
//  FEXViewController.h
//  FileExplorer
//
//  Created by Uli Kusterer on 21/11/15.
//  Copyright © 2015 Uli Kusterer. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class FEXController;


@protocol FEXControllerDelegate <NSObject>

@optional
-(void) fileController: (FEXController *)sender addedFile: (NSString *)inPath;
-(void) fileController: (FEXController *)sender removedFile: (NSString *)inPath;

@end


@interface FEXController : NSObject

@property (weak) id<FEXControllerDelegate> delegate;

@end


@interface FEXViewController : NSViewController <FEXControllerDelegate>

@property FEXController *fileController;

@end

