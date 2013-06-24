//
//  NSData+Additions.h
//  Scribbeo2
//
//  Created by Zachry Thayer on 3/2/12.
//  Copyright (c) 2012 Zachry Thayer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Additions)

#pragma mark - Base 64

+ (NSData *)dataWithBase64EncodedString:(NSString *)string;
- (id)initWithBase64EncodedString:(NSString *)string;


#pragma mark - Gzip

/*
 - (NSData *)gzipDeflate;
 - (NSData *)gzipInflate;
 
 
 #pragma mark - TBXML
 
 + (NSData *)dataWithUncompressedContentsOfFile:(NSString *)file;
 
 */
#pragma mark - Miscellaneous

//- (NSString *)hexString;

- (NSString *)base64;
- (NSString *)NSString;

+ (NSData *)dataWithString:(NSString *)aString;

@end
