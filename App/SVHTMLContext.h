//
//  SVHTMLContext.h
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSHTMLWriter.h"

#import <WebKit/DOMCore.h>


// publishing mode
typedef enum {
	kSVHTMLGenerationPurposeNormal = -1,    // publishing
    kSVHTMLGenerationPurposeEditing,        // (previously known as preview)
    kSVHTMLGenerationPurposeQuickLookPreview = 10,
} KTHTMLGenerationPurpose;


#pragma mark -


@class KTAbstractPage, KTPage, SVContentObject, SVHTMLTextBlock, SVLink;

@interface SVHTMLContext : KSHTMLWriter
{
  @private
    NSURL   *_baseURL;
    KTPage	*_currentPage;
    
	KTHTMLGenerationPurpose	_generationPurpose;
	BOOL					_includeStyling;
	BOOL                    _liveDataFeeds;
    NSStringEncoding        _stringEncoding;
    
    NSString    *_calloutAlignment;
    
    NSMutableArray  *_iteratorsStack;
    
    NSUInteger      _contentObjects;
    NSMutableArray  *_textBlocks;
}

#pragma mark Properties

@property(nonatomic, copy) NSURL *baseURL;
@property(nonatomic) BOOL includeStyling;
@property(nonatomic) BOOL liveDataFeeds;
@property(nonatomic) NSStringEncoding encoding;   // UTF-8 by default

@property(nonatomic) KTHTMLGenerationPurpose generationPurpose;
@property(nonatomic, readonly, getter=isEditable) BOOL editable; // YES if HTML is intended to be edited directly in a Web Editor
- (BOOL)isForQuickLookPreview;
- (BOOL)isForPublishing;

- (void)copyPropertiesFromContext:(SVHTMLContext *)context;


#pragma mark Callouts
- (void)writeCalloutStartWithAlignmentClassName:(NSString *)alignment;
- (void)writeCalloutEnd;    // written lazily so consecutive matching callouts are blended into one


#pragma mark Iterations

// It's pretty common to loop through a series of items when generating HTML. e.g. Pagelets in the Sidebar. When doing so, it's nice to generate a CSS class name that corresponds so special styling can be applied based on that. The Template Parser provides nice functions for generating these class names, but the stack of such iterations is maintained here.
// IMPORTANT: Iteration in the context is 0-based. For CSS class names you generally want it to be 1-based, so bump up values by 1. The HTML Template Parser functions do this automatically interally.

@property(nonatomic, readonly) NSUInteger currentIteration;
@property(nonatomic, readonly) NSUInteger currentIterationsCount;
- (void)nextIteration;  // increments -currentIteration. Pops the iterators stack if this was the last one.
- (void)beginIteratingWithCount:(NSUInteger)count;  // Pushes a new iterator on the stack
- (void)popIterator;  // Pops the iterators stack early


#pragma mark URLs/Paths
// These methods try to generate as simple a URL string when possible. e.g. relative path, or page ID
- (NSString *)relativeURLStringOfURL:(NSURL *)URL;
- (NSString *)relativeURLStringOfPage:(KTAbstractPage *)page;   
- (NSString *)relativeURLStringOfResourceFile:(NSURL *)resourceURL;


#pragma mark Resource Files
- (void)addResource:(NSURL *)resourceURL;   // call to register the resource for needing publishing
- (NSURL *)URLOfResource:(NSURL *)resource; // the URL of a resource once published. Calls -addResource internally
//- (NSString *)uploadPathOfResource:(NSURL *)resource; // counterpart to -URLOfResource


#pragma mark Extra markup
- (void)writeExtraHeaders;  // writes any code plug-ins etc. have requested should inside the <head> element
- (void)writeEndBodyString; // writes any code plug-ins etc. have requested should go at the end of the page, before </body>


#pragma mark Content

- (void)willBeginWritingContentObject:(SVContentObject *)object;
- (void)didEndWritingContentObject;
- (NSUInteger)numberOfContentObjectsOnPage; // incremented for each call to -willWriteContentObject:

// Default implementation does nothing. Subclasses can implement for introspecting the dependencies (WebView loading does)
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;
                               
@property(nonatomic, copy, readonly) NSArray *generatedTextBlocks;
- (void)didGenerateTextBlock:(SVHTMLTextBlock *)textBlock;




// In for compatibility, overrides -baseURL
@property(nonatomic, retain) KTPage *currentPage;

@end


#pragma mark -


@interface SVHTMLContext (CurrentContext)

+ (SVHTMLContext *)currentContext;
+ (void)pushContext:(SVHTMLContext *)context;
+ (void)popContext;

// Convenience methods for pushing and popping that will just do the right thing when the receiver is nil
- (void)push;
- (void)pop;    // only pops if receiver is the current context

@end



#pragma mark -


@interface SVHTMLContext (HTMLElements)

#pragma mark Links

//  <a href="...." target="..." rel="nofollow">
- (void)writeAnchorStartTagWithHref:(NSString *)href title:(NSString *)titleString target:(NSString *)targetString rel:(NSString *)relString;


#pragma mark Images

//  <img src="..." alt="..." width="..." height="..." />
- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                         src:(NSString *)src
                         alt:(NSString *)alt
                       width:(NSString *)width
                      height:(NSString *)height;


#pragma mark Link

- (void)writeLinkWithHref:(NSString *)href
                     type:(NSString *)type
                      rel:(NSString *)rel
                    title:(NSString *)title
                    media:(NSString *)media;

- (void)writeLinkToStylesheet:(NSString *)href
                        title:(NSString *)title
                        media:(NSString *)media;

// Default is to write a <link> tag to the stylesheet, EXCEPT when publishing where nothing happens. It is expected that a subclass will override the method to build up main.css for real publishing
- (void)includeStylesheetAtURL:(NSURL *)stylesheetURL;
- (void)includeStyle:(NSString *)cssText;


#pragma mark Style

- (void)writeStyleStartTagWithType:(NSString *)type;


#pragma mark General

//  <tagName id="idName" class="className">
//  Calls -openTag: and -writeAttribute:value: appropriately for you
- (void)writeStartTag:(NSString *)tagName   
               idName:(NSString *)idName
            className:(NSString *)className;

@end

