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


@interface FEXViewController () <UKFileWatcherDelegate>
{
	NSString	*	_folderPath;
}

@property (strong) id<UKFileWatcher>		fileWatcher;
@property (copy) NSString*					folderPath;
@property (strong) NSMutableArray*			files;
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


@implementation FEXViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if( !self.files )
	{
		self.files = [NSMutableArray new];
		
		self.fileWatcher = [FEXFileWatcherClass new];
		[self.fileWatcher setDelegate: self];
	}
	
	if( !self.folderPath )
	{
		self.folderPath = [@"~" stringByExpandingTildeInPath];
	}
}

- (void)setRepresentedObject:(id)representedObject
{
	[super setRepresentedObject:representedObject];
	
	if( !self.files )
	{
		self.files = [NSMutableArray new];
		
		self.fileWatcher = [FEXFileWatcherClass new];
		[self.fileWatcher setDelegate: self];
	}
	
	self.folderPath = [(FEXFileEntry*)representedObject filePath];
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


-(IBAction)	rowDoubleClicked: (id)sender
{
	FEXViewController*	vc = [self.storyboard instantiateControllerWithIdentifier: @"FolderController"];
	vc.representedObject = self.files[self.tableView.clickedRow];
	self.view.window.contentViewController = vc;
}


-(void)	watcher:(id<UKFileWatcher>)kq receivedNotification:(NSString *)nm forPath:(NSString *)fpath
{
	[self updateFileList];
}


- (void)viewDidAppear
{
	self.view.window.representedFilename = self.folderPath;
	self.view.window.title = [NSFileManager.defaultManager displayNameAtPath: self.folderPath];
}


-(void)	updateFileList
{
	self.view.window.representedFilename = self.folderPath;
	self.view.window.title = self.title = [NSFileManager.defaultManager displayNameAtPath: self.folderPath];
	
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
			}
			else if( order == NSOrderedDescending )	// Current lower than old file? Old file got removed, don't take it along, but try current against next old file again.
			{
				currOldFile = oldFileEnny.nextObject;
				retry = true;
			}
		}
		while( retry );
	}
	self.files = newFiles;
}

@end
