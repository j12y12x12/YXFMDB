//
//  YXFMDB.m
//  YXFMDB
//
//  Created by jin on 2022/11/26.
//

#import "YXFMDB.h"
#import <objc/runtime.h>
#import "FMDB.h"

// 数据库中常见的几种类型
#define SQL_TEXT     @"TEXT" //文本
#define SQL_INTEGER  @"INTEGER" //int long integer ...
#define SQL_REAL     @"REAL" //浮点
#define SQL_BLOB     @"BLOB" //data


@interface YXFMDB ()

@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, strong) FMDatabaseQueue *dbQueue;
@property (nonatomic, strong) FMDatabase *db;

@end

@implementation YXFMDB

- (FMDatabaseQueue *)dbQueue
{
    if (!_dbQueue) {
        FMDatabaseQueue *fmdb = [FMDatabaseQueue databaseQueueWithPath:_dbPath];
        self.dbQueue = fmdb;
//        [_db close];
        self.db = [fmdb valueForKey:@"_db"];
    }
    return _dbQueue;
}

static YXFMDB *yx_db = nil;
+ (instancetype)shareDatabase
{
    return [YXFMDB shareDatabase:nil];
}

+ (instancetype)shareDatabase:(NSString *)dbName
{
    return [YXFMDB shareDatabase:dbName path:nil];
}

+ (instancetype)shareDatabase:(NSString *)dbName path:(NSString *)dbPath
{
    if (!yx_db) {
        
        NSString *path;
        if (!dbName) {
            dbName = [NSString stringWithFormat:@"%@.sqlite",YXDB_DEFAULT_NAME];
        }
        if (!dbPath) {
            path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:dbName];
        } else {
            path = [dbPath stringByAppendingPathComponent:dbName];
        }
        
        FMDatabase *fmdb = [FMDatabase databaseWithPath:path];
        if ([fmdb open]) {
            yx_db = [[YXFMDB alloc] init];
            yx_db.db = fmdb;
            yx_db.dbPath = path;
        }
    }
    if (![yx_db.db open]) {
        NSLog(@"database can not open !");
        return nil;
    };
    return yx_db;
}

// 非单例初始化
- (instancetype)initWithDBName:(NSString *)dbName
{
    return [self initWithDBName:dbName path:nil];
}

- (instancetype)initWithDBName:(NSString *)dbName path:(NSString *)dbPath
{
    if (!dbName) {
        dbName = [NSString stringWithFormat:@"%@.sqlite",YXDB_DEFAULT_NAME];
    }
    NSString *path;
    if (!dbPath) {
        path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:dbName];
    } else {
        path = [dbPath stringByAppendingPathComponent:dbName];
    }
    
    FMDatabase *fmdb = [FMDatabase databaseWithPath:path];
    
    if ([fmdb open]) {
        self = [self init];
        if (self) {
            self.db = fmdb;
            self.dbPath = path;
            return self;
        }
    }
    return nil;
}


#pragma mark -- public method

- (BOOL)createTable:(NSString *)tableName dicOrModel:(id)parameters
{
    return [self createTable:tableName dicOrModel:parameters excludeName:nil];
}

- (BOOL)createTable:(NSString *)tableName dicOrModel:(id)parameters excludeName:(NSArray *)nameArr
{
    
    NSDictionary *dic;
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        dic = parameters;
    } else {
        Class CLS;
        if ([parameters isKindOfClass:[NSString class]]) {
            if (!NSClassFromString(parameters)) {
                CLS = nil;
            } else {
                CLS = NSClassFromString(parameters);
            }
        } else if ([parameters isKindOfClass:[NSObject class]]) {
            CLS = [parameters class];
        } else {
            CLS = parameters;
        }
        dic = [self modelToDictionary:CLS excludePropertyName:nameArr];
    }
    
    NSMutableString *fieldStr = [[NSMutableString alloc] initWithFormat:@"CREATE TABLE %@ (db_id  INTEGER PRIMARY KEY,", tableName];
    
    int keyCount = 0;
    for (NSString *key in dic) {
        
        keyCount++;
        if ((nameArr && [nameArr containsObject:key]) || [key isEqualToString:@"db_id"]) {
            continue;
        }
        if (keyCount == dic.count) {
            [fieldStr appendFormat:@" %@ %@)", key, dic[key]];
            break;
        }
        
        [fieldStr appendFormat:@" %@ %@,", key, dic[key]];
    }
    
    BOOL creatFlag;
    creatFlag = [_db executeUpdate:fieldStr];
    
    return creatFlag;
}


