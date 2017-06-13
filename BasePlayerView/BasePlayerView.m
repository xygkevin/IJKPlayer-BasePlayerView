//
//  BasePlayerView.m
//  BasePlayerView
//
//  Created by xiaocan on 2017/6/13.
//  Copyright © 2017年 xiaocan. All rights reserved.
//

#define B_D_WIDTH   [UIScreen mainScreen].bounds.size.width
#define B_D_HEIGHT  [UIScreen mainScreen].bounds.size.height

#import "BasePlayerView.h"
#import "Masonry.h"



@interface BasePlayerView()

@property(nonatomic, strong, readwrite) NSURL *url;
@property(nonatomic, strong, readwrite) id<IJKMediaPlayback> player;
@property(nonatomic, assign, readwrite) BOOL isPlaying;
@property(nonatomic, assign, readwrite) BOOL lastPlayStatus; /**< YES：play，NO：pause */

@property(nonatomic, strong) UIProgressView *playProgress;

@end

@implementation BasePlayerView

+ (instancetype)shareInstance{
    static BasePlayerView *playerView = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        playerView = [[BasePlayerView alloc]initWithFrame:CGRectMake(0, 0, B_D_WIDTH, B_D_WIDTH / 16.0 * 9.0)];
        playerView.backgroundColor = [UIColor blackColor];
    });
    return playerView;
}

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        
        _playProgress = [[UIProgressView alloc]init];
        _playProgress.progressTintColor = [UIColor redColor];
        [self addSubview:_playProgress];
        [_playProgress mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.mas_left);
            make.right.equalTo(self.mas_right);
            make.bottom.equalTo(self.mas_bottom);
            make.height.mas_equalTo(2.0);
        }];
        _playProgress.progress = 0.f;
        [self refreshPlayTime];
        [self installMovieNotificationObservers];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

+ (void)playWithUrl:(NSURL *)playUrl withHeaderInfos:(NSDictionary *)headerInfo{
    [BasePlayerView shareInstance].lastPlayStatus = NO;
    [BasePlayerView shareInstance].url = playUrl;
    if ([BasePlayerView shareInstance].player) {
        [BasePlayerView shutDown];
    }
#ifdef DEBUG
    [IJKFFMoviePlayerController setLogReport:YES];
    [IJKFFMoviePlayerController setLogLevel:k_IJK_LOG_DEBUG];
#else
    [IJKFFMoviePlayerController setLogReport:NO];
    [IJKFFMoviePlayerController setLogLevel:k_IJK_LOG_INFO];
#endif
    
    [IJKFFMoviePlayerController checkIfFFmpegVersionMatch:NO];
    // [IJKFFMoviePlayerController checkIfPlayerVersionMatch:YES major:1 minor:0 micro:0];
    
    IJKFFOptions *options = [IJKFFOptions optionsByDefault];
    if (headerInfo && [headerInfo isKindOfClass:[NSDictionary class]]) {
        NSArray *keyArr = [headerInfo allKeys];
        for (NSString *keyStr in keyArr) {
            if ([[headerInfo objectForKey:keyStr] isKindOfClass:[NSString class]]) {
                [options setFormatOptionValue:[headerInfo objectForKey:keyStr] forKey:keyStr];
            }
        }
    }
    
    [BasePlayerView shareInstance].player = [[IJKFFMoviePlayerController alloc] initWithContentURL:[BasePlayerView shareInstance].url withOptions:options];
    [BasePlayerView shareInstance].player.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [BasePlayerView shareInstance].player.scalingMode = IJKMPMovieScalingModeAspectFit;
    [BasePlayerView shareInstance].player.shouldAutoplay = YES;
    
    [BasePlayerView shareInstance].autoresizesSubviews = YES;
    [[BasePlayerView shareInstance] insertSubview:[BasePlayerView shareInstance].player.view atIndex:0];
    [[BasePlayerView shareInstance].player.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo([BasePlayerView shareInstance].mas_top);
        make.left.equalTo([BasePlayerView shareInstance].mas_left);
        make.bottom.equalTo([BasePlayerView shareInstance].mas_bottom);
        make.right.equalTo([BasePlayerView shareInstance].mas_right);
    }];
    [[BasePlayerView shareInstance].player prepareToPlay];
}


#pragma mark-
#pragma mark- 播放器方法
+ (void)pause{
    [[BasePlayerView shareInstance].player pause];
}

+ (void)resume{
    [BasePlayerView shareInstance].player.currentPlaybackTime = 0.f;
    [[BasePlayerView shareInstance].player pause];
}

+ (void)play{
    [[BasePlayerView shareInstance].player play];
}

+ (void)shutDown{
    [[BasePlayerView shareInstance].player.view removeFromSuperview];
    [[BasePlayerView shareInstance].player shutdown];
}

+ (void)setCurrentPlayBackTime:(double)playTime{
    [BasePlayerView shareInstance].player.currentPlaybackTime = playTime;
}



