//
//  KTAbstractPage+Paths.m
//  Marvel
//
//  Created by Mike on 05/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//
//	Provides access to various paths and URLs describing how to get to the page.
//	All methods have 1 of 3 prefixes:
//		published	- For accessing the published page via HTTP
//		upload		- When accessing the site for publishing via FTP, SFTP etc.
//		preview		- For previewing the page within the Sandvox UI

#import "KTAbstractPage.h"


#import "Debug.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTMaster.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSMutableSet+Karelia.h"
#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"


@interface KTAbstractPage (PathsPrivate)
- (NSString *)indexFilename;
- (NSString *)pathRelativeToParentWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle;
- (NSString *)pathRelativeToSiteWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle;
@end


#pragma mark -


@implementation KTAbstractPage (Paths)

#pragma mark -
#pragma mark File Name

/*	First we have a simple accessor pair for the file name. This does NOT include the extension.
 */
- (NSString *)fileName { return [self wrappedValueForKey:@"fileName"]; }

- (void)setFileName:(NSString *)fileName
{
	[self setWrappedValue:fileName forKey:@"fileName"];
	[self invalidatePathRelativeToSiteRecursive:YES];	// For collections this affects all children
}

/*	Looks at sibling pages and the page title to determine the best possible filename.
 *	Guaranteed to return something unique.
 */
- (NSString *)suggestedFileName
{
	// The home page's title isn't settable, so keep it constant
	if ([self isRoot]) return nil;
	
	
	// Build a list of the file names already taken
	NSSet *siblingFileNames = [[[self parent] children] valueForKey:@"fileName"];
	NSSet *archiveFileNames = [[self parent] valueForKeyPath:@"archivePages.fileName"];
	NSMutableSet *unavailableFileNames = [NSMutableSet setWithCapacity:([siblingFileNames count] + [archiveFileNames count])];
	[unavailableFileNames unionSet:siblingFileNames];
	[unavailableFileNames unionSet:archiveFileNames];
	[unavailableFileNames removeObjectIgnoringNil:[self fileName]];
	
	// Get the preferred filename by converting to lowercase, spaces to _, & removing everything else
	NSString *result = [[self titleText] legalizeFileNameWithFallbackID:[self uniqueID]];
	NSString *baseFileName = result;
	int suffixCount = 2;
	
	// Now munge it to make it unique.  Keep adding a number until we find an open slot.
	while ([unavailableFileNames containsObject:result])
	{
		result = [baseFileName stringByAppendingFormat:@"_%d", suffixCount++];
	}
	
	OBPOSTCONDITION(result);
	
	return result;
}

#pragma mark -
#pragma mark File Extension

/*	If set, returns the custom file extension. Otherwise, takes the value from the defaults
 */
- (NSString *)fileExtension
{
	NSString *result = [self customFileExtension];
	
	if (!result)
	{
		result = [self defaultFileExtension];
	}
	
	return result;
}

/*	Implemented just to stop anyone accidentally calling it.
 */
- (void)setFileExtension:(NSString *)extension
{
	[NSException raise:NSInternalInconsistencyException
			    format:@"-%@ is not supported. Please use -setCustomFileExtension instead.", NSStringFromSelector(_cmd)];
}


/*	A custom file extension of nil signifies that the value should be taken from the user defaults.
 */
- (NSString *)customFileExtension { return [self wrappedValueForKey:@"customFileExtension"]; }

- (void)setCustomFileExtension:(NSString *)extension
{
	[self setWrappedValue:extension forKey:@"customFileExtension"];
	[self invalidatePathRelativeToSiteRecursive:NO];
}


/*	Super-simple accessor that determines the editing UI available to the user in the Page Details area.
 *	By default, set to true. The File Download and External Link plugins use this to disable editing.
 */
- (BOOL)fileExtensionIsEditable { return [self wrappedBoolForKey:@"fileExtensionIsEditable"]; }

- (void)setFileExtensionIsEditable:(BOOL)editable { [self setWrappedBool:editable forKey:@"fileExtensionIsEditable"]; }


/*	The value -fileExtension should return if there is no custom extensions set.
 *	Mainly used for bindings.
 */
- (NSString *)defaultFileExtension
{
	NSString *result = [[NSUserDefaults standardUserDefaults] objectForKey:@"fileExtension"];
	
	if (!result || [result isEqualToString:@""])
	{
		result = @"html";
	}
	
	return result;
}

/*	All custom file extensions available for the receiver. Mainly used for bindings.
 */
