# 视频播放器池

## 问题

信息流中混有视频卡片。一个 AVPlayer 实例会占用可观的内存和系统资源（解码器、缓冲、渲染管线），如果每条视频卡片都创建独立的 AVPlayer，列表滚几下内存就炸了。需要一套资源复用机制。

抖音、快手这类 App 用的是一个更复杂的方案——多播放器实例 + 预加载策略。但我的场景简单得多：单列信息流，同一时间用户只看得到一张视频卡。所以目标很明确：控制同时存在的 AVPlayer 实例数。

## 方案对比

### 方案 A：每卡一个 AVPlayer，onDisappear 销毁

```swift
VideoCard.onAppear { player = AVPlayer(url: url); player.play() }
VideoCard.onDisappear { player.pause(); player = nil }
```

**问题**：快速滚动时创建和销毁 AVPlayer 的开销很大。一个 `AVPlayerItem(url:)` 的初始化包含网络请求和缓冲分配，连续创建 5 个会导致滚动掉帧。而且 `onDisappear` 触发时机有延迟——卡片完全不可见前，下一个卡片的 `onAppear` 已经触发——瞬间存在两个 AVPlayer 同时播放。

### 方案 B：单例 AVPlayer + replaceCurrentItem

全 App 共享一个 AVPlayer，切换视频时 `replaceCurrentItem(with:)`。

**问题**：`replaceCurrentItem` 不是瞬时操作。切换时有明显的黑屏间隙（200-500ms），用户体验很差。而且无法同时保留两个播放器做预加载。

### 方案 C：AVPlayer 对象池（选用）

维护一个固定大小的 AVPlayer 池，卡片"借用"和"归还"播放器。

## 最终方案：VideoPlayerPool

```swift
final class VideoPlayerPool {
    static let shared = VideoPlayerPool()
    private var availablePlayers: [AVPlayer] = []
    private var inUsePlayers: Set<AVPlayer> = []
    private let poolSize = 3  // Constants.videoPlayerPoolSize
    private let lock = NSLock()
}
```

### 初始化

启动时预创建 3 个 AVPlayer，全部设为静音：

```swift
private init() {
    for _ in 0..<poolSize {
        let player = AVPlayer()
        player.isMuted = true
        availablePlayers.append(player)
    }
}
```

不创建 AVPlayerItem——item 在借用时才绑定 URL。

### 借用（dequeue）

优先从池中取，池空时才创建新实例：

```swift
func dequeuePlayer() -> AVPlayer {
    lock.lock()
    defer { lock.unlock() }
    if let player = availablePlayers.first {
        availablePlayers.removeFirst()
        inUsePlayers.insert(player)
        return player
    }
    let player = AVPlayer()  // 池耗尽时 fallback
    player.isMuted = true
    inUsePlayers.insert(player)
    return player
}
```

### 回收（recycle）

归还时暂停播放、清空 item。如果可用池未满则放回，满了就丢弃：

```swift
func recyclePlayer(_ player: AVPlayer) {
    lock.lock()
    defer { lock.unlock() }
    player.pause()
    player.replaceCurrentItem(with: nil)
    inUsePlayers.remove(player)
    if availablePlayers.count < poolSize {
        availablePlayers.append(player)
    }
}
```

### 线程安全

用 `NSLock` 而非串行队列——加锁范围只有几十纳秒的数组操作，用 GCD 的开销反而更大。

## 外流/内流播放模式

### 外流（FeedView 中的 VideoCard）

- 视频进入可视区时自动播放，但是**静音**（`isMuted = true`）
- 用户可点击播放/暂停按钮和静音/有声切换
- 卡片滚出可视区时暂停并回收播放器

状态管理：

```swift
VideoCard.onChange(of: isActive) { _, active in
    if active {
        setupPlayer(); player?.play(); isPlaying = true
    } else {
        player?.pause(); isPlaying = false; cleanupPlayer()
    }
}
```

`isActive` 由 FeedView 维护：当前可视区内最近出现的视频卡片的 `ad.id` 设为 `activeVideoId`，卡片 `onDisappear` 时清除。

### 内流（详情页）

- 进入详情页自动播放，**有声**（`isMuted = false`）
- 同样走对象池借用/回收流程
- 离开详情页时回收

内流用有声是设计选择：用户主动点进详情页说明对这条广告有兴趣，有声播放是合理的默认行为。外流静音是因为用户可能在公共场合刷信息流。

## 与系统播放器的集成

播放器 UI 用的是 `AVPlayerViewController`（通过 `UIViewControllerRepresentable` 桥接到 SwiftUI），但隐藏了原生控制条：

```swift
func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = player
    controller.showsPlaybackControls = false
    controller.videoGravity = .resizeAspectFill
    return controller
}
```

自定义播放/暂停/静音按钮覆盖在视频上方（`CardVideoOverlay`），用 `.highPriorityGesture` 避免被外层手势拦截。

## 效果

池大小为 3 时，快速滚动 10 张视频卡片的内存峰值稳定在约 3 个 AVPlayer 的水平。没加池之前同样的滚动路径会临时创建 5-6 个播放器，内存峰值高出约 60%。
