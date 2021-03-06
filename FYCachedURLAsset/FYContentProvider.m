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

#import "FYContentProvider.h"
#import "FYSerialContentLoader.h"
#import "FYRandomAccessContentLoader.h"
#import "FYCachedURLAsset.h"
#import "FYCachedURLAssetLog.h"

static NSMutableSet* g_FYContentProviders = nil;


@interface FYCachedURLAsset ()

- (void)failWithPermanentError:(NSError*)permanentError;

@end


@interface FYContentProvider () <FYSerialContentLoaderDelegate, FYRandomAccessContentLoaderDelegate>
{
	FYSerialContentLoader* _serialContentLoader;
	NSMutableSet* _randomAccessLoaders;
	NSMutableSet* _requestsForContentInformationOnly;
	
	NSMutableArray* _assets;
}

@end


@implementation FYContentProvider

+ (FYContentProvider*)contentProviderWithURL:(NSURL*)URL cacheFilePath:(NSString*)cacheFilePath
	asset:(FYCachedURLAsset*)asset
{
	if (!g_FYContentProviders)
		g_FYContentProviders = [[NSMutableSet alloc] init];

	FYContentProvider* contentProvider = nil;
	for (FYContentProvider* cp in g_FYContentProviders)
	{
		if ([cp.cacheFilePath isEqualToString:cacheFilePath])
		{
//			NSAssert([cp.URL isEqual:URL], @"Different URL is already being cached into this path");
			contentProvider = cp;
			break;
		}
	}
	
	if (!contentProvider)
	{
		contentProvider = [[FYContentProvider alloc] initWithURL:URL cacheFilePath:cacheFilePath];
		[g_FYContentProviders addObject:contentProvider];
	}
	
	[asset.resourceLoader setDelegate:contentProvider queue:dispatch_get_main_queue()];
	[contentProvider addAsset:asset];
	
	return contentProvider;
}