- (NSArray *)availableFileExtensions
{
	NSArray *result = [NSArray arrayWithObjects:@"html", @"htm", @"php", @"shtml", @"asp", nil];
	return result;
}

#pragma mark -
#pragma mark Filenames & Extensions

/*	The correct filename for the index.html file, taking into account user defaults and any custom settings
 *	If not a collection, returns nil.
 */
- (NSString *)indexFilename
{
	NSString *result = nil;
	
	if ([self isCollection])
	{
		NSString *indexFileName = [self valueForKeyPath:@"document.documentInfo.hostProperties.htmlIndexBaseName"];
		OBASSERT([self fileExtension]);
		result = [indexFileName stringByAppendingPathExtension:[self fileExtension]];
	}
	
	return result;
}

/*	Used for bindings to determine how the "Default" choice should read
 */
- (NSString *)defaultIndexFileName
{
	OBASSERT([self defaultFileExtension]);
	NSString *filename = [[self indexFileName] stringByAppendingPathExtension:[self defaultFileExtension]];
	
	NSString *result = [NSString stringWithFormat:NSLocalizedString(@"Default (%@)", "The default item in a list."),
												  filename];
												  
	return result;
}

- (NSString *)indexFileName
{
	NSString *result = [self valueForKeyPath:@"document.documentInfo.hostProperties.htmlIndexBaseName"];
	return result;
}

- (NSString *)archivesFilename
{
	NSString *result = nil;
	
	if ([self isCollection])
	{
		NSString *archivesFileName = [self valueForKeyPath:@"document.documentInfo.hostProperties.archivesBaseName"];
		OBASSERT([self fileExtension]);
		result = [archivesFileName stringByAppendingPathExtension:[self fileExtension]];
	}
	
	return result;
}

/*	Used for bindings to pull together a selection of different filenames/extensions available.
 */
- (NSArray *)availableIndexFilenames
{
	NSArray *availableExtensions = [self availableFileExtensions];
	NSEnumerator *extensionsEnumerator = [availableExtensions objectEnumerator];
	NSString *anExtension;
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[availableExtensions count]];
	
	while (anExtension = [extensionsEnumerator nextObject])
	{
		OBASSERT(anExtension);
		NSString *aFilename = [[self indexFileName] stringByAppendingPathExtension:anExtension];
		[result addObject:aFilename];
	}
	
	return result;
}

#pragma mark -
#pragma mark Publishing

/*	Very similar to -uploadPathRelativeToParent
 *	However, the index.html file is not included in collection paths unless the user defaults say to.
 *	If you ask this of the home page, will either return an empty string or index.html.
 */
- (NSString *)pathRelativeToParent
{
	int collectionPathStyle = KTCollectionHTMLDirectoryPath;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PathsWithIndexPages"]) {
		collectionPathStyle = KTCollectionIndexFilePath;
	}
	
	NSString *result = [self pathRelativeToParentWithCollectionPathStyle:collectionPathStyle];
	return result;
}

/*	Returns out path relative to the site as a whole.
 *	Unlike the -pathRelativeToSite method the result is never cached.
 *	Some typical examples:
 *
 *		text.html			-	A top-level text page
 *		photos				-	A photo album
 *		photos/index.html	-	A photo album (with index.html turned on in user defaults)
 *		photos/photo1.html	-	A photo page
 *							-	The home page
 *		index.html			-	The home page (with index.html turned on in user defaults)
 */
- (NSString *)_pathRelativeToSite
{
	NSString *result = [self customPathRelativeToSite];	// A plugin may have specified a custom path
	
	if (!result)
	{
		int collectionPathStyle = KTCollectionHTMLDirectoryPath;
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PathsWithIndexPages"]) {
			collectionPathStyle = KTCollectionIndexFilePath;
		}
		
		result = [self pathRelativeToSiteWithCollectionPathStyle:collectionPathStyle];
	}
	
	return result;
}

/*	Sends out a KVO notification that the page's path has changed. Upon the next request for the path it will be
 *	regenerated and cached.
 *	KTAbstractPage does not support children, so it is up to KTPage to implement the recursive portion.
 *
 *	If the path is invalid, it can be assumed that the site structure must have changed, so we also post a notification.
 */
- (void)invalidatePathRelativeToSiteRecursive:(BOOL)recursive
{
	[self willChangeValueForKey:@"pathRelativeToSite"];
	[self setPrimitiveValue:nil forKey:@"pathRelativeToSite"];
	[self didChangeValueForKey:@"pathRelativeToSite"];
	
	[self postSiteStructureDidChangeNotification];
}


