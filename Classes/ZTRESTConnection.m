//
//  ZTRESTConnection.m
//  ZTKit
//
//  Created by Zachry Thayer on 6/1/12.
//  Copyright (c) 2012 Zachry Thayer. All rights reserved.
//

#import "ZTRESTConnection.h"
#import "NSString+ZTRESTAdditions.h"

@interface ZTRESTConnection () <NSURLConnectionDelegate>

@property (strong, nonatomic) NSMutableDictionary* mimeTypeHandlers;

#ifdef ZTRESTUseURLConnectionDelegate
@property (strong, nonatomic) NSMutableDictionary* connections;
#else
@property dispatch_queue_t networkQueue;
#endif

//Authentication
@property (nonatomic, readwrite) BOOL usesSSL;
@property (strong, nonatomic) NSString* username;
@property (strong, nonatomic) NSString* password;

- (void)performAsyncRequest:(NSURLRequest*)request completion:(ZTRESTCompletion)completionBlock;
- (void)installDefaultMimeTypeHandlers;
+ (NSString*)queryStringFromDictionary:(NSDictionary*)dictionary;

@end

@implementation ZTRESTConnection

@synthesize mimeTypeHandlers;

#ifdef ZTRESTUseURLConnectionDelegate
@synthesize connections;
#else
@synthesize networkQueue;
#endif

@synthesize usesSSL;
@synthesize username;
@synthesize password;

@synthesize apiBase;


+ (ZTRESTConnection*)connectionToApi:(NSString*)api
{
  return [[ZTRESTConnection alloc] initWithAPI:api];
}

+ (ZTRESTConnection*)connectionToApi:(NSString*)api username:(NSString*)aUsername password:(NSString*)aPassword
{
  return [[ZTRESTConnection alloc] initWithAPI:api username:aUsername password:aPassword];
}

- (id)initWithAPI:(NSString*)api
{
  self = [self init];
  if (self)
  {
    [self installDefaultMimeTypeHandlers];

    self.apiBase = [NSURL URLWithString:api];
    NSAssert(self.apiBase,@"API:\"%@\" is not valid URL, %s", api,  __PRETTY_FUNCTION__);
  }
  return self;
}

- (id)initWithAPI:(NSString*)api username:(NSString*)aUsername password:(NSString*)aPassword
{
  self = [self initWithAPI:api];
  if (self)
  {
    self.username = aUsername;
    self.password = aPassword;
    self.usesSSL = YES;
  }
  return self;
}

- (void)dealloc
{
  //dispatch_release(self.networkQueue);
}

#pragma mark - Public

#pragma mark Asynchrnous

- (void)GET:(NSString*)route query:(NSDictionary*)queryParams completion:(ZTRESTCompletion)completionBlock
{
  NSMutableURLRequest* request = [self requestForAction:@"GET" route:route data:queryParams];
  [self performAsyncRequest:request completion:completionBlock];
}

- (void)POST:(NSString*)route data:(NSData*)postData completion:(ZTRESTCompletion)completionBlock
{
  NSMutableURLRequest* request = [self requestForAction:@"POST" route:route data:postData];
  [self performAsyncRequest:request completion:completionBlock];
}

- (void)PUT:(NSString*)route data:(NSData*)putData completion:(ZTRESTCompletion)completionBlock
{
  NSMutableURLRequest* request = [self requestForAction:@"PUT" route:route data:putData];
  [self performAsyncRequest:request completion:completionBlock];
}

- (void)DELETE:(NSString*)route completion:(ZTRESTCompletion)completionBlock
{
  NSMutableURLRequest* request = [self requestForAction:@"DELETE" route:route data:nil];
  [self performAsyncRequest:request completion:completionBlock];
}

#pragma mark Synchrnous

- (id)GET:(NSString*)route query:(NSDictionary*)queryParams
{
  NSMutableURLRequest* request = [self requestForAction:@"GET" route:route data:queryParams];

  return [self performRequest:request];
}

- (id)POST:(NSString*)route data:(NSData*)postData
{
  NSMutableURLRequest* request = [self requestForAction:@"POST" route:route data:postData];
  
  return [self performRequest:request];
}

- (id)PUT:(NSString*)route data:(NSData*)putData
{
  NSMutableURLRequest* request = [self requestForAction:@"PUT" route:route data:putData];
  
  return [self performRequest:request];
}

