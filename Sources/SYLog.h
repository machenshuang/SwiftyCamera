//
//  SYLog.h
//  Pods
//
//  Created by 马陈爽 on 2024/6/26.
//

#ifndef SYLog_h
#define SYLog_h

#ifdef DEBUG
#define SYLog(tag, fmt, ...) NSLog((@"[SwiftyCamera][%@] " fmt), tag, ##__VA_ARGS__)
#else
#define SYLog(tag, fmt, ...) do { } while (0)
#endif

#endif /* SYLog_h */
