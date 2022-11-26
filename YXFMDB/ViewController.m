//
//  ViewController.m
//  YXFMDB
//
//  Created by jin on 2022/11/26.
//

#import "ViewController.h"
#import "YXPersion.h"
#import "YXFMDB.h"

#define kPersionTable @"PersionTable"

@interface ViewController () <UITableViewDataSource,UITableViewDelegate>

@property (strong, nonatomic) UITableView *tableView;

@property (nonatomic, strong) NSArray *dataArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UIButton *insertBtn = [UIButton new];
    [insertBtn setTitle:@"插入" forState:UIControlStateNormal];
    [insertBtn addTarget:self action:@selector(insertBtnClick) forControlEvents:UIControlEventTouchUpInside];
    insertBtn.backgroundColor = [UIColor redColor];
    
    UIButton *insert2Btn = [UIButton new];
    [insert2Btn setTitle:@"插入2条" forState:UIControlStateNormal];
    [insert2Btn addTarget:self action:@selector(insert2BtnClick) forControlEvents:UIControlEventTouchUpInside];
    insert2Btn.backgroundColor = [UIColor blueColor];

    UIButton *clearBtn = [UIButton new];
    [clearBtn setTitle:@"清空" forState:UIControlStateNormal];
    [clearBtn addTarget:self action:@selector(clearBtnClick) forControlEvents:UIControlEventTouchUpInside];
    clearBtn.backgroundColor = [UIColor orangeColor];

    [self.view addSubview:self.tableView];
    [self.view addSubview:insertBtn];
    [self.view addSubview:insert2Btn];
    [self.view addSubview:clearBtn];
    
    self.tableView.frame = CGRectMake(0, 80, self.view.frame.size.width, self.view.frame.size.height - 180);
    insertBtn.frame = CGRectMake(20, self.view.frame.size.height - 80, 100, 44);
    insert2Btn.frame = CGRectMake(140, self.view.frame.size.height - 80, 100, 44);
    clearBtn.frame = CGRectMake(260, self.view.frame.size.height - 80, 100, 44);
    
    [self createTable];
    [self loadData];
}


- (BOOL)createTable {
    if ([[YXFMDB shareDatabase] isExistTable:kPersionTable]) {
        return YES;
    }
    BOOL flag = [[YXFMDB shareDatabase] createTable:kPersionTable dicOrModel:YXPersion.class];
    return flag;
}

- (void)loadData {
    [[YXFMDB shareDatabase] lookupTable:kPersionTable dicOrModel:YXPersion.class where:nil complete:^(NSArray *dataArray) {
        
        self.dataArray = dataArray;
        [self.tableView reloadData];

    }];
}


- (void)insertBtnClick {
    YXPersion *persion = [[YXPersion alloc] init];
    NSInteger count = self.dataArray.count;
    
    persion.name = [NSString stringWithFormat:@"小王%ld",(long)count];
    persion.age = 10+count;

    [[YXFMDB shareDatabase] insertTable:kPersionTable dicOrModel:persion complete:^(BOOL success) {
        [self loadData];
    }];
}


- (void)insert2BtnClick {
    YXPersion *persion = [[YXPersion alloc] init];
    NSInteger count = self.dataArray.count;
    
    persion.name = [NSString stringWithFormat:@"小王%ld",(long)count];
    persion.age = 10+count;

    YXPersion *persion2 = [[YXPersion alloc] init];
    persion2.name = [NSString stringWithFormat:@"小王%ld",(long)count+1];
    persion2.age = 10+count+1;

    NSArray *persionArray = @[persion,persion2];
    
    [[YXFMDB shareDatabase] insertTable:kPersionTable dicOrModelArray:persionArray complete:^(BOOL success) {
        [self loadData];
    }];
}

- (void)clearBtnClick {
    [[YXFMDB shareDatabase] deleteAllDataFromTable:kPersionTable complete:^(BOOL success) {
        [self loadData];
    }];
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] init];
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.tableHeaderView = [UIView new];
        _tableView.tableFooterView = [UIView new];
        
        if (@available(iOS 15.0, *)) {
            _tableView.sectionHeaderTopPadding = 0;
        }


        if (@available(iOS 11.0, *)) {
            _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        } else {
            self.automaticallyAdjustsScrollViewInsets = NO;
        }
    }
     
    return _tableView;
    
}

#pragma mark - UITableViewDataSource && UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataArray.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }

    YXPersion *persion = [self.dataArray objectAtIndex:indexPath.row];
    cell.textLabel.text = persion.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"age : %ld",(long)persion.age];
    return cell;
}



@end