#pragma mark - *************** 增删改查
- (void)insertTable:(NSString *)tableName dicOrModel:(id)parameters complete:(void(^)(BOOL success))complete
{
    NSArray *columnArr = [self getColumnArr:tableName db:_db];
    [self insertTable:tableName dicOrModel:parameters columnArr:columnArr complete:complete];
}

- (void)insertTable:(NSString *)tableName dicOrModel:(id)parameters columnArr:(NSArray *)columnArr complete:(void(^)(BOOL success))complete
{
    YXDISPATCH_ASYNC_GLOBAL(^{
        [self inDatabase:^{
            BOOL flag = [self syncInsertTable:tableName dicOrModel:parameters columnArr:columnArr];
            if (complete) {
                YXDISPATCH_ASYNC_MAIN(^{
                    complete(flag);
                });
            }
        }];

    });
}

// 同步插入
- (BOOL)syncInsertTable:(NSString *)tableName dicOrModel:(id)parameters columnArr:(NSArray *)columnArr
{
    BOOL flag;
    NSDictionary *dic;
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        dic = parameters;
    }else {
        dic = [self getModelPropertyKeyValue:parameters tableName:tableName clomnArr:columnArr];
    }
    
    NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"INSERT INTO %@ (", tableName];
    NSMutableString *tempStr = [NSMutableString stringWithCapacity:0];
    NSMutableArray *argumentsArr = [NSMutableArray arrayWithCapacity:0];
    
    for (NSString *key in dic) {
        
        if (![columnArr containsObject:key] || [key isEqualToString:@"db_id"]) {
            continue;
        }
        [finalStr appendFormat:@"%@,", key];
        [tempStr appendString:@"?,"];
        
        [argumentsArr addObject:dic[key]];
    }
    
    [finalStr deleteCharactersInRange:NSMakeRange(finalStr.length-1, 1)];
    if (tempStr.length)
        [tempStr deleteCharactersInRange:NSMakeRange(tempStr.length-1, 1)];
    
    [finalStr appendFormat:@") values (%@)", tempStr];
    
    flag = [self.db executeUpdate:finalStr withArgumentsInArray:argumentsArr];
    return flag;
}

// 直接传一个array插入
- (void)insertTable:(NSString *)tableName dicOrModelArray:(NSArray *)dicOrModelArray complete:(void(^)(BOOL success))complete
{
    __block BOOL flag;
    [self inTransaction:^(BOOL *rollback) {
        NSArray *columnArr = [self getColumnArr:tableName db:self.db];
        for (id parameters in dicOrModelArray) {
            flag = [self syncInsertTable:tableName dicOrModel:parameters columnArr:columnArr];
            if (!flag) {
                if (!flag) {
                    *rollback = YES;
                    return;
                }
            }
        }
    }];
    
    if (complete) {
        YXDISPATCH_ASYNC_MAIN(^{
            complete(flag);
        });
    }
}


- (void)deleteTable:(NSString *)tableName complete:(void(^)(BOOL success))complete
{
    YXDISPATCH_ASYNC_GLOBAL(^{
        [self inDatabase:^{
            NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", tableName];
            BOOL flag = [self.db executeUpdate:sqlstr];
            if (complete) {
                YXDISPATCH_ASYNC_MAIN(^{
                    complete(flag);
                });
            }
        }];
    });
}

