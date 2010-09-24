//
//  SVPlugInGraphic.m
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugInGraphic.h"

#import "SVDOMController.h"
#import "SVMediaProtocol.h"
#import "SVPlugIn.h"
#import "SVGraphicFactory.h"
#import "SVHTMLContext.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"


static NSString *sPlugInPropertiesObservationContext = @"PlugInPropertiesObservation";


@interface SVPlugInGraphic ()
- (void)setPlugIn:(SVPlugIn *)plugIn useSerializedProperties:(BOOL)serialize;
@end


#pragma mark -


@implementation SVPlugInGraphic

#pragma mark Lifecycle

+ (SVPlugInGraphic *)insertNewGraphicWithPlugInIdentifier:(NSString *)identifier
                                   inManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVPlugInGraphic *result =
    [NSEntityDescription insertNewObjectForEntityForName:@"PlugInGraphic"    
                                  inManagedObjectContext:context];
    
    [result setValue:identifier forKey:@"plugInIdentifier"];
    [result loadPlugIn];
    
    return result;
}

+ (SVPlugInGraphic *)insertNewGraphicWithPlugIn:(SVPlugIn *)plugIn
                         inManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVPlugInGraphic *result =
    [NSEntityDescription insertNewObjectForEntityForName:@"PlugInGraphic"    
                                  inManagedObjectContext:context];
    
    [result setValue:[[plugIn class] plugInIdentifier] forKey:@"plugInIdentifier"];
    
    
    [result setPlugIn:plugIn useSerializedProperties:YES];  // passing YES to copy the current properties out of the plug-in
    
    
    return result;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    if ([[[self entity] attributesByName] objectForKey:@"plugInVersion"])
    {
        [self setPrimitiveValue:@"??" forKey:@"plugInVersion"];
    }
}

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    
    [self loadPlugIn];
    [[self plugIn] awakeFromFetch];
}

- (void)willInsertIntoPage:(KTPage *)page;
{
    [[self plugIn] awakeFromNew];
    [super willInsertIntoPage:page];
}

- (void)awakeFromExtensiblePropertyUndoUpdateForKey:(NSString *)key;
{
    [super awakeFromExtensiblePropertyUndoUpdateForKey:key];
    
    // Need to pass the change onto our plug-in
    id value = [self extensiblePropertyForKey:key];
    [[self plugIn] setSerializedValue:value forKey:key];
}

- (void)didAddToPage:(id <SVPage>)page;
{
    [super didAddToPage:page];
    
    // Start off at a decent size
    if ([[[self plugIn] class] isExplicitlySized])
    {
        NSUInteger maxWidth = 490;
        if ([self isPagelet]) maxWidth = 200;
        
        if ([[self plugIn] width] > maxWidth)
        {
            [[self plugIn] setWidth:maxWidth];
        }
    }
    
    // Pass on
    [[self plugIn] didAddToPage:page];
}

/*  Where possible (i.e. Leopard) tear down the delegate early to avoid any KVO issues.
 */
- (void)willTurnIntoFault
{
    [_plugIn removeObserver:self forKeyPaths:[[_plugIn class] plugInKeys]];
    [_plugIn setValue:nil forKey:@"container"];
	[_plugIn release];	_plugIn = nil;
}

#pragma mark Plug-in

- (SVPlugIn *)plugIn
{
	return _plugIn;
}

- (void)setPlugIn:(SVPlugIn *)plugIn useSerializedProperties:(BOOL)serialize;
{
    OBASSERT(!_plugIn);
    _plugIn = [plugIn retain];
               
    
    [_plugIn setValue:self forKey:@"container"];
    
    // Observe the plug-in's properties so they can be synced back to the MOC
    [plugIn addObserver:self
            forKeyPaths:[[plugIn class] plugInKeys]
                options:(serialize ? NSKeyValueObservingOptionInitial : 0)
                context:sPlugInPropertiesObservationContext];
}

- (void)loadPlugIn;
{
    SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:[self plugInIdentifier]];
    Class plugInClass = [factory plugInClass];
    
    if (plugInClass)
    {                
        OBASSERT(!_plugIn);
        
        // Create plug-in object
        SVPlugIn *plugIn = [[plugInClass alloc] init];
        OBASSERTSTRING(plugIn, @"plug-in cannot be nil!");
        
        [plugIn setValue:self forKey:@"container"];    // MUST do before deserializing properties
        
        // Restore plug-in's properties
        NSDictionary *plugInProperties = [self extensibleProperties];
        @try
        {
            for (NSString *aKey in plugInProperties)
            {
                id serializedValue = [plugInProperties objectForKey:aKey];
                [plugIn setSerializedValue:serializedValue forKey:aKey];
            }
        }
        @catch (NSException *exception)
        {
            // TODO: Log warning
        }
        
        [self setPlugIn:plugIn useSerializedProperties:NO];
        [plugIn release];
    }
}

@dynamic plugInIdentifier;