- (id)DELETE:(NSString*)route
{
  NSMutableURLRequest* request = [self requestForAction:@"DELETE" route:route data:nil];
  
  return [self performRequest:request];
}

#pragma mark Public Helpers

- (NSMutableURLRequest*)requestForAction:(NSString*)action route:(NSString*)route data:(id)data
{
  NSAssert(self.apiBase,@"ZTRESTConnect.apiBase is not set for %@\n%s", self, __PRETTY_FUNCTION__);
  
  NSString* fullRoute = [ZTRESTConnection prepareRoute:route];
  NSURL* requestURL = [self.apiBase URLByAppendingPathComponent:fullRoute];
  
  if ([action isEqualToString:@"GET"])
  {
    if (data)
    {
      NSDictionary* queryParams = data;
      NSString* queryString = [ZTRESTConnection queryStringFromDictionary:queryParams];
      fullRoute = [[requestURL absoluteString] stringByAppendingFormat:@"?%@", queryString];
      requestURL = [NSURL URLWithString:fullRoute];
    }
  }
  
  NSMutableURLRequest* URLRequest = [NSMutableURLRequest requestWithURL:requestURL];
  [URLRequest setHTTPMethod:action];
  
  //If credentials are provided use them, but only over ssl
  if (self.usesSSL && self.username && self.password)
  {
    
    NSString* authenticationString = [[NSString stringWithFormat:@"%@:%@", self.username, self.password] base64EncodeString];
    [URLRequest addValue:authenticationString forHTTPHeaderField:@"Authentication"];
  }
  
  if ([action isEqualToString:@"POST"] || [action isEqualToString:@"PUT"])
  {
    [URLRequest setHTTPBody:data];
  }
  
  return URLRequest;
}

- (void)handleMimeType:(NSString*)mimeType withBlock:(ZTRESTMimeHandler)mimeHandlerBlock
{
  //Don't override default handlers ?
  //if (![self.mimeTypeHandlers objectForKey:mimeType])
  //{
      [self.mimeTypeHandlers setObject:[mimeHandlerBlock copy] forKey:mimeType];
  //}
}

- (NSArray*)installedMimeTypeHandlers
{
  return [self.mimeTypeHandlers allKeys];
}

#pragma mark Setters

- (void)setApiBase:(NSURL *)anApiBase
{
  if ([[anApiBase scheme] isEqualToString:@"https"])
  {
    usesSSL = YES;
  }
  
  apiBase = anApiBase;
  
#ifndef ZTRESTUseURLConnectionDelegate
  NSString* networkQueueName = [NSString stringWithFormat:@"com.zachrythayer.ztkit.rest_connection.%@", [apiBase host]];
  
  if (self.networkQueue)
  {
    //dispatch_release(self.networkQueue);
  }
  self.networkQueue = dispatch_queue_create([networkQueueName UTF8String], NULL);
#endif
}

- (void)setUseSSL:(BOOL)ssl
{
  if (!apiBase)
  {
    return;
  }
  
  usesSSL = ssl;
  
  //TODO:make route use SSL
  
}

#pragma mark Getters

- (NSMutableDictionary*)mimeTypeHandlers
{
  if (!mimeTypeHandlers)
  {
    mimeTypeHandlers = [NSMutableDictionary dictionary];
  }
  return mimeTypeHandlers;
}

#ifdef ZTRESTUseURLConnectionDelegate

- (NSMutableDictionary*)connections
{
  if (!connections)
  {
    connections = [NSMutableDictionary dictionary];
  }
  return connections;
}

#endif

#pragma mark Helpers