- (void)deleteAllDataFromTable:(NSString *)tableName complete:(void(^)(BOOL success))complete
{
    
    YXDISPATCH_ASYNC_GLOBAL(^{
        [self inDatabase:^{
            NSString *sqlstr = [NSString stringWithFormat:@"DELETE FROM %@", tableName];
            BOOL flag = [self.db executeUpdate:sqlstr];
            if (complete) {
                YXDISPATCH_ASYNC_MAIN(^{
                    complete(flag);
                });
            }
        }];
    });
}

// 根据条件删除数据，如:@"where name = '小李'"
- (void)deleteTable:(NSString *)tableName where:(NSString *)where complete:(void(^)(BOOL success))complete
{
    YXDISPATCH_ASYNC_GLOBAL(^{
        [self inDatabase:^{
            NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"delete from %@  %@", tableName,where];
            BOOL flag = [self.db executeUpdate:finalStr];
            if (complete) {
                YXDISPATCH_ASYNC_MAIN(^{
                    complete(flag);
                });
            }
        }];
    });
}

// 更新数据
- (void)updateTable:(NSString *)tableName dicOrModel:(id)parameters where:(NSString *)where complete:(void(^)(BOOL success))complete
{
    YXDISPATCH_ASYNC_GLOBAL(^{
        [self inDatabase:^{
            BOOL flag;
            NSDictionary *dic;
            NSArray *clomnArr = [self getColumnArr:tableName db:self.db];
            if ([parameters isKindOfClass:[NSDictionary class]]) {
                dic = parameters;
            }else {
                dic = [self getModelPropertyKeyValue:parameters tableName:tableName clomnArr:clomnArr];
            }
            
            NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"update %@ set ", tableName];
            NSMutableArray *argumentsArr = [NSMutableArray arrayWithCapacity:0];
            
            for (NSString *key in dic) {
                
                if (![clomnArr containsObject:key] || [key isEqualToString:@"db_id"]) {
                    continue;
                }
                [finalStr appendFormat:@"%@ = %@,", key, @"?"];
                [argumentsArr addObject:dic[key]];
            }
            
            [finalStr deleteCharactersInRange:NSMakeRange(finalStr.length-1, 1)];
            if (where.length) [finalStr appendFormat:@" %@", where];
            
            
            flag =  [self.db executeUpdate:finalStr withArgumentsInArray:argumentsArr];
            
            if (complete) {
                YXDISPATCH_ASYNC_MAIN(^{
                    complete(flag);
                });
            }

        }];
    });
}

