//
//  ViewController.m
//  iOSMMapTest
//
//  Created by Xuhui on 16/6/12.
//  Copyright © 2016年 Xuhui. All rights reserved.
//

#import "ViewController.h"
#import "MMapFile.h"
#import "ZipArchive.h"
#import "MBProgressHUD.h"

#import <fcntl.h>
#import <unistd.h>
#import <sstream>
#import <string>
#import <cstdio>

#define kFileSize (256 * 1024 * 1024)
#define kFilePath [NSString stringWithFormat:@"%@data.dat", NSTemporaryDirectory()]

void genData(char* buf, size_t size)
{
    for (int i = 0; i < size; i++) {
        buf[i] = rand();
    }
}

void createFile(size_t size)
{
    @autoreleasepool {
        NSString *dataFilePath = kFilePath;
        int fd = open(dataFilePath.UTF8String, O_RDWR | O_CREAT | O_TRUNC, 0644);
        lseek(fd, size - 1, SEEK_SET);
        write(fd, "", 1);
        lseek(fd, 0, SEEK_SET);
        close(fd);
    }
}

std::string ctest(bool isWrite, bool preCreateFile)
{
    @autoreleasepool {
        NSString *dataFilePath = kFilePath;
        if(isWrite) {
            [[NSFileManager defaultManager] removeItemAtPath:dataFilePath error:0];
            NSDate *date = [NSDate date];
            size_t size = kFileSize;
            char buf[4096];
            FILE* file = fopen(dataFilePath.UTF8String, "wb");
            if(preCreateFile) {
                int fd = fileno(file);
                lseek(fd, size - 1, SEEK_SET);
                write(fd, "", 1);
                lseek(fd, 0, SEEK_SET);
            }
            
            for (int i = 0; i < size; ) {
                genData(buf, sizeof(buf));
                size_t writeSize = std::min<size_t>(size - i, sizeof(buf));
                fwrite(buf, 1, writeSize, file) ;
                i += writeSize;
            }
            fclose(file);
            
            NSTimeInterval genDataCost = -[date timeIntervalSinceNow];
            
            std::stringstream ss;
            ss << "gen data cost: " << genDataCost;
            return ss.str();
        } else {
            NSDate *date = [NSDate date];
            size_t size = kFileSize;
            char buf[4096];
            //char fbuf[1024 * 16];
            FILE* file = fopen(dataFilePath.UTF8String, "rb");
            //setvbuf(file, fbuf, 1, 1024 * 16);
            int sum = 0;
            for (int i = 0; i < size; ) {
                size_t readSize = std::min<size_t>(size - i, sizeof(buf));
                fread(buf, 1, readSize, file);
                i += readSize;
                for (int j = 0; j < readSize; j++) {
                    sum += buf[j];
                }
            }
            fclose(file);
            NSTimeInterval cost = -[date timeIntervalSinceNow];
            std::stringstream ss;
            ss << "read data cost: " << cost << " sum: " << sum;
            return ss.str();
        }
        
    }
}

std::string stest(bool isWrite, bool preCreateFile)
{
    @autoreleasepool {
        NSString *dataFilePath = kFilePath;
        if(isWrite) {
            [[NSFileManager defaultManager] removeItemAtPath:dataFilePath error:0];
            NSDate *date = [NSDate date];
            size_t size = kFileSize;
            char buf[4096];
            int writefd = open(dataFilePath.UTF8String, O_RDWR | O_CREAT | O_TRUNC, 0644);
            if(preCreateFile) {
                lseek(writefd, size - 1, SEEK_SET);
                write(writefd, "", 1);
                lseek(writefd, 0, SEEK_SET);
            }
            
            for (int i = 0; i < size; ) {
                genData(buf, sizeof(buf));
                size_t writeSize = std::min<size_t>(size - i, sizeof(buf));
                write(writefd, buf, writeSize);
                i += writeSize;
            }
            close(writefd);
            
            NSTimeInterval genDataCost = -[date timeIntervalSinceNow];
            
            std::stringstream ss;
            ss << "gen data cost: " << genDataCost;
            return ss.str();
        } else {
            NSDate *date = [NSDate date];
            size_t size = kFileSize;
            char buf[4096];
            int readfd = open(dataFilePath.UTF8String, O_RDONLY);
            int sum = 0;
            for (int i = 0; i < size; ) {
                size_t readSize = std::min<size_t>(size - i, sizeof(buf));
                read(readfd, buf, readSize);
                i += readSize;
                for (int j = 0; j < readSize; j++) {
                    sum += buf[j];
                }
            }
            close(readfd);
            NSTimeInterval cost = -[date timeIntervalSinceNow];
            std::stringstream ss;
            ss << "read data cost: " << cost << " sum: " << sum;
            return ss.str();
        }
        
    }
}

