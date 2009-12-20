//
//  SVDOMController.m
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVContentObject.h"
#import "SVHTMLContext.h"

#import "DOMNode+Karelia.h"


@implementation SVDOMController

#pragma mark Dealloc

- (void)dealloc
{
    [_context release];
    [super dealloc];
}

#pragma mark Content

- (id)initWithContentObject:(SVContentObject *)contentObject
              inDOMDocument:(DOMDocument *)document;
{
    self = [self initWithHTMLElement:[contentObject elementForEditingInDOMDocument:document]];
    [self setRepresentedObject:contentObject];
    return self;
}

- (void)createHTMLElement
{
    // Try to create HTML corresponding to our content (should be a Pagelet or plug-in)
    NSString *htmlString = [self representedObjectHTMLString];
    OBASSERT(htmlString);
    
    DOMDocumentFragment *fragment = [[self HTMLDocument]
                                     createDocumentFragmentWithMarkupString:htmlString
                                     baseURL:[[self HTMLContext] baseURL]];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [self setHTMLElement:element];
}

- (NSString *)representedObjectHTMLString;
{
    SVHTMLContext *context = [self HTMLContext];
    
    [context push];
    NSString *result = [[self representedObject] HTMLString];
    [context pop];
    
    return result;
}

@synthesize HTMLContext = _context;

#pragma mark Updating

- (void)update;
{
    [super update]; // does nothing, but hey, might as well
    _needsUpdate = NO;
}

@synthesize needsUpdate = _needsUpdate;

- (void)setNeedsUpdate;
{
    // Try to get hold of the controller in charge of update coalescing
    id controller = (id)[[self webEditor] delegate];
    if ([controller respondsToSelector:@selector(scheduleUpdate)])
    {
        _needsUpdate = YES;
        [controller performSelector:@selector(scheduleUpdate)];
    }
    else
    {
        [self update];
    }
}

- (void)updateIfNeeded; // recurses down the tree
{
    if ([self needsUpdate])
    {
        [self update];
    }
    
    [super updateIfNeeded];
}

#pragma mark Editing

- (BOOL)isEditable { return YES; }

@end


#pragma mark -


@implementation SVWebEditorItem (SVDOMController)

- (void)update; { }

- (void)updateIfNeeded; // recurses down the tree
{
    // The update may well have meant no children need updating any more. If so, no biggie as this recursion should do nothing
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
}

@end

