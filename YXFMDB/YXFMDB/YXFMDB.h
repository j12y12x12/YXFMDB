//
//  YXFMDB.h
//  YXFMDB
//
//  Created by jin on 2022/11/26.
//

#import <Foundation/Foundation.h>

#define YXDB_DEFAULT_NAME @"default_db"

// 注：目前不支持model嵌套，将嵌套的model转为json存入
@interface YXFMDB : NSObject
/**
 单例方法创建数据库，App主数据库，如果使用shareDatabase创建,则默认在NSDocumentDirectory下创建siren_db.sqlite,
 dbName 数据库的名称 如: @"Users.sqlite"，如果dbName = nil,则默认dbName=@"default_db.sqlite"
 dbPath 数据库的路径, 如果dbPath = nil，则路径默认为NSDocumentDirectory
 */
+ (instancetype)shareDatabase;
+ (instancetype)shareDatabase:(NSString *)dbName;
+ (instancetype)shareDatabase:(NSString *)dbName path:(NSString *)dbPath;

/**
 非单例方法创建数据库，适合某个模块单独创建数据库
 @param dbName 数据库的名称 如: @"Users.sqlite"
        dbPath 数据库的路径, 如果dbPath = nil, 则路径默认为NSDocumentDirectory
 */
- (instancetype)initWithDBName:(NSString *)dbName;
- (instancetype)initWithDBName:(NSString *)dbName path:(NSString *)dbPath;


/**
 创建表 通过传入的model或dictionary(如果是字典注意类型要写对),虽然都可以不过还是推荐以下都用model

 @param tableName 表的名称
 @param parameters 设置表的字段,可以传model(runtime自动生成字段)或字典(格式:@{@"name":@"TEXT"})
 @return 是否创建成功
 */
- (BOOL)createTable:(NSString *)tableName dicOrModel:(id)parameters;
/**
 同上,
 @param nameArr 不允许model或dic里的属性/key生成表的字段,如:nameArr = @[@"name"],则不允许名为name的属性/key 生成表的字段
 
 */
- (BOOL)createTable:(NSString *)tableName dicOrModel:(id)parameters excludeName:(NSArray *)nameArr;

/**
 增加: 向表中插入一条数据

 @param tableName 表的名称
 @param parameters 要插入的数据,可以是model或dictionary(格式:@{@"name":@"小李"})
 */
- (void)insertTable:(NSString *)tableName dicOrModel:(id)parameters complete:(void(^)(BOOL success))complete;

// 同步插入
- (BOOL)syncInsertTable:(NSString *)tableName dicOrModel:(id)parameters columnArr:(NSArray *)columnArr;

// 批量插入或更改
- (void)insertTable:(NSString *)tableName dicOrModelArray:(NSArray *)dicOrModelArray complete:(void(^)(BOOL success))complete;

// 删除表
- (void)deleteTable:(NSString *)tableName complete:(void(^)(BOOL success))complete;
// 清空表
- (void)deleteAllDataFromTable:(NSString *)tableName complete:(void(^)(BOOL success))complete;

/**
 删除: 根据条件删除表中数据
 @param tableName 表的名称
 @param where 条件语句, 如:@"where name = '小李'"
 */
- (void)deleteTable:(NSString *)tableName where:(NSString *)where complete:(void(^)(BOOL success))complete;

/**
 更改: 根据条件更改表中数据

 @param tableName 表的名称
 @param parameters 要更改的数据,可以是model或dictionary(格式:@{@"name":@"张三"})
 @param where 条件语句, 如:@"where name = '小李'"
 */
- (void)updateTable:(NSString *)tableName dicOrModel:(id)parameters where:(NSString *)where complete:(void(^)(BOOL success))complete;

/**
 查找: 根据条件查找表中数据

 @param tableName 表的名称
 @param parameters 每条查找结果放入model(可以是[Person class] or @"Person" or Person实例)或dictionary中
 @param where 条件语句, 如:@"where name = '小李'",
 */
- (void)lookupTable:(NSString *)tableName dicOrModel:(id)parameters where:(NSString *)where complete:(void(^)(NSArray *dataArray))complete;

/**
 增加新字段, 在建表后还想新增字段,可以在原建表model或新model中新增对应属性,然后传入即可新增该字段,该操作已在事务中执行
 
 @param tableName 表的名称
 @param parameters 如果传Model:数据库新增字段为建表时model所没有的属性,如果传dictionary格式为@{@"newname":@"TEXT"}
 */
- (void)alterTable:(NSString *)tableName dicOrModel:(id)parameters complete:(void(^)(BOOL success))complete;
/**
  nameArr 不允许生成字段的属性名的数组
 */
- (void)alterTable:(NSString *)tableName dicOrModel:(id)parameters excludeName:(NSArray *)nameArr complete:(void(^)(BOOL success))complete;

// 表是否存在
- (BOOL)isExistTable:(NSString *)tableName;
// 获取表中字段名
- (NSArray *)columnNameArray:(NSString *)tableName;
// 获取表中共有多少数据
- (int)tableItemCount:(NSString *)tableName;

@end