- (void)performAsyncRequest:(NSURLRequest*)request completion:(ZTRESTCompletion)completionBlock 
{
  
  NSAssert([NSURLConnection canHandleRequest:request],@"Can't handle request %@\n%s", request, __PRETTY_FUNCTION__);
  
  #if DEBUG
  
  //NSLog(@"%s:\n%@",__PRETTY_FUNCTION__,request);
  
  #endif

#ifdef ZTRESTUseURLConnectionDelegate
  // Delegate based connection
    NSURLConnection *aConnection = [NSURLConnection connectionWithRequest:request delegate:self];    
    
    NSMutableDictionary *connectionDict = [NSMutableDictionary dictionary];
    [connectionDict setObject:aConnection forKey:@"connection"];
    [connectionDict setObject:request forKey:@"request"];
    [connectionDict setObject:[NSMutableData data] forKey:@"data"];
    [connectionDict setObject:[completionBlock copy] forKey:@"completion"];
    
    [self.connections setObject:connectionDict forKey:[ZTRESTConnection keyForConnection:aConnection]];

#else
  // Synchronous in background thread connection
  dispatch_async(self.networkQueue, ^(){
    NSHTTPURLResponse* URLResponse;
    NSError* URLRequestError;
    
    NSData* URLRequestData = [NSURLConnection sendSynchronousRequest:request returningResponse:&URLResponse error:&URLRequestError];
    
    //NSLog(@"%@",[[NSString alloc] initWithBytes:[URLRequestData bytes] length:[URLRequestData length] encoding:NSUTF8StringEncoding]);
    
    id object = [self objectFormMimeTypeWithResponse:URLResponse withData:URLRequestData];
    
    completionBlock(URLResponse, object, URLRequestError);
  });
#endif
}

- (id)performRequest:(NSURLRequest*)request
{
  NSHTTPURLResponse* response;
  NSError* error;
  
  NSData* URLRequestData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
  
  id object = [self objectFormMimeTypeWithResponse:response withData:URLRequestData];
  
  self.lastResponse = response;
  self.lastError    = error;
  
  return object;
}

+ (NSString*)keyForConnection:(NSURLConnection*)connection
{
  return [NSString stringWithFormat:@"connection.%x",[connection hash]];
}

+ (NSString*)prepareRoute:(NSString*)route
{
  return route;
}

+ (NSString*)queryStringFromDictionary:(NSDictionary*)dictionary
{
  return [ZTRESTConnection queryStringFromDictionary:dictionary withBaseName:nil];
}

+ (NSString*)queryStringFromDictionary:(NSDictionary*)dictionary withBaseName:(NSString*)baseName
{
  NSMutableString *queryString = [NSMutableString string];
  
  BOOL firstParameter = YES;
  
  for (NSString *key in dictionary)
  {
    
    id value = dictionary[key];
    
    if (!firstParameter)
    {
      [queryString appendString:@"&"];
    }
    
    NSString *newBase;
    if(!baseName)
    {
      newBase = [NSString stringWithFormat:@"%@", key];
    }
    else
    {
      newBase = [NSString stringWithFormat:@"%@[%@]", baseName, key];
    }
    
    if ([value isKindOfClass:[NSDictionary class]])
    {
      NSString * dictQuery = [ZTRESTConnection queryStringFromDictionary:value withBaseName:newBase];
      [queryString appendString:dictQuery];
      continue;
    }
    
    if ([value isKindOfClass:[NSArray class]])
    {
      NSString * arrayQuery = [ZTRESTConnection queryStringFromArray:value withBaseName:newBase];
      [queryString appendString:arrayQuery];
      continue;
    }
    
    NSString* eBaseName = [ZTRESTConnection escape:[NSString stringWithFormat:@"%@", baseName]];
    NSString* eKey = [ZTRESTConnection escape:[NSString stringWithFormat:@"%@", key]];
    NSString* eValue = [ZTRESTConnection escape:[NSString stringWithFormat:@"%@", value]];
    
    if (baseName)
    {
      [queryString appendFormat:@"%@[%@]=%@", eBaseName, eKey, eValue];
    }
    else
    {
      [queryString appendFormat:@"%@=%@", eKey, eValue];
    }
    
    firstParameter = NO;
  }
  
  return queryString;
}

+ (NSString*)queryStringFromArray:(NSArray*)array withBaseName:(NSString*)baseName
{
  NSMutableString *queryString = [NSMutableString string];
  
  BOOL firstParameter = YES;
  
  for (NSString *value in array)
  {
    
    if (!firstParameter)
    {
      [queryString appendString:@"&"];
    }
    
    NSString* key = [NSString stringWithFormat:@"%@[]", baseName];
    
    //NSString* eBaseName = [ZTRESTConnection escape:[NSString stringWithFormat:@"%@", baseName]];
    NSString* eKey = [ZTRESTConnection escape:[NSString stringWithFormat:@"%@", key]];
    NSString* eValue = [ZTRESTConnection escape:[NSString stringWithFormat:@"%@", value]];
    
    [queryString appendFormat:@"%@=%@", eKey, eValue];
    
    firstParameter = NO;
    
  }
  
  return queryString;
}

