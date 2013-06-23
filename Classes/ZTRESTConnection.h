//
//  ZTRESTConnection.h
//  ZTKit
//
//  Created by Zachry Thayer on 6/1/12.
//  Copyright (c) 2012 Zachry Thayer. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^ZTRESTCompletion)(NSHTTPURLResponse* response, id object, NSError* error);

// Returns and object for specified mimetype
typedef id (^ZTRESTMimeHandler)(NSHTTPURLResponse* response, NSData* data);


@interface ZTRESTConnection : NSObject

@property (strong, nonatomic) NSURL* apiBase;

@property (strong, nonatomic) NSString* username;
@property (strong, nonatomic) NSString* password;

@property (nonatomic, strong) NSHTTPURLResponse* lastResponse;
@property (nonatomic, strong) NSError*           lastError;


+ (ZTRESTConnection*)connectionToApi:(NSString*)api;
+ (ZTRESTConnection*)connectionToApi:(NSString*)api username:(NSString*)aUsername password:(NSString*)aPassword;

- (id)initWithAPI:(NSString*)api;
- (id)initWithAPI:(NSString*)api username:(NSString*)aUsername password:(NSString*)aPassword;

#pragma mark REST

//Default MIME type support (unsupported mimetypes return NSData)
// application/json

//Asynchrnous

- (void)GET:(NSString*)route query:(NSDictionary*)queryParams completion:(ZTRESTCompletion)completionBlock;

- (void)POST:(NSString*)route data:(NSData*)postData completion:(ZTRESTCompletion)completionBlock;

- (void)PUT:(NSString*)route data:(NSData*)putData completion:(ZTRESTCompletion)completionBlock;

- (void)DELETE:(NSString*)route completion:(ZTRESTCompletion)completionBlock;

// Synchronous

- (id)GET:(NSString*)route query:(NSDictionary*)queryParams;

- (id)POST:(NSString*)route data:(NSData*)postData;

- (id)PUT:(NSString*)route data:(NSData*)putData;

- (id)DELETE:(NSString*)route;

#pragma mark Helpers

- (NSMutableURLRequest*)requestForAction:(NSString*)action route:(NSString*)route data:(id)data;
- (void)performAsyncRequest:(NSMutableURLRequest*)request completion:(ZTRESTCompletion)completionBlock;
- (id)performRequest:(NSMutableURLRequest*)request;

// For use when POSTing queries
+ (NSData*)queryDataFromDictionary:(NSDictionary*)dictionary;
+ (NSString*)queryStringFromDictionary:(NSDictionary*)dictionary;

// For use with custom actions
- (void)performAsyncAction:(NSString*)action route:(NSString*)route data:(id)data completion:(ZTRESTCompletion)completionBlock;

// For handling custom mime types
- (void)handleMimeType:(NSString*)mimeType withBlock:(ZTRESTMimeHandler)mimeHandlerBlock;

// Returns and array of mimetypes that have installed handlers
- (NSArray*)installedMimeTypeHandlers;

@end

