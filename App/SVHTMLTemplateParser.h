//
//  SVHTMLTemplateParser.h
//  Sandvox
//
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//


#import "SVTemplateParser.h"

#import "SVHTMLContext.h"


@class KTDocument, KTHTMLParserMasterCache, KTMediaFileUpload, SVHTMLTextBlock;
@class KTPage;
@class KTMediaContainer;
@protocol SVHTMLTemplateParserDelegate, SVMedia;


@interface SVHTMLTemplateParser : SVTemplateParser
{
  @private
    SVHTMLContext   *_context;          // weak, temporary ref
    id              _iterationObject;   // weak, temporary ref
	id				myDelegate;
}

- (id)initWithPage:(KTPage *)page;	// Convenience method that parses the whole page

@property(nonatomic, assign) id <SVHTMLTemplateParserDelegate> delegate;


#pragma mark Parse

- (BOOL)parseIntoHTMLContext:(SVHTMLContext *)context;
@property(nonatomic, readonly) SVHTMLContext *HTMLContext;

+ (SVHTMLTemplateParser *)currentTemplateParser;
@property(nonatomic, readonly) id currentIterationObject;


#pragma mark Functions
- (NSString *)pathToObject:(id)anObject;


#pragma mark Prebuilt templates
- (NSString *)targetStringForPage:(id) aDestPage;


@end


@interface SVHTMLTemplateParser (Media)

- (NSString *)info:(NSString *)infoString forMedia:(KTMediaContainer *)media scalingProperties:(NSDictionary *)scalingSettings;

- (NSString *)pathToMedia:(id <SVMedia>)media scalingProperties:(NSDictionary *)scalingProps;
- (NSString *)widthStringForMediaFile:(id <SVMedia>)mediaFile scalingProperties:(NSDictionary *)scalingProps;
- (NSString *)heightStringForMediaFile:(id <SVMedia>)mediaFile scalingProperties:(NSDictionary *)scalingProps;

@end


@interface SVHTMLTemplateParser (Text)
- (SVHTMLTextBlock *)textblockForKeyPath:(NSString *)keypath ofObject:(id)object
                                   flags:(NSArray *)flags
                                 HTMLTag:(NSString *)tag
                               className:(NSString *)className
                                  idName:(NSString *)idName
                       graphicalTextCode:(NSString *)GTCode
                               hyperlink:(KTPage *)hyperlink;
@end


@protocol SVHTMLTemplateParserDelegate
@optional
- (void)HTMLParser:(SVHTMLTemplateParser *)parser didEncounterResourceFile:(NSURL *)resourcePath;
- (void)HTMLParser:(SVHTMLTemplateParser *)parser didParseMediaFile:(id <SVMedia>)mediaFile upload:(KTMediaFileUpload *)upload;
@end