- (instancetype)initWithURL:(NSURL*)URL cacheFilePath:(NSString*)cacheFilePath
{
	if ((self = [super init]))
	{
		_URL = URL;
		_cacheFilePath = cacheFilePath;
		
		_serialContentLoader = [[FYSerialContentLoader alloc] initWithURL:URL cacheFilePath:cacheFilePath
			delegate:self];
		_randomAccessLoaders = [[NSMutableSet alloc] init];
		_requestsForContentInformationOnly = [[NSMutableSet alloc] init];
		
		_assets = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)cancel {
	[_serialContentLoader stopDownloading];
	for (FYRandomAccessContentLoader* loader in _randomAccessLoaders)
		[loader cancel];
}

- (void)dealloc
{
	[self cancel];
	
	FYLogD(@"[FYContentProvider dealloc]\n   URL: %@\n  cacheFilePath: %@", _URL, _cacheFilePath);
}

- (void)addAsset:(FYCachedURLAsset*)asset
{
	[_assets addObject:[NSValue valueWithPointer:(__bridge const void *)(asset)]];
}

- (void)removeAsset:(FYCachedURLAsset*)asset
{
	[_assets removeObject:[NSValue valueWithPointer:(__bridge const void *)(asset)]];
	
	if ([_assets count] == 0)
	{
		[g_FYContentProviders removeObject:self];
	}
}

- (void)addResourceLoadingRequest:(AVAssetResourceLoadingRequest*)loadingRequest
{
	if (loadingRequest.dataRequest)
	{
		if (loadingRequest.dataRequest.requestedOffset <= (_serialContentLoader.availableData + 512*512))
			[_serialContentLoader addLoadingRequest:loadingRequest];
		else
		{
			FYRandomAccessContentLoader* randomAccessContentLoader = [[FYRandomAccessContentLoader alloc] initWithURL:_URL
				loadingRequest:loadingRequest delegate:self];
			[_randomAccessLoaders addObject:randomAccessContentLoader];
		}
	}
	else if (loadingRequest.contentInformationRequest)
	{
		[_requestsForContentInformationOnly addObject:loadingRequest];
	}
}

- (void)removeResourceLoadingRequest:(AVAssetResourceLoadingRequest*)loadingRequest
{
	[_serialContentLoader removeLoadingRequest:loadingRequest];
	
	for (FYRandomAccessContentLoader* randomAccessLoader in _randomAccessLoaders)
	{
		if (randomAccessLoader.loadingRequest == loadingRequest)
		{
			[randomAccessLoader cancel];
			[_randomAccessLoaders removeObject:randomAccessLoader];
			break;
		}
	}
}

- (void)updateContentInformationRequest:(AVAssetResourceLoadingContentInformationRequest*)contentInformationRequest
{
	contentInformationRequest.contentType = _serialContentLoader.contentType;
	contentInformationRequest.byteRangeAccessSupported = YES;
	
	if (_serialContentLoader.contentLength > 0) // we know content length
		contentInformationRequest.contentLength = _serialContentLoader.contentLength;
}

- (long long)contentLength
{
	return _serialContentLoader.contentLength;
}

- (long long)availableDataOnDisk
{
	return _serialContentLoader.availableDataOnDisk;
}

- (long long)availableData
{
	return _serialContentLoader.availableData;
}

- (void)failWithPermanentError:(NSError*)permanentError
{
	FYContentProvider* sself = self;
	[g_FYContentProviders removeObject:self];
	
	_permanentError = permanentError;
	for (NSValue* pAsset in _assets)
	{
		FYCachedURLAsset* asset = (FYCachedURLAsset*)[pAsset pointerValue];
		[asset failWithPermanentError:permanentError];
	}
	[_assets removeAllObjects];
	
	sself = nil;
}

#pragma mark - FYRandomAccessContentLoaderDelegate

- (void)randomAccessContentLoaderDidFinishLoading:(FYRandomAccessContentLoader*)loader
{
	[_randomAccessLoaders removeObject:loader];
}

- (void)randomAccessContentLoaderDidInvalidateCache:(FYRandomAccessContentLoader*)loader withError:(NSError*)error
{
	FYLogI(@"RESOURCE UPDATED ON SERVER\n   URL: %@\n  cacheFilePath: %@", _URL, _cacheFilePath);
	
	[_serialContentLoader removeCacheAndStopAllRequestsWithError:error];
	
	[_randomAccessLoaders removeObject:loader];
	for (FYRandomAccessContentLoader* randomAccessLoader in _randomAccessLoaders)
	{
		[randomAccessLoader cancel];
		[randomAccessLoader.loadingRequest finishLoadingWithError:error];
	}
	[_randomAccessLoaders removeAllObjects];
	
	for (AVAssetResourceLoadingRequest* loadingRequest in _requestsForContentInformationOnly)
	{
		[loadingRequest finishLoadingWithError:error];
	}
	[_requestsForContentInformationOnly removeAllObjects];
	
	[self failWithPermanentError:error];
}

- (BOOL)hasETagForRandomAccessContentLoader:(FYRandomAccessContentLoader *)loader
{
	return _serialContentLoader.hasContentInformation;
}

- (NSString*)eTagForRandomAccessContentLoader:(FYRandomAccessContentLoader *)loader
{
	return _serialContentLoader.eTag;
}

#pragma mark - FYSerialContentLoaderDelegate

- (void)serialContentLoaderDidUpdateMeta:(FYSerialContentLoader*)loader
{
	for (AVAssetResourceLoadingRequest* loadingRequest in _serialContentLoader.loadingRequests)
	{
		if (loadingRequest.contentInformationRequest)
			[self updateContentInformationRequest:loadingRequest.contentInformationRequest];
	}
	
	for (FYRandomAccessContentLoader* randomAccessLoader in _randomAccessLoaders)
	{
		if (randomAccessLoader.loadingRequest.contentInformationRequest)
			[self updateContentInformationRequest:randomAccessLoader.loadingRequest.contentInformationRequest];
	}
	
	for (AVAssetResourceLoadingRequest* loadingRequest in _requestsForContentInformationOnly)
	{
		[self updateContentInformationRequest:loadingRequest.contentInformationRequest];
		[loadingRequest finishLoading];
	}
	[_requestsForContentInformationOnly removeAllObjects];
}

- (void)serialContentLoaderDidInvalidateCache:(FYSerialContentLoader*)loader withError:(NSError*)error
{
	FYLogI(@"RESOURCE UPDATED ON SERVER\n   URL: %@\n  cacheFilePath: %@", _URL, _cacheFilePath);
	
	for (FYRandomAccessContentLoader* randomAccessLoader in _randomAccessLoaders)
	{
		[randomAccessLoader cancel];
		[randomAccessLoader.loadingRequest finishLoadingWithError:error];
	}
	[_randomAccessLoaders removeAllObjects];
	
	for (AVAssetResourceLoadingRequest* loadingRequest in _requestsForContentInformationOnly)
	{
		[loadingRequest finishLoadingWithError:error];
	}
	[_requestsForContentInformationOnly removeAllObjects];
	
	[self failWithPermanentError:error];
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader*)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest*)loadingRequest
{
	FYLogD(@"NEW REQUEST (%llx)\n  Content information: %@\n  Offset: %lld\n  Length: %lld",
		(long long)loadingRequest,
		loadingRequest.contentInformationRequest ? @"Y" : @"N",
		loadingRequest.dataRequest ? loadingRequest.dataRequest.requestedOffset : 0,
		loadingRequest.dataRequest ? (long long)loadingRequest.dataRequest.requestedLength : 0);

	if (_permanentError)
	{
		FYLogD(@"PERMANENT RESOURCE LOADING ERROR: %@", _permanentError);
		return NO;
	}
	
	if (loadingRequest.contentInformationRequest)
	{
		if (_serialContentLoader.hasContentInformation)
			[self updateContentInformationRequest:loadingRequest.contentInformationRequest];
	}
	
	[self addResourceLoadingRequest:loadingRequest];
	return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader*)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest*)loadingRequest
{
	FYLogD(@"CANCEL REQUEST (%llx)", (long long)loadingRequest);
	
	[self removeResourceLoadingRequest:loadingRequest];
}

@end
