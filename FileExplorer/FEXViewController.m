//
//  FEXViewController.m
//  FileExplorer
//
//  Created by Uli Kusterer on 21/11/15.
//  Copyright © 2015 Uli Kusterer. All rights reserved.
//

#import "FEXViewController.h"
#import "UKKQueue.h"
#import "UKFSEventsWatcher.h"


#if 0
#define FEXFileWatcherClass	UKFSEventsWatcher
#else
#define FEXFileWatcherClass	UKKQueue
#endif


@interface FEXController () <UKFileWatcherDelegate>
{
	NSString	*	_folderPath;
}

@property (strong) id<UKFileWatcher>		fileWatcher;
@property (copy) NSString*					folderPath;
@property (strong) NSMutableArray*			files;

@end


@interface FEXViewController ()

@property (strong) IBOutlet NSTableView*	tableView;

@end




@interface FEXFileEntry : NSObject
{
	NSString	*	_displayName;
	NSImage		*	_icon;
}

@property (strong) NSString*			filePath;
@property (strong) NSString*			fileName;
@property (strong,readonly) NSString*	displayName;
@property (strong,readonly) NSImage*	icon;

-(instancetype)	initWithFilePath: (NSString*)inFilePath fileName: (NSString*)inFileName;

@end


@implementation FEXFileEntry

-(instancetype)	initWithFilePath: (NSString*)inFilePath fileName: (NSString*)inFileName
{
	self = [super init];
	if( self )
	{
		self.filePath = inFilePath;
		self.fileName = inFileName;
	}
	return self;
}


-(NSString*)	displayName
{
	if( !_displayName )	// Lazy-load display name.
	{
		_displayName = [NSFileManager.defaultManager displayNameAtPath: self.filePath];
	}
	return _displayName;
}


-(NSImage*)	icon
{
	if( !_icon )	// Lazy-load file icon.
	{
		_icon = [NSWorkspace.sharedWorkspace iconForFile: self.filePath];
	}
	return _icon;
}


-(NSString*)	description
{
	return [NSString stringWithFormat: @"%@ <%p> \"%@\" { path = %@, icon = <%p> }", self.class, self, _displayName ? _displayName : _fileName, _filePath, _icon];
}

@end


@implementation FEXController

-(instancetype) init
{
	if( self = [super init])
	{
		_files = [NSMutableArray new];
		
		_fileWatcher = [FEXFileWatcherClass new];
		[_fileWatcher setDelegate: self];
	}
	
	return self;
}


-(void)	setFolderPath: (NSString *)folderPath
{
	if( _folderPath )
	{
		[self.fileWatcher removePath: _folderPath];
	}
	_folderPath = folderPath;
	[self.files removeAllObjects];
	if( _folderPath )
	{
		[self.fileWatcher addPath: folderPath];
		[self updateFileList];
	}
}


-(NSString*)	folderPath
{
	return _folderPath;
}


-(void)	watcher:(id<UKFileWatcher>)kq receivedNotification:(NSString *)nm forPath:(NSString *)fpath
{
	[self updateFileList];
}


-(void)	updateFileList
{
	BOOL delegateWantsAddMessages = [_delegate respondsToSelector: @selector(fileController:addedFile:)];
	BOOL delegateWantsRemoveMessages = [_delegate respondsToSelector: @selector(fileController:removedFile:)];
	
	NSMutableArray	*	newFiles = [NSMutableArray new];
	NSArray			*	filePaths = [NSFileManager.defaultManager contentsOfDirectoryAtPath: self.folderPath  error: NULL];
	NSEnumerator	*	oldFileEnny = self.files.objectEnumerator;
	FEXFileEntry	*	currOldFile = oldFileEnny.nextObject;
	
	for( NSString* currFile in filePaths )
	{
		if( [currFile hasPrefix: @"."] )
			continue;
		NSString	*	currPath = [self.folderPath stringByAppendingPathComponent: currFile];
		NSNumber	*	hiddenValue = nil;
		if( [[NSURL fileURLWithPath: currPath] getResourceValue: &hiddenValue forKey: NSURLIsHiddenKey error: NULL] )
		{
			if( [hiddenValue boolValue] )
				continue;
		}
		
		BOOL	retry = false;
		do
		{
			retry = false;
			NSComparisonResult	order = currOldFile ? [currOldFile.fileName compare: currFile] : NSOrderedAscending;
			if( order == NSOrderedSame )
			{
				[newFiles addObject: currOldFile];	// File still there, keep it.
				currOldFile = oldFileEnny.nextObject;
			}
			else if( order == NSOrderedAscending )
			{
				// Current higher than old file? Current is new, add it!
				[newFiles addObject: [[FEXFileEntry alloc] initWithFilePath: currPath fileName: currFile]];
				if( delegateWantsAddMessages )
					[_delegate fileController: self addedFile: currPath];
			}
			else if( order == NSOrderedDescending )	// Current lower than old file? Old file got removed, don't take it along, but try current against next old file again.
			{
				if( delegateWantsRemoveMessages )
					[_delegate fileController: self removedFile: currOldFile.fileName];
				
				currOldFile = oldFileEnny.nextObject;
				retry = true;
			}
		}
		while( retry );
	}
	self.files = newFiles;
}

@end


@implementation FEXViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	FEXController *fileController = [FEXController new];
	fileController.delegate = self;
	
	if( !fileController.folderPath )
	{
		fileController.folderPath = [@"~" stringByExpandingTildeInPath];
	}
	self.fileController = fileController;
}


- (void)setRepresentedObject:(id)representedObject
{
	[super setRepresentedObject:representedObject];
	
	self.fileController.folderPath = [(FEXFileEntry*)representedObject filePath];
}


-(IBAction)	rowDoubleClicked: (id)sender
{
	FEXViewController*	vc = [self.storyboard instantiateControllerWithIdentifier: @"FolderController"];
	vc.representedObject = self.fileController.files[self.tableView.clickedRow];
	self.view.window.contentViewController = vc;
}


- (void)viewDidAppear
{
	self.view.window.representedFilename = self.fileController.folderPath;
	self.view.window.title = [NSFileManager.defaultManager displayNameAtPath: self.fileController.folderPath];
}


-(void) fileController: (FEXController *)sender addedFile: (NSString *)inPath
{
	self.view.window.representedFilename = self.fileController.folderPath;
	self.view.window.title = [NSFileManager.defaultManager displayNameAtPath: self.fileController.folderPath];
}


-(void) fileController: (FEXController *)sender removedFile: (NSString *)inPath
{
	self.view.window.representedFilename = self.fileController.folderPath;
	self.view.window.title = [NSFileManager.defaultManager displayNameAtPath: self.fileController.folderPath];
}

@end
