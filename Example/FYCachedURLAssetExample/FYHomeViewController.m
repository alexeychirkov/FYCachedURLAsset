/*
 MIT License
 
 Copyright (c) 2015 Factorial Complexity
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 */

#import "FYHomeViewController.h"
#import "FYPlaybackViewController.h"

// Models
#import "FYCachedURLAsset.h"
#import "FYContentProvider.h"
#import "FYTableCellItem.h"
#import "FYHeaderItem.h"
#import "FYSectionItem.h"
#import "FYMediaItem.h"
#import "FYTextFieldItem.h"
#import "FYSeparatorItem.h"

// Cells
#import "FYTableViewCell.h"
#import "FYHeaderCell.h"
#import "FYSectionItem.h"
#import "FYMediaCell.h"
#import "FYTextFieldCell.h"
#import "FYSeparatorCell.h"

@interface FYHomeViewController ()
<
UITableViewDelegate,
UITableViewDataSource
>
@end


@implementation FYHomeViewController {
	NSArray<id<FYTableCellItem>> *_rowsDatasource;
	
	NSMutableArray<FYMediaItem*>* _userMediaFiles;
	
	__weak IBOutlet UITableView *_tableView;
	
	__weak IBOutlet UIView *_addMediaView;
	__weak IBOutlet UITextField *_addMediaTextField;
	__weak IBOutlet UIButton *_addMediaButton;
	
	__weak IBOutlet NSLayoutConstraint *_footerBottonConstraint;
}

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	[self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	[self loadMediaFiles];
	
	_tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 40;
	
	_addMediaTextField.layer.borderColor = [[UIColor colorWithRed:232.0 / 255 green:232.0 / 255 blue:232.0 / 255 alpha:1] CGColor];
	_addMediaTextField.layer.borderWidth = 1;
	
	_addMediaTextField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 0)];
	_addMediaTextField.leftViewMode = UITextFieldViewModeAlways;
	
	_addMediaButton.enabled = NO;
	
	[_addMediaButton setTitleColor:[UIColor colorWithRed:75.0 / 255 green:90.0 / 255 blue:191.0 / 255 alpha:0.5] forState:UIControlStateDisabled];
	
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
	[tap setCancelsTouchesInView:NO];
	[_tableView addGestureRecognizer:tap];
	
	[self subscribeKeyboardNotifications];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	[self updateDatasource];
}

#pragma mark - Callbacks

- (void)dismissKeyboard {
	[self.view endEditing:YES];
}

- (IBAction)textChanged:(id)sender {
	_addMediaButton.enabled = _addMediaTextField.text.length > 0;
}

- (IBAction)textDidEndOnExit:(id)sender {
	[self addMediaFileWithUrl:[NSURL URLWithString:_addMediaTextField.text]];
}

- (IBAction)addClicked:(id)sender {
	[self addMediaFileWithUrl:[NSURL URLWithString:_addMediaTextField.text]];
	
	[_addMediaTextField resignFirstResponder];
}

#pragma mark - Private

- (NSString*)documentDirectory {
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

- (void)loadMediaFiles {
	NSData* mediaFilesData = [NSData dataWithContentsOfFile:[[self documentDirectory] stringByAppendingPathComponent:@"media.plist"]];
	
	if (mediaFilesData) {
		_userMediaFiles = [NSKeyedUnarchiver unarchiveObjectWithData:mediaFilesData];
	}

	if (!_userMediaFiles) {
		_userMediaFiles = [NSMutableArray new];
	}
}

- (void)saveMediaFiles {
	NSData* mediaFilesData = [NSKeyedArchiver archivedDataWithRootObject:_userMediaFiles];
	
	[mediaFilesData writeToFile:[[self documentDirectory] stringByAppendingPathComponent:@"media.plist"] atomically:YES];
}

- (void)updateDatasource {
    NSMutableArray<id<FYTableCellItem>>* rowsDatasource = [NSMutableArray new];
	
	[rowsDatasource addObject:[[FYHeaderItem alloc] initWithText:@"FY Cached URL Asset"]];
    
    [rowsDatasource addObject:[[FYSectionItem alloc] initWithText:@"MEDIA FILES EXAMPLES"]];
	
	[rowsDatasource addObject:[FYSeparatorItem new]];

	[rowsDatasource addObject:[[FYMediaItem alloc] initWithMediaName:@"Crowd Cheering.mp3" mediaUrl:@"http://www.sample-videos.com/audio/mp3/crowd-cheering.mp3" mediaSize:443926 mediaLength:27 cacheFilePath:nil]];
	
	[rowsDatasource addObject:[FYSeparatorItem new]];

	[rowsDatasource addObject:[[FYMediaItem alloc] initWithMediaName:@"Wave.mp3" mediaUrl:@"http://www.sample-videos.com/audio/mp3/wave.mp3" mediaSize:725240 mediaLength:45 cacheFilePath:nil]];
	
	[rowsDatasource addObject:[FYSeparatorItem new]];

	[rowsDatasource addObject:[[FYMediaItem alloc] initWithMediaName:@"Big Buck Bunny.mp4" mediaUrl:@"https://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_10mb.mp4" mediaSize:10498677 mediaLength:62 cacheFilePath:nil]];
	
	[rowsDatasource addObject:[FYSeparatorItem new]];

	[rowsDatasource addObject:[[FYMediaItem alloc] initWithMediaName:@"Big Buck Bunny.mp4" mediaUrl:@"https://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_30mb.mp4" mediaSize:31491130 mediaLength:170 cacheFilePath:nil]];
	
	[rowsDatasource addObject:[FYSeparatorItem new]];

	[rowsDatasource addObject:[[FYMediaItem alloc] initWithMediaName:@"mov file" mediaUrl:@"http://file-examples.com/wp-content/uploads/2018/04/file_example_MOV_1920_2_2MB.mov" mediaSize:(int)(2.2f * 1024.0f * 1024.0f) mediaLength:30 cacheFilePath:nil]];

	[rowsDatasource addObject:[FYSeparatorItem new]];

	NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	NSString *cacheFilePath = [documentsPath stringByAppendingPathComponent:@"hi25.mp4"];
	[rowsDatasource addObject:[[FYMediaItem alloc] initWithMediaName:@"hi25" mediaUrl:@"https://s3-eu-west-1.amazonaws.com/storychat-pix-video-prod/330869/0?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJ3FGVFKFVFEEJPRQ/20190319/eu-west-1/s3/aws4_request&X-Amz-Date=20190319T102701Z&X-Amz-Expires=90000&X-Amz-SignedHeaders=host&X-Amz-Signature=a6f6a62744f9d0273aa67439e3d6ab3969bc09c06353e1cc3f43f7e1c181c05b" mediaSize:1005702 mediaLength:10 cacheFilePath:cacheFilePath]];

	if (_userMediaFiles.count > 0) {
		[rowsDatasource addObject:[FYSeparatorItem new]];
		
		[rowsDatasource addObject:[[FYSectionItem alloc] initWithText:@"YOUR MEDIA FILES"]];
		
		for (FYMediaItem* mediaFile in _userMediaFiles) {
			[rowsDatasource addObject:[FYSeparatorItem new]];
			
			[rowsDatasource addObject:mediaFile];
		}
	}
	
    _rowsDatasource = [rowsDatasource copy];
	
	[_tableView reloadData];
}

- (void)addMediaFileWithUrl:(NSURL*)url {
	if (url && [url scheme] && [url host]) {
		NSString* mediaName = ([url lastPathComponent].length > 0) ? [url lastPathComponent] : [url absoluteString];
		
		FYMediaItem* mediaItem = [[FYMediaItem alloc] initWithMediaName:mediaName mediaUrl:[url absoluteString] mediaSize:0 mediaLength:0 cacheFilePath:nil];
		
		[_userMediaFiles addObject:mediaItem];
		
		_addMediaTextField.text = @"";
		_addMediaButton.enabled = NO;
		
		[self saveMediaFiles];
		
		[self updateDatasource];
		
		[self openMedia:mediaItem];
	} else {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Invalid Media File URL"
																		message:nil
																 preferredStyle:UIAlertControllerStyleAlert];
		
		UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK"
														   style:UIAlertActionStyleDefault
														 handler:nil];
		
		[alert addAction:okButton];
		
		[self presentViewController:alert animated:YES completion:nil];
	}
}

