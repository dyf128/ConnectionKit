//
//  SVMediaPlugIn.m
//  Sandvox
//
//  Created by Mike on 24/09/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVMediaPlugIn.h"

#import "SVGraphicFactory.h"
#import "SVHTMLContext.h"
#import "SVMediaGraphic.h"
#import "SVMediaRecord.h"

#import "NSString+Karelia.h"
#import "KSURLUtilities.h"
#import "NSError+Karelia.h"


@interface SVMediaPlugIn (InheritedPrivate)
@property(nonatomic, readonly) SVMediaGraphic *container;
@end


@implementation SVMediaPlugIn

#pragma mark Properties

- (SVMedia *)media;
{
    return [[[self container] media] media];
}
+ (NSSet *)keyPathsForValuesAffectingMedia;
{
    return [NSSet setWithObject:@"container.media.media"];
}

- (NSURL *)externalSourceURL; { return [[self container] externalSourceURL]; }

- (void)didSetSource; { }

+ (NSArray *)allowedFileTypes; { return nil; }

#pragma mark Poster Frame

- (SVMediaRecord *)posterFrame; { return [[self container] posterFrame]; }
+ (NSSet *)keyPathsForValuesAffectingPosterFrame;
{
    return [NSSet setWithObject:@"container.posterFrame"];
}

- (BOOL)validatePosterFrame:(SVMediaRecord *)posterFrame;
{
    return (posterFrame == nil);
}

- (void)setPosterFrameWithMedia:(SVMedia *)media;   // nil removes poster frame
{
    SVMediaRecord *record = nil;
    if (media)
    {
        record = [SVMediaRecord mediaRecordWithMedia:media
                                          entityName:@"PosterFrame"
                      insertIntoManagedObjectContext:[self.container managedObjectContext]];
    }
    
	[self replaceMedia:record forKeyPath:@"container.posterFrame"];
}

#pragma mark Media Conversion

- (NSString *)typeToPublish; { return [[self container] typeToPublish]; }
- (void)setTypeToPublish:(NSString *)type; { [[self container] setTypeToPublish:type]; }
- (BOOL)validateTypeToPublish:(NSString *)type; { return YES; }
+ (NSSet *)keyPathsForValuesAffectingTypeToPublish;
{
    return [NSSet setWithObject:@"container.typeToPublish"];
}

#pragma mark Metrics

- (BOOL)validateHeight:(NSNumber **)height error:(NSError **)error;
{
    // By default allow anything since it may be imported external media whose size is not yet known
    return YES;
}

- (NSNumber *)minWidth; { return [NSNumber numberWithInt:1]; }
// -minHeight is already 1

- (NSNumber *)constrainedAspectRatio;
{
    return [[self container] constrainedAspectRatio];
}
- (void)setConstrainedAspectRatio:(NSNumber *)ratio;
{
    [[self container] performSelector:_cmd withObject:ratio];
}

- (NSNumber *)naturalWidth; { return [[self container] naturalWidth]; }

- (NSNumber *)naturalHeight; { return [[self container] naturalHeight]; }

- (void)setNaturalWidth:(NSNumber *)width height:(NSNumber *)height;
{
    SVMediaGraphic *graphic = [self container];
    [graphic setNaturalWidth:width];
    [graphic setNaturalHeight:height];
    
    
    // I'm not convinced we should touch the actual size at all, but it's needed to make video import. #121592
    if ((![self width] || ![self height]) && width && height)
    {
        NSNumber *oldWidth = [[self width] copy];
        [graphic makeOriginalSize]; // why did I decide to do this? – Mike

        if (width && height)
        {
            [graphic setConstrainsProportions:YES];
        }

        if (oldWidth && [[self width] unsignedIntegerValue] > [oldWidth unsignedIntegerValue])
        {
            [[self container] setContentWidth:oldWidth];
        }
        [oldWidth release];
    }
}

- (void)resetNaturalSize; { [self setNaturalWidth:nil height:nil]; }

/*  There shouldn't be any need to call this method directly. Instead, it should only be called internally from -[SVMediaGraphic makeOriginalSize]
 */
- (void)makeOriginalSize;
{
    NSNumber *width = [self naturalWidth];
    NSNumber *height = [self naturalHeight];
    
    if (width && height)
    {
        [self setWidth:width height:height];
    }
    else
    {
        // Need to go back to the source
        [self resetNaturalSize];
        
        if ([self naturalWidth] && [self naturalHeight]) [self makeOriginalSize];
    }
}

#pragma mark SVEnclosure

- (NSURL *)downloadedURL;   // where it currently resides on disk
{
	NSURL *mediaURL = nil;
	SVMedia *media = [self media];
	
    if (media)
    {
		mediaURL = [media fileURL];
	}
	else
	{
		mediaURL = [self externalSourceURL];
	}
	return mediaURL;
}

- (long long)length;
{
	long long result = 0;
	SVMedia *media = [self media];
	
    if (media)
    {
		NSData *mediaData = [media mediaData];
		result = [mediaData length];
	}
	return result;
}

- (NSString *)MIMEType;
{
	NSString *type = [(id)[self media] typeOfFile];
    if (!type)
    {
        type = [KSWORKSPACE ks_typeForFilenameExtension:[[self externalSourceURL] ks_pathExtension]];
    }
    
    NSString *result = (type ? [KSWORKSPACE ks_MIMETypeForType:type] : nil);
	return result;
}

- (NSURL *)addToContext:(SVHTMLContext *)context;
{
    if ([self media])
    {
        return [context addMedia:[self media]];
    }
    else
    {
        return [self externalSourceURL];
    }
}

#pragma mark HTML

- (BOOL)canWriteHTMLInline; { return NO; }

// For backwards compat. with 1.x:
+ (NSString *)elementClassName; { return nil; }
+ (NSString *)contentClassName; { return nil; }

#pragma mark Thumbnail

- (id <SVMedia>)thumbnailMedia; { return [self media]; }

- (id)imageRepresentation;
{
    id <SVMedia> media = [self thumbnailMedia];
    id result = [media mediaData];
    if (!result) result = [media mediaURL];
    
    return result;
}

- (NSString *)imageRepresentationType;
{
    // Default to Quick Look. Subclasses can get better
    return ([[self thumbnailMedia] mediaData] ? nil : IKImageBrowserQuickLookPathRepresentationType);
}


#pragma mark Inspector

- (id)valueForUndefinedKey:(NSString *)key; { return NSNotApplicableMarker; }

#pragma mark Pasteboard

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    NSArray *result = [[KSWebLocation webLocationPasteboardTypes]
                       arrayByAddingObjectsFromArray:[self allowedFileTypes]];
    return result;
}

@end