std::string mtest(bool isWrite, bool preCreateFile)
{
    @autoreleasepool {
        NSString *dataFilePath = kFilePath;
        if(isWrite) {
            [[NSFileManager defaultManager] removeItemAtPath:dataFilePath error:0];
            NSDate *date = [NSDate date];
            size_t size = kFileSize;
            char buf[4096];
            MMapFile mapFile;
            mapFile.open(dataFilePath.UTF8String, MMapFile::ModeWriteTruncate, MMapFile::AccessModeAggressive, preCreateFile ? size : 4096);
            //mapFile.warmup();
            for (int i = 0; i < size; ) {
                genData(buf, sizeof(buf));
                size_t writeSize = std::min<size_t>(size - i, sizeof(buf));
                mapFile.write(buf, writeSize, i);
                i += writeSize;
            }
            
            NSTimeInterval genDataCost = -[date timeIntervalSinceNow];
            
            std::stringstream ss;
            ss << "gen data cost: " << genDataCost;
            return ss.str();
        } else {
            
            //size_t size = 512 * 1024 * 1024;
            //char buf[4096];
            
            MMapFile mapFile;
            mapFile.open(dataFilePath.UTF8String, MMapFile::ModeRead, MMapFile::AccessModeSequential);
            //mapFile.warmup();
            NSDate *date = [NSDate date];
            int sum = 0;
            for (int i = 0; i < mapFile.size(); i++) {
                sum += mapFile.mmapBase()[i];
            }
            
            NSTimeInterval cost = -[date timeIntervalSinceNow];
            std::stringstream ss;
            ss << "read data cost: " << cost << " sum: " << sum;
            return ss.str();
        }
        
    }
}

@interface ViewController () {
    BOOL _isWriteTest;
    
}
@property (strong, nonatomic) IBOutlet UIButton *mtestNotPreSetBtn;
@property (strong, nonatomic) IBOutlet UIButton *mtestPreSetBtn;
@property (strong, nonatomic) IBOutlet UIButton *stestNotPreSetBtn;
@property (strong, nonatomic) IBOutlet UIButton *stestPreSetBtn;
@property (strong, nonatomic) IBOutlet UIButton *ctestNotPreSetBtn;
@property (strong, nonatomic) IBOutlet UIButton *ctestPreSetBtn;



@property (strong, nonatomic) IBOutlet UILabel *mwriteNotPreLabel;

@property (strong, nonatomic) IBOutlet UILabel *mwritePreLabel;
@property (strong, nonatomic) IBOutlet UILabel *swriteNotePreLabel;

@property (strong, nonatomic) IBOutlet UILabel *swritePreLabel;
@property (strong, nonatomic) IBOutlet UILabel *cwritePreLabel;
@property (strong, nonatomic) IBOutlet UILabel *cwriteNotPreLabel;
@property (strong, nonatomic) IBOutlet UISegmentedControl *switchSegment;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _isWriteTest = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)onMWriteTestNotPreBtnTap:(id)sender
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^() {
        NSString *str = [NSString stringWithUTF8String:mtest(_isWriteTest, false).c_str()];
        dispatch_async(dispatch_get_main_queue(), ^() {
            _mwriteNotPreLabel.text = str;
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        });
    });
}