/*	This accessor pair is used by plugins like the File Download and External Link to specify a custom path different
 *	to the default behaviour.
 */
- (NSString *)customPathRelativeToSite { return [self wrappedValueForKey:@"customPathRelativeToSite"]; }

- (void)setCustomPathRelativeToSite:(NSString *)path
{
	[self setWrappedValue:path forKey:@"customPathRelativeToSite"];
	[self invalidatePathRelativeToSiteRecursive:YES];
}

#pragma mark -
#pragma mark Uploading

/*	The path the page will be uploaded to when publishing/exporting.
 *	This path is RELATIVE to the base diretory of the site so that it
 *	works for both publishing and exporting.
 *
 *	Some typical examples:
 *		index.html			-	Home Page
 *		text.html			-	Text page
 *		photos/index.html	-	Photo album
 *		photos/photo1.html	-	Photo page in album
 */
- (NSString *)uploadPath
{
	NSString *result = [self pathRelativeToSiteWithCollectionPathStyle:KTCollectionIndexFilePath];
	return result;
}

/*	The path relative to our parent which we will be uploaded to.
 *	For plain pages this is dead simple: @"filename.ext"
 *	But for collections, also takes into account the index page: @"filename/index.html"
 */
- (NSString *)uploadPathRelativeToParent
{
	NSString *result = [self pathRelativeToParentWithCollectionPathStyle:KTCollectionIndexFilePath];
	return result;
}

#pragma mark -
#pragma mark Preview

- (NSString *)previewPath
{
	NSString *result = [NSString stringWithFormat:@"%@%@", kKTPageIDDesignator, [self uniqueID]];
	return result;
}

#pragma mark -
#pragma mark Resources

/*	Provides the path of the _Resources directory relative to the reciever.
 */
- (NSString *)pathToResourcesDirectory
{
	NSString *resourcesDirectory = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultResourcesPath"];
	NSString *result = [resourcesDirectory URLPathRelativeTo:[self pathRelativeToSite]];
	
	return result;
}

/*	As above, but takes the resource's filename into account.
 */
- (NSString *)pathToResourceFile:(NSString *)onDiskResourcePath
{
	NSString *result = [[self pathToResourcesDirectory] stringByAppendingPathComponent:[onDiskResourcePath lastPathComponent]];
	return result;
}

#pragma mark -
#pragma mark Other Paths

- (NSString *)designDirectoryPath
{
	SUBCLASSMUSTIMPLEMENT;
	return nil;
}

#pragma mark -
#pragma mark Support

/*	Does the hard graft for -publishedPathRelativeToParent and -uploadPathRelativeToParent.
 *	Should NOT be called externally, PRIVATE method only.
 */
- (NSString *)pathRelativeToParentWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle
{
	NSString *result = @"";
	if (![self isRoot])
	{
		result = [self valueForKey:@"fileName"];
	}
	
	if ([self isCollection])
	{
		if (collectionPathStyle == KTCollectionIndexFilePath)
		{
			result = [result stringByAppendingPathComponent:[self indexFilename]];
		}
		else if (collectionPathStyle == KTCollectionHTMLDirectoryPath)
		{
			result = [result HTMLdirectoryPath];
		}
	}
	else
	{
		OBASSERT([self fileExtension]);
		result = [result stringByAppendingPathExtension:[self fileExtension]];
	}
	
	OBPOSTCONDITION(result);
	return result;
}

/*	Does the hard graft for -publishedPathRelativeToSite and -uploadPathRelativeToSite.
 *	Should not generally be called outside of KTAbstractPage methods.
 */
- (NSString *)pathRelativeToSiteWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle
{
	NSString *parentPath = @"";
	if (![self isRoot])
	{
		parentPath = [[self parent] pathRelativeToSiteWithCollectionPathStyle:KTCollectionDirectoryPath];
	}
	
	NSString *relativePath = [self pathRelativeToParentWithCollectionPathStyle:collectionPathStyle];
	NSString *result = [parentPath stringByAppendingPathComponent:relativePath];
	
	// NSString doesn't handle KTCollectionHTMLDirectoryPath-style strings; we must fix them manually
	if (collectionPathStyle == KTCollectionHTMLDirectoryPath && [self isCollection])
	{
		result = [result HTMLdirectoryPath];
	}
	
	return result;
}

@end
