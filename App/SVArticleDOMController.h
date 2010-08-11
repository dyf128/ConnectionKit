//
//  SVArticleDOMController.h
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRichTextDOMController.h"

#import "SVArticle.h"


@class SVCalloutDOMController;


@interface SVArticleDOMController : SVRichTextDOMController
{
  @private
    SVCalloutDOMController  *_earlyCalloutController;
    
    DOMElement  *_dragCaret;
}

- (IBAction)insertPagelet:(id)sender;

- (IBAction)moveToBlockLevel:(id)sender;


#pragma mark Callouts
@property(nonatomic, retain) SVCalloutDOMController *earlyCalloutDOMController;


#pragma mark Drag Caret
- (void)removeDragCaret;
- (void)moveDragCaretToBeforeDOMNode:(DOMNode *)node draggingInfo:(id <NSDraggingInfo>)dragInfo;
- (void)replaceDragCaretWithHTMLString:(NSString *)html;

- (DOMElement *)dropOutlineDOMElement;


@end