- (void)openMedia:(FYMediaItem*)mediaItem {
	__typeof(self) __weak weakSelf = self;
	
	FYPlaybackViewController* playbackViewController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"FYPlaybackViewController"];
	
	playbackViewController.mediaItem = mediaItem;
	if (!mediaItem.hasMediaLength) {
		// subscribe for media length/size callback
		playbackViewController.mediaPropertiesCallback = ^(int64_t mediaSize, int32_t mediaLength) {
			__typeof(weakSelf) __strong strongSelf = weakSelf;
			
			if (strongSelf) {
				mediaItem.mediaSize = mediaSize;
				mediaItem.mediaLength = mediaLength;
				
				[strongSelf saveMediaFiles];
				
				[strongSelf updateDatasource];
			}
		};
	}
	
	[self.navigationController pushViewController:playbackViewController animated:YES];
}

- (void)keyboardWillShow:(NSNotification *)notification {
	CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	
	[self.view layoutIfNeeded];
	[UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^ {
		_footerBottonConstraint.constant = keyboardFrame.size.height;
		[self.view layoutIfNeeded];
	} completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)notification {
	[self.view layoutIfNeeded];
	[UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^ {
		_footerBottonConstraint.constant = 0;
		[self.view layoutIfNeeded];
	} completion:nil];
}

- (void)subscribeKeyboardNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillShow:)
												 name:UIKeyboardWillShowNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillHide:)
												 name:UIKeyboardWillHideNotification
											   object:nil];
}

#pragma mark - UITableViewDelegate/Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return _rowsDatasource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	__typeof(self) __weak weakSelf = self;
	
    id<FYTableCellItem> item = _rowsDatasource[indexPath.row];
    
    FYTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([item class])];
    
    cell.item = item;
	
	if ([cell isKindOfClass:[FYTextFieldCell class]]) {
		FYTextFieldCell* textFieldCell = (FYTextFieldCell*)cell;
		
		textFieldCell.textAddedCallback = ^(NSString* text) {
			__typeof(weakSelf) __strong strongSelf = weakSelf;
			
			if (strongSelf) {
				[strongSelf addMediaFileWithUrl:[NSURL URLWithString:text]];
			}
		};
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id<FYTableCellItem> item = _rowsDatasource[indexPath.row];
	
    if ([item isKindOfClass:[FYMediaItem class]]) {
		[self openMedia:(FYMediaItem*)item];
    }    
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	id<FYTableCellItem> item = _rowsDatasource[indexPath.row];
	
	if ([item isKindOfClass:[FYMediaItem class]]) {
		FYMediaItem* mediaItem = (FYMediaItem*)item;
		
		return [_userMediaFiles containsObject:mediaItem];
	}
	
	return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		id<FYTableCellItem> item = [_rowsDatasource objectAtIndex:indexPath.row];
		
		FYMediaItem* mediaItem = (FYMediaItem*)item;
		
		[_userMediaFiles removeObject:mediaItem];
		
		[self saveMediaFiles];
		
		[self updateDatasource];
	}
}

@end