- (IBAction)onMWriteTestPreBtnTap:(id)sender
{
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^() {
            NSString *str = [NSString stringWithUTF8String:mtest(_isWriteTest, true).c_str()];
            dispatch_async(dispatch_get_main_queue(), ^() {
                _mwritePreLabel.text = str;
                [MBProgressHUD hideHUDForView:self.view animated:YES];
            });
        });
}

- (IBAction)onSTestNotPreBtnTap:(id)sender
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^() {
        NSString *str = [NSString stringWithUTF8String:stest(_isWriteTest, false).c_str()];
        dispatch_async(dispatch_get_main_queue(), ^() {
            _swriteNotePreLabel.text = str;
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        });
    });
}

- (IBAction)onSTestPreBtnTap:(id)sender
{
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^() {
            NSString *str = [NSString stringWithUTF8String:stest(_isWriteTest, true).c_str()];
            dispatch_async(dispatch_get_main_queue(), ^() {
                _swritePreLabel.text = str;
                [MBProgressHUD hideHUDForView:self.view animated:YES];
            });
        });
}
- (IBAction)onCWriteTestNotPreBtnTap:(id)sender
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^() {
        NSString *str = [NSString stringWithUTF8String:ctest(_isWriteTest, false).c_str()];
        dispatch_async(dispatch_get_main_queue(), ^() {
            _cwriteNotPreLabel.text = str;
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        });
    });
}
- (IBAction)onCWriteTestPreBtnTap:(id)sender
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^() {
        NSString *str = [NSString stringWithUTF8String:ctest(_isWriteTest, true).c_str()];
        dispatch_async(dispatch_get_main_queue(), ^() {
            _cwritePreLabel.text = str;
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        });
    });
}

- (IBAction)onSegmentChange:(UISegmentedControl *)sender {
    if(sender.selectedSegmentIndex == 0) {
        _isWriteTest = YES;
    } else {
        _isWriteTest = NO;
        NSString *dataFilePath = [NSString stringWithFormat:@"%@data.dat", NSTemporaryDirectory()];
        if(![[NSFileManager defaultManager] fileExistsAtPath:dataFilePath]) {
            [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            dispatch_async(dispatch_get_global_queue(0, 0), ^() {
                stest(true, true);;
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                });
            });
        }
    }
    [self.view setNeedsLayout];
}

- (void)viewWillLayoutSubviews
{
    if(_isWriteTest) {
        [_mtestPreSetBtn setTitle:@"mmap write test预先设置文件大小" forState:UIControlStateNormal];
        [_mtestNotPreSetBtn setTitle:@"mmap write test不预先设置文件大小" forState:UIControlStateNormal];
        [_stestPreSetBtn setTitle:@"write test预先设置文件大小" forState:UIControlStateNormal];
        [_stestNotPreSetBtn setTitle:@"write test不预先设置文件大小" forState:UIControlStateNormal];
        [_ctestPreSetBtn setTitle:@"fwrite test预先设置文件大小" forState:UIControlStateNormal];
        [_ctestNotPreSetBtn setTitle:@"fwrite test不预先设置文件大小" forState:UIControlStateNormal];
    } else {
        [_mtestPreSetBtn setTitle:@"mmap read test" forState:UIControlStateNormal];
        [_mtestNotPreSetBtn setTitle:@"" forState:UIControlStateNormal];
        [_stestPreSetBtn setTitle:@"read test" forState:UIControlStateNormal];
        [_stestNotPreSetBtn setTitle:@"" forState:UIControlStateNormal];
        [_ctestPreSetBtn setTitle:@"fread test" forState:UIControlStateNormal];
        [_ctestNotPreSetBtn setTitle:@"" forState:UIControlStateNormal];
    }
}

@end
