//
//  SVParagraphedHTMLWriter.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVParagraphedHTMLWriter.h"

#import "SVBodyTextDOMController.h"
#import "SVGraphic.h"
#import "SVImage.h"
#import "SVMediaRecord.h"
#import "SVTextAttachment.h"

#import "NSURL+Karelia.h"


@implementation SVParagraphedHTMLWriter

#pragma mark Init & Dealloc

- (void)dealloc
{
    [_DOMController release];
    [super dealloc];
}

#pragma mark Cleanup

- (DOMNode *)convertImageElementToGraphic:(DOMHTMLImageElement *)imageElement;
{
    // Make an image object
    SVBodyTextDOMController *textController = [self bodyTextDOMController];
    SVRichText *text = [textController representedObject];
    NSManagedObjectContext *context = [text managedObjectContext];
    
    SVMediaRecord *media;
    NSURL *URL = [imageElement absoluteImageURL];
    if ([URL isFileURL])
    {
        media = [SVMediaRecord mediaWithURL:URL
                                 entityName:@"ImageMedia"
             insertIntoManagedObjectContext:context
                                      error:NULL];
    }
    else
    {
        WebResource *resource = [[[[imageElement ownerDocument] webFrame] dataSource] subresourceForURL:URL];
        NSData *data = [resource data];
        
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[resource URL]
                                                            MIMEType:[resource MIMEType]
                                               expectedContentLength:[data length]
                                                    textEncodingName:[resource textEncodingName]];
        
        media = [SVMediaRecord mediaWithFileContents:data
                                         URLResponse:response
                                          entityName:@"ImageMedia"
                      insertIntoManagedObjectContext:context];
        [response release];
        
        [media setPreferredFilename:[@"pastedImage" stringByAppendingPathExtension:[URL pathExtension]]];
    }
    
    SVImage *image = [SVImage insertNewImageWithMedia:media];
    
    
    // Make corresponding text attachment
    SVTextAttachment *textAttachment = [NSEntityDescription
                                        insertNewObjectForEntityForName:@"TextAttachment"
                                        inManagedObjectContext:context];
    [textAttachment setGraphic:image];
    [textAttachment setBody:text];
    [textAttachment setPlacement:[NSNumber numberWithInteger:SVGraphicPlacementInline]];
    
    
    // Create controller for graphic
    SVDOMController *controller = [[[image DOMControllerClass] alloc]
                                   initWithHTMLDocument:(DOMHTMLDocument *)[imageElement ownerDocument]];
    [controller setHTMLContext:[textController HTMLContext]];
    [controller setRepresentedObject:image];
    
    [textController addChildWebEditorItem:controller];
    [controller release];
    
    
    // Replace old DOM element with new one
    DOMNode *result = [imageElement nextSibling];
    DOMNode *parentNode = [imageElement parentNode];
    [parentNode removeChild:imageElement];
    [parentNode insertBefore:[controller HTMLElement] refChild:result];
    
    
    // Write the replacement
    [[self delegate] HTMLWriter:self writeDOMElement:[controller HTMLElement]];
    
    
    return result;
}

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
{
    // Invalid top-level elements should be converted into paragraphs
    if ([[element tagName] isEqualToString:@"IMG"])
    {
        return [self convertImageElementToGraphic:(DOMHTMLImageElement *)element];
    }
    else if ([self openElementsCount] == 0)
    {
        DOMElement *result = [self changeDOMElement:element toTagName:@"P"];
        return result;  // pretend the element was written, but retry on this new node
    }
    else
    {
        return [super handleInvalidDOMElement:element];
    }
    
    /*NSString *tagName = [element tagName];
    
    
    // If a paragraph ended up here, treat it like normal, but then push all nodes following it out into new paragraphs
    if ([tagName isEqualToString:@"P"])
    {
        DOMNode *parent = [element parentNode];
        DOMNode *refNode = element;
        while (parent)
        {
            [parent flattenNodesAfterChild:refNode];
            if ([[(DOMElement *)parent tagName] isEqualToString:@"P"]) break;
            refNode = parent; parent = [parent parentNode];
        }
    }*/
}

#pragma mark Validation

- (BOOL)validateTagName:(NSString *)tagName
{
    // Paragraphs are permitted in body text
    if ([tagName isEqualToString:@"P"] ||
        [tagName isEqualToString:@"UL"] ||
        [tagName isEqualToString:@"OL"])
    {
        BOOL result = ([self openElementsCount] == 0 || [self lastOpenElementIsList]);
        return result;
    }
    else
    {
        BOOL result = ([tagName isEqualToString:@"A"] ||
                       [super validateTagName:tagName]);
    
        return result;
    }
}

- (BOOL)validateAttribute:(NSString *)attributeName;
{
    // Super doesn't allow links; we do.
    if ([[self lastOpenElementTagName] isEqualToString:@"A"])
    {
        BOOL result = ([attributeName isEqualToString:@"href"] ||
                       [attributeName isEqualToString:@"target"] ||
                       [attributeName isEqualToString:@"style"] ||
                       [attributeName isEqualToString:@"charset"] ||
                       [attributeName isEqualToString:@"hreflang"] ||
                       [attributeName isEqualToString:@"name"] ||
                       [attributeName isEqualToString:@"title"] ||
                       [attributeName isEqualToString:@"rel"] ||
                       [attributeName isEqualToString:@"rev"]);
        
        return result;               
    }
    else
    {
        return [super validateAttribute:attributeName];
    }
}

- (BOOL)validateStyleProperty:(NSString *)propertyName;
{
    BOOL result = [super validateStyleProperty:propertyName];
    
    if (!result && [propertyName isEqualToString:@"text-align"])
    {
        NSString *tagName = [self lastOpenElementTagName];
        if ([tagName isEqualToString:@"P"])
        {
            result = YES;
        }
    }
    
    return result;
}

#pragma mark Properties

@synthesize bodyTextDOMController = _DOMController;

@end


#pragma mark -


@implementation DOMNode (SVBodyText)

- (DOMNode *)topLevelBodyTextNodeWriteToStream:(KSHTMLWriter *)context;
{
    //  Don't want unknown nodes
    DOMNode *result = [self nextSibling];
    [[self parentNode] removeChild:self];
    return result;
}

@end


@implementation DOMElement (SVBodyText)

- (DOMNode *)topLevelBodyTextNodeWriteToStream:(KSHTMLWriter *)context;
{
    //  Elements can be treated pretty normally
    return [context _writeDOMElement:self];
}

@end


@implementation DOMText (SVBodyText)

- (DOMNode *)topLevelBodyTextNodeWriteToStream:(KSHTMLWriter *)context;
{
    //  Only allowed  a single newline at the top level
    if ([[self previousSibling] nodeType] == DOM_TEXT_NODE)
    {
        return [super topLevelBodyTextNodeWriteToStream:context];  // delete self
    }
    else
    {
        [self setTextContent:@"\n"];
        [context writeNewline];
        return [self nextSibling];
    }
}

@end


