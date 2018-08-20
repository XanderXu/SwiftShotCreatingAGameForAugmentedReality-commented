# SwiftShot: Creating a Game for Augmented Reality

See how Apple built the featured demo for WWDC18, and get tips for making your own multiplayer games using ARKit, SceneKit, and Swift.

学习苹果如何构建WWDC18的特色demo,并学习如何让你的多人游戏使用ARKit,SceneKit和Swift.

## Overview 综述

SwiftShot is an AR game for two to six players, featured in the [WWDC18 keynote][00]. Use this sample code project to experience it on your own device, see how it works, and build your own customized version of the game.

SwiftShot是在 [WWDC18 keynote][00]上发布的AR游戏,适用于2~6人.可以在你自己的设备上体会这个示例代码,看看它是如何工作的,还可以在此基础上自定义开发自己的游戏.

[00]:https://developer.apple.com/wwdc/

![Screenshots of the SwiftShot menu screen that appears on launch and of the AR game board placed on a real table after hosting or joining a game.](Documentation/SwiftShot.png)

Tap the Host button to start a game for other nearby players, or the Join button to participate in a game started on another device. If you're hosting, the app asks you to find a flat surface (like a table) to place the game board on: Drag, rotate, and pinch to position and resize the board, then tap when you're ready to play, and the game board appears.

点击Host按钮开始游戏,以便附近玩家加入,或者点击Join按钮加入一个别人开始的游戏.如果你是主机(hosting),那app会要求你找到一个平整的表面(如桌子)以放置游戏沙盘:用拖拽,旋转和缩放来定位和设置底座尺寸和位置,然后点击屏幕,游戏沙盘就出现了.

When the game board appears, you'll find a landscape of wooden blocks on the table, with three slingshots at each end. Move your device near a slingshot and touch the screen to grab it, then pull back and release to aim and fire the ball. Hit blocks with balls to knock them out of the way, and knock down all three of the other team's slingshots to win.

当游戏沙盘出现后,你会看到桌面上有木头块,两端各有三个弹弓.移动设备靠近弹弓,点击屏幕来抓起它,向后拉,瞄准然后松手发射.小球撞到中间的木块,会把它们撞开,把对方三个弹弓架都打翻,就是胜利了.

## Getting Started 开始

Requires Xcode 10.0, iOS 12.0 and an iOS device with an A9 or later processor. ARKit is not supported in iOS Simulator.

要求Xcode 10.0,iOS 12.0,使用A9及更新处理器的iOS设备.ARKit不支持模拟器.

## Designing Gameplay for AR 设计AR游戏性

SwiftShot embraces augmented reality as a medium for engaging gameplay.

SwiftShot使用了增强现实作为媒介,增加了游戏性.

**Encourage player movement to make gameplay more immersive.** In SwiftShot, you may find that you can't get a good shot at an enemy slingshot because blocks are in the way. And you may find a structure of blocks that can't be easily knocked down from one angle. But you can move to other slingshots and work with your teammates to find the best angle for a winning play. 

**鼓励玩家移动来使游戏性更强.** 在SwiftShot中,你可能会发现有些木块挡住了你射击敌人的路线.也可能有些木块从当前角度难以打倒.这时你可以和你的同伴一起换到另一个弹弓架处,找到最佳获胜角度.

**Don't encourage *too much* movement.** You have to aim carefully to fire a good shot, so you're less likely to bump into your teammates and send your device flying across the room.

**不鼓励过多的移动.** 你必须认真瞄准,准确射击,这样就不会撞到你的同伴,把设备撞飞出去.

**Foster social engagement.** Multiplayer AR games bring players together in the same space, giving them exciting new ways to have fun together. Using AR to watch a game as a spectator provides a different perspective and a new experience.

**促进社交参与.** 多人AR游戏将多个玩家聚焦到同一个地方,并提供了一起开心玩乐的新方式.以旁观者的视角用AR来观看一场游戏,会有不同的视点和新的体验.

**Keep games short, but add fun through variation.** Getting up and waving your device around at arm's length can make for exciting gameplay, but it can also be tiring. SwiftShot keeps matches short, encouraging party-style gameplay where players can drop into and out of games often. But SwiftShot also provides several game board layouts and special effects so that each game can be different.