#pragma mark- 
#pragma mark- 播放器通知方法
//加载状态变化
- (void)loadStateDidChange:(NSNotification*)notification{
    //    MPMovieLoadStateUnknown        = 0,
    //    MPMovieLoadStatePlayable       = 1 << 0,
    //    MPMovieLoadStatePlaythroughOK  = 1 << 1, // Playback will be automatically started in this state when shouldAutoplay is YES
    //    MPMovieLoadStateStalled        = 1 << 2, // Playback will be automatically paused in this state, if started
    
    IJKMPMovieLoadState loadState = _player.loadState;
    
    if ((loadState & IJKMPMovieLoadStatePlaythroughOK) != 0) {//加载完成
        NSLog(@"loadStateDidChange: IJKMPMovieLoadStatePlaythroughOK: %d\n", (int)loadState);
    } else if ((loadState & IJKMPMovieLoadStateStalled) != 0) {//加载停滞
        NSLog(@"loadStateDidChange: IJKMPMovieLoadStateStalled: %d\n", (int)loadState);
    } else {
        NSLog(@"loadStateDidChange: ???: %d\n", (int)loadState);
    }
}

- (void)moviePlayBackDidFinish:(NSNotification*)notification{
    //    MPMovieFinishReasonPlaybackEnded,
    //    MPMovieFinishReasonPlaybackError,
    //    MPMovieFinishReasonUserExited
    int reason = [[[notification userInfo] valueForKey:IJKMPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    
    switch (reason){
        case IJKMPMovieFinishReasonPlaybackEnded:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonPlaybackEnded: %d\n", reason);
            break;
            
        case IJKMPMovieFinishReasonUserExited:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonUserExited: %d\n", reason);
            break;
            
        case IJKMPMovieFinishReasonPlaybackError://视频播放出错
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonPlaybackError: %d\n", reason);
            break;
            
        default:
            NSLog(@"playbackPlayBackDidFinish: ???: %d\n", reason);
            break;
    }
}

//初始化完成、即将播放
- (void)mediaIsPreparedToPlayDidChange:(NSNotification*)notification{
    NSLog(@"mediaIsPreparedToPlayDidChange\n");
}

//播放状态更改
- (void)moviePlayBackStateDidChange:(NSNotification*)notification{
    //    MPMoviePlaybackStateStopped,
    //    MPMoviePlaybackStatePlaying,
    //    MPMoviePlaybackStatePaused,
    //    MPMoviePlaybackStateInterrupted,
    //    MPMoviePlaybackStateSeekingForward,
    //    MPMoviePlaybackStateSeekingBackward
    
    switch (_player.playbackState){
        case IJKMPMoviePlaybackStateStopped: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: stoped", (int)_player.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStatePlaying: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: playing", (int)_player.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStatePaused: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: paused", (int)_player.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStateInterrupted: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: interrupted", (int)_player.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStateSeekingForward:
        case IJKMPMoviePlaybackStateSeekingBackward: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: seeking", (int)_player.playbackState);
            break;
        }
        default: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: unknown", (int)_player.playbackState);
            break;
        }
    }
}





#pragma mark-
#pragma mark- 应用进入前后台
- (void)appWillEnterForeground:(NSNotification *)notifi{
    if (_lastPlayStatus && !self.isPlaying) {
        [_player play];
    }
    [self refreshPlayTime];
}

- (void)appDidEnterBackground:(NSNotification *)notifi{
    _lastPlayStatus = self.isPlaying;
    if (_lastPlayStatus) {
        [_player pause];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshPlayTime) object:nil];
}









#pragma mark-
#pragma mark- 刷新播放进度
- (void)refreshPlayTime{
    if (_player.currentPlaybackTime == 0 && _player.duration == 0) {
        _playProgress.progress = 0.f;
    }else{
       _playProgress.progress = _player.currentPlaybackTime / _player.duration;
    }
    
    NSLog(@"current play time:%f and total time:%f",_player.currentPlaybackTime,_player.duration);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshPlayTime) object:nil];
    [self performSelector:@selector(refreshPlayTime) withObject:nil afterDelay:0.5];
}



#pragma mark-
#pragma mark- 播放状态
- (BOOL)isPlaying{
    return [_player isPlaying];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor{
    [super setBackgroundColor:[UIColor blackColor]];
}

#pragma mark-
#pragma mark- 播放器通知
- (void)installMovieNotificationObservers{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadStateDidChange:) name:IJKMPMoviePlayerLoadStateDidChangeNotification object:_player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackDidFinish:) name:IJKMPMoviePlayerPlaybackDidFinishNotification object:_player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaIsPreparedToPlayDidChange:) name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification object:_player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackStateDidChange:) name:IJKMPMoviePlayerPlaybackStateDidChangeNotification object:_player];
}

- (void)removeMovieNotificationObservers{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerLoadStateDidChangeNotification object:_player];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackDidFinishNotification object:_player];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification object:_player];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackStateDidChangeNotification object:_player];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)dealloc{
    [self removeMovieNotificationObservers];
}

@end