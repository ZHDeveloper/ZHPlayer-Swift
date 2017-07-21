# ZHPlayer-Swift
ZHPlayer基于Swift语言，对AVPlayer进行封装的播放器。

## 新特性

* 兼容Swift4
* 可高度定制UI
* 简单易用

## 使用方法

1、初始化

```
let player = ZHPlayer()
player.url = URL(string: "xxxx")
或者
let player = ZHPlayer(url: <#T##URL#>)
```

2、添加播放器的view

```
contentView.addSubview(player.view)
player.view.fillToSuperview()
```

3、准备播放

```
player.prepareToPlay()
注意：切换播放的URL都需要调用prepareToPlay()方法才能播放
```

## 公开属性

```
/// 视频文件的大小
public var naturalSize: CGSize? 
```