**游戏要短,但是要有变化以增加乐趣.** 开始游戏,在一臂之长的距离内挥动设备是很好玩的,但是也会非常累.SwiftShot让每场比赛都很短,鼓励聚会形式的游戏,让玩家可以经常进入和退出游戏.同时SwiftShot也提供了一些不同的游戏沙盘布局和特殊效果,这样每次的游戏都会略有不同.

## Using Local Multipeer Networking and Sharing World Maps 使用本地多点网络及共享世界地图

SwiftShot uses the [MultipeerConnectivity][30] framework to establish a connection with other local players and send gameplay data between devices. When you start your own session, the player who starts the session creates an [`ARWorldMap`][31] containing ARKit's spatial understanding of the area around the game board. Other players joining the session receive a copy of the map and see a photo of the host's view of the table. Moving their device so they see a similar perspective helps ARKit process the received map and establish a shared frame of reference for the multiplayer game. 

SwiftShot使用[MultipeerConnectivity][30]框架来和其他玩家的设备间建立网络连接.当你开启你的session时,开启session的玩家创建一个 [`ARWorldMap`][31] ,里面包含了ARKit对游戏沙盘区域的空间理解数据.其他玩家加入session,会接收一份地图的拷贝并看到host对桌子的视角.来回移动他们的设备,使他们看到相似的视角,能帮助ARKit处理接收到的地图,并建立一个共享的多人游戏的参考框架.