//NOTE: Encode all HTTP data
+ (NSString*)escape:(NSString*)string
{
  return (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, CFSTR(":/?#[]@!$&’()*+,;="), kCFStringEncodingUTF8);
}

+ (NSData*)queryDataFromDictionary:(NSDictionary*)dictionary
{
  NSString* queryString = [ZTRESTConnection queryStringFromDictionary:dictionary];
  return [NSData dataWithBytes:[queryString UTF8String] length:[queryString length]];
}

- (id)objectFormMimeTypeWithResponse:(NSHTTPURLResponse*)response withData:(NSData*)data
{
  if ((NSInteger)(response.statusCode/100) != 2)//Is of type 200
  {
    return nil;
  }
  
  ZTRESTMimeHandler mimeHandler = [self.mimeTypeHandlers objectForKey:response.MIMEType];

  if (!mimeHandler)
  {
    NSLog(@"No mimehandler installed for mimeType:%@ using fallback handler\n%s", response.MIMEType, __PRETTY_FUNCTION__);
    mimeHandler = [self.mimeTypeHandlers objectForKey:@"fallback"];
  }  

  return mimeHandler(response, data);
}

- (void)installDefaultMimeTypeHandlers
{
  
  /*
   fallback
   */
  ZTRESTMimeHandler fallbackHandler = ^(NSHTTPURLResponse* response, NSData* data){
    return data;
  };
  [self.mimeTypeHandlers setObject:[fallbackHandler copy] forKey:@"fallback"];
  
  /*
   application/json
   */
  ZTRESTMimeHandler jsonHandler = ^(NSHTTPURLResponse* response, NSData* data){
    NSError* jsonError;
    id object = nil;
    
    if (data)
    {
      object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves |NSJSONReadingMutableContainers | NSJSONReadingAllowFragments error:&jsonError];
    }
    
    if (jsonError)
    {
      NSAssert(!jsonError, @"\n%@\n%s", jsonError, __PRETTY_FUNCTION__);
    }
    return object;
  };
  
  [self.mimeTypeHandlers setObject:[jsonHandler copy] forKey:@"application/json"];
  
  
  /*
   text/html
   */
  ZTRESTMimeHandler textHandler = ^(NSHTTPURLResponse* response, NSData* data){
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((__bridge  CFStringRef)[response textEncodingName]));
    id object = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:encoding];
    
    return object;
  };
  [self.mimeTypeHandlers setObject:[textHandler copy] forKey:@"text/html"];
  
}


#ifdef ZTRESTUseURLConnectionDelegate

#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
  if ([challenge previousFailureCount] == 0 && self.username && self.password)
  {
    
    NSURLCredential *newCredential = [NSURLCredential credentialWithUser:self.username
                                                                password:self.password
                                                             persistence:NSURLCredentialPersistenceForSession];
    [[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
  }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
  NSString* key = [ZTRESTConnection keyForConnection:connection];
  NSMutableDictionary* connectionDict = [self.connections objectForKey:key];
  [connectionDict setObject:response forKey:@"response"];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  NSString* key = [ZTRESTConnection keyForConnection:connection];
  NSMutableDictionary* connectionDict = [self.connections objectForKey:key];
  NSMutableData* connectionData = [connectionDict objectForKey:@"data"];
  [connectionData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  NSString* key = [ZTRESTConnection keyForConnection:connection];
  NSMutableDictionary* connectionDict = [self.connections objectForKey:key];
  ZTRESTCompletion completionBlock = [connectionDict objectForKey:@"completion"];
  NSHTTPURLResponse* response = [connectionDict objectForKey:@"response"];
  NSMutableData* data = [connectionDict objectForKey:@"data"];
    
  completionBlock(response, [NSData dataWithData:data], nil);
  [self.connections removeObjectForKey:key]; //Clear out cache
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
  
  NSString* key = [ZTRESTConnection keyForConnection:connection];
  NSMutableDictionary* connectionDict = [self.connections objectForKey:key];
  ZTRESTCompletion completionBlock = [connectionDict objectForKey:@"completion"];
  NSHTTPURLResponse* response = [connectionDict objectForKey:@"response"];
  
  completionBlock(response, nil, error);
  [self.connections removeObjectForKey:key]; // Clear out cache
}

#endif

@end