- (void)lookupTable:(NSString *)tableName dicOrModel:(id)parameters where:(NSString *)where complete:(void(^)(NSArray *dataArray))complete
{
    YXDISPATCH_ASYNC_GLOBAL(^{
        [self inDatabase:^{
            NSMutableArray *resultMArr = [NSMutableArray arrayWithCapacity:0];
            NSDictionary *dic;
            NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"select * from %@ %@", tableName, where?where:@""];
            NSArray *clomnArr = [self getColumnArr:tableName db:self.db];
            
            FMResultSet *set = [self.db executeQuery:finalStr];
            
            if ([parameters isKindOfClass:[NSDictionary class]]) {
                dic = parameters;
                
                while ([set next]) {
                    
                    NSMutableDictionary *resultDic = [NSMutableDictionary dictionaryWithCapacity:0];
                    for (NSString *key in dic) {
                        
                        if ([dic[key] isEqualToString:SQL_TEXT]) {
                            id value = [set stringForColumn:key];
                            if (value)
                                [resultDic setObject:value forKey:key];
                        } else if ([dic[key] isEqualToString:SQL_INTEGER]) {
                            [resultDic setObject:@([set longLongIntForColumn:key]) forKey:key];
                        } else if ([dic[key] isEqualToString:SQL_REAL]) {
                            [resultDic setObject:[NSNumber numberWithDouble:[set doubleForColumn:key]] forKey:key];
                        } else if ([dic[key] isEqualToString:SQL_BLOB]) {
                            id value = [set dataForColumn:key];
                            if (value)
                                [resultDic setObject:value forKey:key];
                        }
                        
                    }
                    
                    if (resultDic) [resultMArr addObject:resultDic];
                }
                
            }else {
                
                Class CLS;
                if ([parameters isKindOfClass:[NSString class]]) {
                    if (!NSClassFromString(parameters)) {
                        CLS = nil;
                    } else {
                        CLS = NSClassFromString(parameters);
                    }
                } else if ([parameters isKindOfClass:[NSObject class]]) {
                    CLS = [parameters class];
                } else {
                    CLS = parameters;
                }
                
                if (CLS) {
                    NSDictionary *propertyType = [self modelToDictionary:CLS excludePropertyName:nil];
                    
                    while ([set next]) {
                        
                        id model = CLS.new;
                        for (NSString *name in clomnArr) {
                            if ([propertyType[name] isEqualToString:SQL_TEXT]) {
                                id value = [set stringForColumn:name];
                                if (value)
                                    [model setValue:value forKey:name];
                            } else if ([propertyType[name] isEqualToString:SQL_INTEGER]) {
                                [model setValue:@([set longLongIntForColumn:name]) forKey:name];
                            } else if ([propertyType[name] isEqualToString:SQL_REAL]) {
                                [model setValue:[NSNumber numberWithDouble:[set doubleForColumn:name]] forKey:name];
                            } else if ([propertyType[name] isEqualToString:SQL_BLOB]) {
                                id value = [set dataForColumn:name];
                                if (value)
                                    [model setValue:value forKey:name];
                            }
                        }
                        
                        [resultMArr addObject:model];
                    }
                }
                
            }
            if (complete) {
                YXDISPATCH_ASYNC_MAIN(^{
                    complete(resultMArr);
                });
            }
        }];
    });
}

// 增加字段
- (void)alterTable:(NSString *)tableName dicOrModel:(id)parameters complete:(void(^)(BOOL success))complete
{

    [self alterTable:tableName dicOrModel:parameters excludeName:nil complete:complete];
}