For more details on setting up multiplayer AR sessions, see [Creating a Multiuser AR Experience][32]. For details on how this app implements Multipeer Connectivity, see the  [`GameBrowser`](x-source-tag://GameBrowser-MCNearbyServiceBrowserDelegate) and [`GameSession`](x-source-tag://GameSession-MCSessionDelegate) classes.

要了解如何建立多人玩家AR session的更多细节,见 [Creating a Multiuser AR Experience][32].要了解app如何实现Multipeer Connectivity的细节,见 [`GameBrowser`](x-source-tag://GameBrowser-MCNearbyServiceBrowserDelegate) 和 [`GameSession`](x-source-tag://GameSession-MCSessionDelegate) 类.

[30]:https://developer.apple.com/documentation/multipeerconnectivity
[31]:https://developer.apple.com/documentation/arkit/arworldmap
[32]:https://developer.apple.com/documentation/arkit/creating_a_multiuser_ar_experience

- Note: Using Multipeer Connectivity helps to ensure user privacy for the local space-mapping data that ARKit collects. Multipeer Connectivity transmits data directly between devices using peer-to-peer wireless networking. When you use the [`required`][33] encryption setting, it also protects against eavesdropping. 

  注意:使用Multipeer Connectivity能帮助保障用户隐私,即ARKit收集到的本地空间地图数据.Multipeer Connectivity使用peer-to-peer无线网络直接在设备间传输数据.当你启动[`required`][33] 加密设置时,它还会保护抵御窃听.

[33]:https://developer.apple.com/documentation/multipeerconnectivity/mcencryptionpreference/required

## Synchronizing Gameplay Actions 游戏动作同步

To synchronize game events between players—like launching a ball from a slingshot—SwiftShot uses an *action queue* pattern:

为了在玩家之间同步游戏事件—如从弹弓架上发射一个小球—SwiftShot使用了一个 *action queue* 模式:

- The [`GameManager`](x-source-tag://GameManager) class maintains a list of [`GameCommand`](x-source-tag://GameCommand) structures, each of which pairs a [`GameAction`](x-source-tag://GameAction) enum value describing the event with an identifier for the player responsible for that event.

   [`GameManager`](x-source-tag://GameManager) 类维护了一个[`GameCommand`](x-source-tag://GameCommand) 结构体列表,其中的每一个结构体匹配一个[`GameAction`](x-source-tag://GameAction) 枚举值,用来描述一个带有id的事件,用来表示玩家发起的事件.

- Whenever the local player performs an action that would trigger a game event (like touching the screen while near a slingshot), the game creates a corresponding [`GameAction`](x-source-tag://GameAction) and adds it to the end of the list. 

  当本地玩家执行一个动作,触发了一个游戏事件(如靠近弹弓架时触摸了屏幕),游戏会创建一个对应的[`GameAction`](x-source-tag://GameAction)并添加到列表的末尾.

- At the same time, the game encodes that [`GameAction`](x-source-tag://GameAction) and sends it through the multipeer session to other players. Each player's [`GameSession`](x-source-tag://GameSession) decodes actions as they are received, adding them to the local [`GameManager`](x-source-tag://GameManager) instance's command queue.

  与此同时,游戏将[`GameAction`](x-source-tag://GameAction)编码,并通过multipeer session发送给其他玩家.每个玩家的 [`GameSession`](x-source-tag://GameSession) 解码他们收到的动作,添加到本地的 [`GameManager`](x-source-tag://GameManager) 实例对象的命令队列(command queue)中.

- The [`GameManager`](x-source-tag://GameManager) class updates game state for each pass of the SceneKit rendering loop (at 60 frames per second). On each [`update`](x-source-tag://GameManager-update), it removes commands from the queue in the order they were added and applies the resulting effect for each in the game world (like launching a ball).

   [`GameManager`](x-source-tag://GameManager) 类在SceneKit的每个渲染循环(每秒60帧)中更新游戏状态.在每次 [`update`](x-source-tag://GameManager-update)中,它按照在游戏中的应用顺序来移除队列中的已执行的命令(如发射一个小球).

Defining the set of game events as a Swift enum brings multiple benefits. The enum can include additional information specific to each game action (like status for a slingshot grab or velocity for a ball launch) as an associated value for each enum case, which means you don't need to write code elsewhere determining which information is relevant for which action. By implementing the Swift [`Codable`][40] protocol on these enum types, actions can be easily serialized and deserialized for transmission over the local network.

用Swift中的枚举来定义游戏事件集合有很多优势.枚举可以包含附加的信息来特指每个游戏动作(如弹弓被抓起的具体状态或小球被发射出去的速度),即每个枚举case的关联值,这意味着你不需要再去其它地方写代码来表示哪个动作对应于哪个信息.通过在这些枚举类型上实现Swift的[`Codable`][40] 协议,动作可以被轻易地序列化和反序列化,并用于本地网络传输.

[40]:https://developer.apple.com/documentation/swift/codable

## Solving Multiplayer Physics 解决多人物理效果问题

[`SceneKit`][50] has a built-in physics engine that provides realistic physical behaviors for SwiftShot.  SceneKit simulates physics on only one device, so SwiftShot needs to ensure that all players in a session see the same physics results, while still providing realistic smooth animation. SwiftShot supports all ARKit-capable iOS devices and unreliable networking scenarios, so it can't guarantee that all devices in a session can synchronize at 60 frames per second.

[`SceneKit`][50] 有一个内置的物理引擎,它给SwiftShot提供了真实的物理行为.SceneKit只在本地设备上模拟物理效果,所以SwiftShot需要保证:在同一个session的所有玩家看到相同的物理效果,同时仍能提供真实平滑的动画.SwiftShot支持所有兼容ARKit的iOS设备,和不可靠的网络环境,所以它无法保证session中的所有设备都能同步在60帧每秒.

SwiftShot uses two techniques to solve these problems:

SwiftShot使用了两种技术来解决这些问题:

**Each peer in a session runs its own local physics simulation, but synchronizes physics results.** To ensure that gameplay-relevant physics results are consistent for all peers, the game designates the player who started the game as the source of truth. The peer in that "server" role continually sends physics state information to all other peers, who update their local physics simulations accordingly. The physics server doesn't encode and transmit the entire state of the SceneKit physics simulation, however—it sends updates only for bodies that are relevant to gameplay and whose state has changed since the last update. For implementation details, see the [`PhysicsSyncSceneData`](x-source-tag://PhysicsSyncSceneData) class in the sample code.

**session中的每一个peer运行自己的本地物理模拟,但同步物理效果的结果.** 为了保证游戏性相关的物理结果对所有peer都是一致的,游戏设计了开启游戏的玩家作为真相源(the source of truth).承担"server"角色的peer持续改善物理状态信息给所有其他peer,他们则相应更新本地物理模拟.这个物理服务器并没有编码或传输SceneKit物理模拟的完整状态,而只是更新那些和游戏性相关的物体,以及上次更新后状态改变的物体.要了解实现细节,见示例代码中的 [`PhysicsSyncSceneData`](x-source-tag://PhysicsSyncSceneData) 类.

**Domain-specific data compression minimizes the bandwidth cost of physics synchronization.** To transmit physics state information, the server encodes only the minimal information needed for accurate synchronization: position, orientation, velocity, and angular velocity, as well as a Boolean flag indicating whether the body should be treated as in motion or at rest. To send this information efficiently between devices, the [`PhysicsNodeData`](x-source-tag://PhysicsNodeData) and [`PhysicsPoolNodeData`](x-source-tag://PhysicsPoolNodeData) types encode it to a minimal binary representation. For example:

**特定域的数据压缩,最小化了物理同步的带宽占用.** 为了传输物理状态信息,服务器只编码了精确同步所需的最少信息:位置,朝向速度和角速度,同时还有一个布尔值来表示物体应该被作为运动物体还是静置物体对待.为了在设备之间高效地发送信息, [`PhysicsNodeData`](x-source-tag://PhysicsNodeData) 和 [`PhysicsPoolNodeData`](x-source-tag://PhysicsPoolNodeData) 类型将它编码成最小二进制表示法.例如:

- Position is a three-component vector of 32-bit float values (96 bits total), but the game is constrained to a space 80 units wide, tall, and deep. Applying this constraint provides for encoding position in only 48 bits (16 bits per component).

  位置是三个32-bits浮点数组成的三元向量(共96bit),但是游戏限制在一个长宽高为80个单位的空间内.考虑这些限制,编码位置只需要48bit(每个分量16bit).

- Orientation can be expressed as a unit quaternion of always-positive magnitude, which in turn can be written as a four-component vector. Additionally, one component of a unit quaternion is always dependent on the other three, and those components' values are always in the range from `-1/sqrt(2)` to `1/sqrt(2)`. Applying these constraints provides for encoding orientation in 38 bits (2 bits to identify the dependent component, and 12 bits each for the other three components).

  朝向则可以表示为一个总是正值的单位四元数,也就是可以转写为一个四元素的向量.另外,单位四元数中的任一个分量是和其他三个分量相关的,这些分量的范围是从 `-1/sqrt(2)` 到 `1/sqrt(2)`.考虑这些限制,编码四元数只需要38bit(2bit来定义独立分量,12bit给其他三个分量).

To encode and decode structures with this compact packing of bits, SwiftShot defines a [`BitStreamCodable`](x-source-tag://BitStreamCodable) protocol, extending the pattern of the Swift [`Codable`][40] protocol and providing a way to combine bit-stream-encoded types with other Swift [`Codable`][40] types in the same data stream. 

为了编码和解码这些紧凑型的结构体,SwiftShot定义了一个[`BitStreamCodable`](x-source-tag://BitStreamCodable) 协议,扩展了Swift中 [`Codable`][40] 协议的形式,并提供了一个方法将bit-stream-encoded类型和Swift [`Codable`][40] 类型在同一个数据流中组合起来.

- Note: SwiftShot's bit-stream encoding is purpose-built for minimal data size, so it omits features of a general-purpose encoder such as resilience to schema change. 

  注意:SwiftShot的bit-stream编码是为了最小化数据的尺寸,所以它忽略了通用型编码器的特性,如对架构更改的弹性.

The [`GameSession`](x-source-tag://GameSession) class sends and receives physics synchronization data in addition to game actions. Physics data synchronization occurs outside the queue used for game actions, so that each peer's physics world is updated to match the server's at the earliest opportunity.

 [`GameSession`](x-source-tag://GameSession) 类发送并接收附加于游戏中动作上的物理效果同步数据.物理数据同步发生在队列用于游戏动作之前,所以每个peer的物理世界会被更新,以匹配server上的早先的数据.

[50]:https://developer.apple.com/documentation/scenekit
