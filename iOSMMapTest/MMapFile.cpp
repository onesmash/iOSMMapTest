//
//  MMapFile.cpp
//  MMapFile
//
//  Created by Xuhui on 16/5/13.
//  Copyright © 2016年 Xuhui. All rights reserved.
//

#include "MMapFile.h"
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>    
#include <sys/stat.h>
#include <sys/mman.h>
#include <cmath>
#include <cstdlib>
using namespace std;

#define kMapFileSizeMax (1024 * 1024 * 700)

MMapFile::MMapFile(): opened_(false), size_(0), map_size_(0), fd_(-1), mmap_base_(NULL)
{
    //page_size_ = sysconf(_SC_PAGE_SIZE);
}

MMapFile::~MMapFile()
{
    if(opened_) {
        close();
    }
}


bool MMapFile::open(const string& filePath, Mode mode, AccessMode accessMode, size_t size)
{
    if(fd_ != -1) {
        close();
    }
    fd_ = openFile(filePath, mode);
    if(fd_ == -1){
        return false;
    }
    
    size_t file_size = lseek(fd_, 0, SEEK_END);
    if(mode == ModeRead) {
        size = file_size;
    } else {
        size = size ? size : file_size;
    }
    
    lseek(fd_, 0, SEEK_SET);
    
    if(mode == ModeWriteAppend || mode == ModeWriteTruncate) {
        if(file_size < size) {
            if(!resizeMapFile(size)) {
                ::close(fd_);
                size_ = 0;
                return false;
            }
        }
        mmap_base_ = (char*)mmap(0, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd_, 0);
    } else {
        mmap_base_ = (char*)mmap(0, size, PROT_READ, MAP_SHARED, fd_, 0);
    }
    
    if(mmap_base_ == MAP_FAILED) {
        ::close(fd_);
        size_ = 0;
        map_size_ = 0;
        return false;
    }
    
    filePath_ = filePath;
    size_ = file_size;
    map_size_ = size;
    mode_ = mode;
    opened_ = true;
    setAccessMode(accessMode);
    return true;
}

int MMapFile::openFile(const std::string& filePath, Mode mode)
{
    int fd = -1;
    do {
        if(mode == ModeRead) {
            fd = ::open(filePath.c_str(), O_RDONLY);
            if (fd == -1) {
                perror("Error opening file for reading");
            }
            break;
        }
        if(mode == ModeWriteAppend) {
            fd = ::open(filePath.c_str(), O_RDWR | O_CREAT | O_APPEND, 0644);
            if (fd == -1) {
                perror("Error opening file for writing");
            }
            break;
        }
        if(mode == ModeWriteTruncate) {
            fd = ::open(filePath.c_str(), O_RDWR | O_CREAT | O_TRUNC, 0644);
            if (fd == -1) {
                perror("Error opening file for writing");
            }
            break;
        }
    } while (false);
    return fd;
}

void MMapFile::setAccessMode(AccessMode mode)
{
    int access_mode = MADV_NORMAL;
    switch (mode) {
        case AccessModeNormal: {
            access_mode = MADV_NORMAL;
        } break;
        case AccessModeSequential: {
            access_mode = MADV_SEQUENTIAL;
        } break;
        case AccessModeRandom: {
            access_mode = MADV_RANDOM;
        } break;
        case AccessModeAggressive: {
            access_mode = MADV_WILLNEED;
        }
        default: {
            return;
        } break;
    }
    access_mode_ = mode;
    madvise(mmap_base_, map_size_, access_mode_);
}

bool MMapFile::resizeMapFile(size_t size)
{
    if(size < size_) return true;
    
    if(lseek(fd_, size - 1, SEEK_SET) == -1) {
        return false;
    }
    if(::write(fd_, "", 1) == -1) {
        return false;
    }
    
    return true;
}



bool MMapFile::remap(size_t size)
{
//    if(!flush(false)) {
//        return false;
//    }
    
    if(size > map_size_ && resizeMapFile(size)) {
        if(mmap_base_ != NULL && munmap(mmap_base_, map_size_) == -1) {
            return false;
        }
        if(mode_ == ModeWriteAppend || mode_ == ModeWriteTruncate) {
            mmap_base_ = (char*)mmap(0, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd_, 0);
        } else {
            mmap_base_ = (char*)mmap(0, size, PROT_READ, MAP_SHARED, fd_, 0);
        }
        if(mmap_base_ == MAP_FAILED) {
            mmap_base_ = NULL;
            close();
            return false;
        }
        map_size_ = size;
        setAccessMode(access_mode_);
    }
    return true;
}

bool MMapFile::write(const char* src, size_t size, off_t offset)
{
    if(!opened_) return false;
    if(offset + size <= map_size_) {
        memcpy(mmap_base_ + offset, src, size);
        size_ = (offset + size > size_ ? offset + size : size_);
        return true;
    } else {
        if(!remap(min<size_t>(kMapFileSizeMax, (size_ + size) * 2))) {
            return false;
        }
        return write(src, size, offset);
    }
}

bool MMapFile::append(const char* src, size_t size)
{
    return write(src, size, size_);
}

const char* MMapFile::read(size_t size, off_t offset)
{
    if(!opened_ || offset + size > size_) return NULL;
    return mmap_base_ + offset;
}

bool MMapFile::close()
{
    if(mmap_base_ != NULL && munmap(mmap_base_, map_size_) == -1) {
        return false;
    }
    mmap_base_ = NULL;
    
    if(fd_ != -1 && size_ < map_size_) {
        ftruncate(fd_, size_);
    }
    
    if(fd_ != -1 && ::close(fd_) != 0) {
        return false;
    }
    fd_ = -1;
    size_ = 0;
    map_size_ = 0;
    opened_ = false;
    return true;
    
}

bool MMapFile::flush(bool aync)
{
    if(mmap_base_ != NULL && msync(mmap_base_, size_, aync ? MS_ASYNC : MS_SYNC) == -1) {
        return false;
    }
    return true;
}

void MMapFile::warmup()
{
    for (size_t i = 0; i < map_size_; i++) {
        ((volatile char*)mmapBase())[i];
    }
}