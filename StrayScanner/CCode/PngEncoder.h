//
//  PngWriter.h
//  RHLab
//
//  Created by Gene Jiang on 5/30/2026.
//  Copyright © 2026 RHLab. All rights reserved.
//

#ifndef PngEncoder_h
#define PngEncoder_h
#include <Foundation/Foundation.h>

@interface PngEncoder : NSObject

- (instancetype) initWithDepth:(float *)content width:(int)width height:(int)height;
- (NSData*) fileContents;

@end
#endif /* PngWriter_h */