- (void)alterTable:(NSString *)tableName dicOrModel:(id)parameters excludeName:(NSArray *)nameArr complete:(void(^)(BOOL success))complete
{
    __block BOOL flag;
    [self inTransaction:^(BOOL *rollback) {
        if ([parameters isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in parameters) {
                if ([nameArr containsObject:key]) {
                    continue;
                }
                flag = [self.db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@", tableName, key, parameters[key]]];
                if (!flag) {
                    *rollback = YES;
                    return;
                }
            }
            
        } else {
            Class CLS;
            if ([parameters isKindOfClass:[NSString class]]) {
                if (!NSClassFromString(parameters)) {
                    CLS = nil;
                } else {
                    CLS = NSClassFromString(parameters);
                }
            } else if ([parameters isKindOfClass:[NSObject class]]) {
                CLS = [parameters class];
            } else {
                CLS = parameters;
            }
            NSDictionary *modelDic = [self modelToDictionary:CLS excludePropertyName:nameArr];
            NSArray *columnArr = [self getColumnArr:tableName db:self.db];
            for (NSString *key in modelDic) {
                if (![columnArr containsObject:key] && ![nameArr containsObject:key]) {
                    flag = [self.db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@", tableName, key, modelDic[key]]];
                    if (!flag) {
                        *rollback = YES;
                        return;
                    }
                }
            }
        }
    }];
    
    if (complete) {
        complete(flag);
    }
    
}

#pragma mark - *************** other
- (NSDictionary *)modelToDictionary:(Class)cls excludePropertyName:(NSArray *)nameArr
{
    NSMutableDictionary *mDic = [NSMutableDictionary dictionaryWithCapacity:0];
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList(cls, &outCount);
    for (int i = 0; i < outCount; i++) {
        
        NSString *name = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        if ([nameArr containsObject:name]) continue;
        
        NSString *type = [NSString stringWithCString:property_getAttributes(properties[i]) encoding:NSUTF8StringEncoding];
        
        id value = [self propertTypeConvert:type];
        if (value) {
            [mDic setObject:value forKey:name];
        }
        
    }
    free(properties);
    
    return mDic;
}

- (NSString *)propertTypeConvert:(NSString *)typeStr
{
    NSString *resultStr = nil;
    if ([typeStr hasPrefix:@"T@\"NSString\""]) {
        resultStr = SQL_TEXT;
    } else if ([typeStr hasPrefix:@"T@\"NSData\""]) {
        resultStr = SQL_BLOB;
    } else if ([typeStr hasPrefix:@"Ti"]||[typeStr hasPrefix:@"TI"]||[typeStr hasPrefix:@"Ts"]||[typeStr hasPrefix:@"TS"]||[typeStr hasPrefix:@"T@\"NSNumber\""]||[typeStr hasPrefix:@"TB"]||[typeStr hasPrefix:@"Tq"]||[typeStr hasPrefix:@"TQ"]) {
        resultStr = SQL_INTEGER;
    } else if ([typeStr hasPrefix:@"Tf"] || [typeStr hasPrefix:@"Td"]){
        resultStr= SQL_REAL;
    }
    
    return resultStr;
}



// 获取model的key和value
- (NSDictionary *)getModelPropertyKeyValue:(id)model tableName:(NSString *)tableName clomnArr:(NSArray *)clomnArr
{
    NSMutableDictionary *mDic = [NSMutableDictionary dictionaryWithCapacity:0];
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList([model class], &outCount);
    
    for (int i = 0; i < outCount; i++) {
        
        NSString *name = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        if (![clomnArr containsObject:name]) {
            continue;
        }
        
        id value = [model valueForKey:name];
        if (value) {
            [mDic setObject:value forKey:name];
        }
    }
    free(properties);
    
    return mDic;
}

// 得到表里的字段名称
- (NSArray *)getColumnArr:(NSString *)tableName db:(FMDatabase *)db
{
    NSMutableArray *mArr = [NSMutableArray arrayWithCapacity:0];
    
    FMResultSet *resultSet = [db getTableSchema:tableName];
    
    while ([resultSet next]) {
        [mArr addObject:[resultSet stringForColumn:@"name"]];
    }
    
    return mArr;
}


- (BOOL)isExistTable:(NSString *)tableName
{
    FMResultSet *set = [_db executeQuery:@"SELECT count(*) as 'count' FROM sqlite_master WHERE type ='table' and name = ?", tableName];
    while ([set next])
    {
        NSInteger count = [set intForColumn:@"count"];
        if (count == 0) {
            return NO;
        } else {
            return YES;
        }
    }
    return NO;
}

// 获取表中字段名
- (NSArray *)columnNameArray:(NSString *)tableName
{
    return [self getColumnArr:tableName db:_db];
}

// 获取表中共有多少数据
- (int)tableItemCount:(NSString *)tableName
{
    NSString *sqlstr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@", tableName];
    FMResultSet *set = [_db executeQuery:sqlstr];
    while ([set next])
    {
        return [set intForColumn:@"count"];
    }
    return 0;
}


- (void)close
{
    [_db close];
}

- (void)open
{
    [_db open];
}

// =============================   线程安全操作    ===============================
void YXDISPATCH_ASYNC_GLOBAL(void(^block)(void)){
    dispatch_async(dispatch_get_global_queue(0, 0), block);
}

void YXDISPATCH_ASYNC_MAIN(void(^block)(void)){
    dispatch_async(dispatch_get_main_queue(), block);
}

- (void)inDatabase:(void(^)(void))block
{
    
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        block();
    }];
}

- (void)inTransaction:(void(^)(BOOL *rollback))block
{
    [[self dbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        block(rollback);
    }];
    
}

@end