#pragma mark Plug-in settings storage

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sPlugInPropertiesObservationContext)
    {
        // Copy serialized value to MOC
        id serializedValue = [[self plugIn] serializedValueForKey:keyPath];
        if (serializedValue)
        {
            [self setExtensibleProperty:serializedValue forKey:keyPath];
        }
        else
        {
            [self removeExtensiblePropertyForKey:keyPath];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context
{
    NSString *identifier = [self plugInIdentifier];
    
    NSUInteger openElements = [context openElementsCount];
    
    NSUInteger level = [context currentHeaderLevel];
    [context setCurrentHeaderLevel:4];
    
    [context writeComment:[NSString stringWithFormat:@" %@ ", identifier]];
    
    @try
    {
        [[self plugIn] writeHTML:context];
    }
    @catch (NSException *exception)
    {
        // TODO: Log or report exception
        
        // Correct open elements count if plug-in managed to break this. #88083
        while ([context openElementsCount] > openElements)
        {
            [context endElement];
        }
    }
    
    [context writeComment:[NSString stringWithFormat:@" /%@ ", identifier]];
    
    [context setCurrentHeaderLevel:level];
}

// This was an experiment with including plug-in's classname up at the highest level, but that ruins sizing
- (void)XbuildClassName:(SVHTMLContext *)context;
{
    [super buildClassName:context];
    
    if ([[self placement] intValue] == SVGraphicPlacementInline)
    {
        NSString *className = [[self plugIn] inlineGraphicClassName];
        if (className) [context pushClassName:className];
    }
}

- (NSString *)inlineGraphicClassName;
{
    return [[self plugIn] inlineGraphicClassName];
}

#pragma mark Metrics

- (void)makeOriginalSize; { [[self plugIn] makeOriginalSize]; }

- (BOOL)isExplicitlySized; { return [[[self plugIn] class] isExplicitlySized]; }

- (NSNumber *)contentWidth;
{
    SVPlugIn *plugIn = [self plugIn];
    
    NSNumber *result = nil;
    if ([self isExplicitlySized] || [[self placement] intValue] == SVGraphicPlacementInline)
    {
        NSUInteger width = [plugIn width];
        if (width) result = [NSNumber numberWithUnsignedInteger:width];
    }
    else
    {
        result = NSNotApplicableMarker;
    }
    
    return result;
}
- (void)setContentWidth:(NSNumber *)width;
{
    [[self plugIn] setWidth:[width unsignedIntegerValue]];
}
+ (NSSet *)keyPathsForValuesAffectingContentWidth; { return [NSSet setWithObject:@"plugIn.width"]; }
- (BOOL)validateContentWidth:(NSNumber **)width error:(NSError **)error;
{
    BOOL result = YES;
    
    if (*width && [*width unsignedIntegerValue] < [self minWidth])
    {
        *width = [NSNumber numberWithUnsignedInt:[self minWidth]];
    }
    
    return result;
}


- (NSNumber *)contentHeight;
{
    SVPlugIn *plugIn = [self plugIn];
    
    NSNumber *result = nil;
    if ([self isExplicitlySized])
    {
        NSUInteger height = [plugIn height];
        if (height) result = [NSNumber numberWithUnsignedInteger:height];
    }
    else
    {
        result = NSNotApplicableMarker;
    }
    
    return result;
}
- (void)setContentHeight:(NSNumber *)height;
{
    [[self plugIn] setHeight:[height unsignedIntegerValue]];
}
+ (NSSet *)keyPathsForValuesAffectingContentHeight; { return [NSSet setWithObject:@"plugIn.height"]; }
- (BOOL)validateContentHeight:(NSNumber **)height error:(NSError **)error;
{
    BOOL result = YES;
    
    if (*height && [*height unsignedIntegerValue] < [self minHeight])
    {
        *height = [NSNumber numberWithUnsignedInt:[self minHeight]];
    }
    
    return result;
}


- (NSUInteger)minWidth; { return [[self plugIn] minWidth]; }
- (NSUInteger)minHeight; { return [[self plugIn] minHeight]; }


- (BOOL)constrainProportions; { return [[self plugIn] constrainProportions]; }
- (void)setConstrainProportions:(BOOL)constrain;
{
    [[self plugIn] setBool:constrain forKey:@"constrainProportions"];
}


- (BOOL)isConstrainProportionsEditable;
{
    return [[self plugIn] respondsToSelector:@selector(setConstrainProportions:)];
}

#pragma mark Thumbnail

- (id <SVMedia>)thumbnail;
{
    return ([[self plugIn] thumbnailURL] ? self : nil);
}

- (CGFloat)thumbnailAspectRatio;
{
    CIImage *image = [[CIImage alloc] initWithContentsOfURL:[self mediaURL]];
    CGSize size = [image extent].size;
    CGFloat result = size.width / size.height;
    [image release];
    return result;
}

- (NSURL *)mediaURL; { return [[self plugIn] thumbnailURL]; }
- (NSData *)mediaData; { return nil; }
- (NSString *)preferredFilename; { return [[self mediaURL] ks_lastPathComponent]; }

- (id)imageRepresentation; { return [self mediaURL]; }
- (NSString *)imageRepresentationType; { return IKImageBrowserNSURLRepresentationType; }

#pragma mark Inspector

- (Class)inspectorFactoryClass; { return [[self plugIn] class]; }

- (id)objectToInspect; { return [self plugIn]; }

#pragma mark Serialization

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    [self loadPlugIn];
}

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Put plug-in properties in their own dict
    [propertyList setObject:[self extensibleProperties] forKey:@"plugInProperties"];
}

@end
