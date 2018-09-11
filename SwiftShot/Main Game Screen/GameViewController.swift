/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR game.
*/

import UIKit
import SceneKit
import ARKit
import AVFoundation
import os.signpost

class GameViewController: UIViewController {
    enum SessionState {
        case setup
        case lookingForSurface
        case adjustingBoard
        case placingBoard
        case waitingForBoard
        case localizingToBoard
        case setupLevel
        case gameInProgress

        var localizedInstruction: String? {
            guard !UserDefaults.standard.disableInGameUI else { return nil }
            switch self {
            case .lookingForSurface:
                return NSLocalizedString("Find a flat surface to place the game.", comment: "")
            case .placingBoard:
                return NSLocalizedString("Scale, rotate or move the board.", comment: "")
            case .adjustingBoard:
                return NSLocalizedString("Make adjustments and tap to continue.", comment: "")
            case .gameInProgress:
                if UserDefaults.standard.hasOnboarded || UserDefaults.standard.spectator {
                    return nil
                } else {
                    return NSLocalizedString("Move closer to a slingshot.", comment: "")
                }
            case .setupLevel:
                return nil
            case .waitingForBoard:
                return NSLocalizedString("Synchronizing world map…", comment: "")
            case .localizingToBoard:
                return NSLocalizedString("Point the camera towards the table.", comment: "")
            case .setup:
                return nil
            }
        }
    }

    @IBOutlet var sceneView: ARSCNView!
    private let audioListenerNode = SCNNode()

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var trackingStateLabel: UILabel!

    @IBOutlet weak var exitGameButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    
    // Maps UI
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var loadButton: UIButton!
    @IBOutlet weak var mappingStateLabel: UILabel!
    
    // Relocalization help
    @IBOutlet weak var saveAsKeyPositionButton: UIButton!
    @IBOutlet weak var keyPositionThumbnail: UIImageView!
    @IBOutlet weak var nextKeyPositionThumbnailButton: UIButton!
    @IBOutlet weak var previousKeyPositionThumbnailButton: UIButton!
    
    // Gesture recognizers
    @IBOutlet var tapGestureRecognizer: UITapGestureRecognizer!
    @IBOutlet var pinchGestureRecognizer: UIPinchGestureRecognizer!
    @IBOutlet var rotateGestureRecognizer: UIRotationGestureRecognizer!
    @IBOutlet var panGestureRecognizer: UIPanGestureRecognizer!

    @IBOutlet var inSceneButtons: [UIButton]!

    @IBOutlet weak var instructionLabel: UILabel!
    
    @IBOutlet weak var thermalStateLabel: UILabel!
    @IBOutlet weak var networkDelayText: UILabel!
    @IBOutlet weak var notificationLabel: UILabel!
    
    @IBOutlet var teamACatapultImages: [UIImageView]!
    @IBOutlet var teamBCatapultImages: [UIImageView]!

    private var teamACatapultCount = 0 {
        didSet {
            guard oldValue != teamACatapultCount else { return }

            // The "highlighted" state actually means that the catapult has been disabled.
            // "highlighted"状态,实际上意味着该弹弓已经不可用了.
            for (index, catapultImage) in teamACatapultImages.enumerated() {
                let shouldAppear = index < teamACatapultCount
                catapultImage.isHighlighted = !shouldAppear
            }
        }
    }

    private var teamBCatapultCountTemp = 0 {
        didSet {
            guard oldValue != teamBCatapultCountTemp else { return }

            // The "highlighted" state actually means that the catapult has been disabled.
            // "highlighted"状态,实际上意味着该弹弓已经不可用了.
            for (index, catapultImage) in teamBCatapultImages.enumerated() {
                let shouldAppear = index < teamBCatapultCountTemp
                catapultImage.isHighlighted = !shouldAppear
            }
        }
    }

    var gameManager: GameManager? {
        didSet {
            guard let manager = gameManager else {
                sessionState = .setup
                return
            }
            
            if manager.isNetworked && !manager.isServer {
                sessionState = .waitingForBoard
            } else {
                sessionState = .lookingForSurface
            }
            manager.delegate = self
        }
    }

    var sessionState: SessionState = .setup {
        didSet {
            guard oldValue != sessionState else { return }

            os_log(.info, "session state changed to %s", "\(sessionState)")
            configureView()
            configureARSession()
        }
    }
    
    var isSessionInterrupted = false {
        didSet {
            if isSessionInterrupted && !UserDefaults.standard.disableInGameUI {
                instructionLabel.isHidden = false
                instructionLabel.text = NSLocalizedString("Point the camera towards the table.", comment: "")
            } else {
                if let localizedInstruction = sessionState.localizedInstruction {
                    instructionLabel.isHidden = false
                    instructionLabel.text = localizedInstruction
                } else {
                    instructionLabel.isHidden = true
                }
            }
        }
    }

    // used when state is localizingToWorldMap or localizingToSavedMap
    // 当状态是localizingToWorldMap or localizingToSavedMap 时用到
    var targetWorldMap: ARWorldMap?

    var gameBoard = GameBoard()
    
    // Root node of the level
    // 根节点
    var renderRoot = SCNNode()
    
    var panOffset = float3()

    var buttonBeep: ButtonBeep!
    var backButtonBeep: ButtonBeep!

    // Music player
    let musicCoordinator = MusicCoordinator()
    
    var selectedLevel: GameLevel? {
        didSet {
            if let level = selectedLevel {
                gameBoard.preferredSize = level.targetSize
            }
        }
    }

    // Proximity manager for beacons
    // beacons的接近管理器
    let proximityManager = ProximityManager.shared

    var canAdjustBoard: Bool {
        return sessionState == .placingBoard || sessionState == .adjustingBoard
    }
    
    var attemptingBoardPlacement: Bool {
        return sessionState == .lookingForSurface || sessionState == .placingBoard
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view's delegate
        sceneView.delegate = self
        
        // Explicitly set the listener position to be in an SCNNode that we control
        // because the scaling of the scaling difference between the render coordinate
        // space and the simulation coordinate space. This node isn't added to the node
        // hierarchy of the scene, so it isn't affected by changes to the scene scale.
        // On each frame update, however, its position is explicitly set to a transformed
        // value that is consistent with the game objects in the scene.
        // 将音频听者的位置设置到一个我们控制的SCNNode上
        // 因为渲染坐标空间的缩放,与物理模拟坐标空间的缩放不同.这个节点并没有添加到场景树的层级节点上,所以它不会被场景缩放影响.
        // 在每个帧更新时,它的位置被设置为了个变换过的值,这个值和场景中的游戏物体保持一致.
        sceneView.audioListener = audioListenerNode

        sceneView.scene.rootNode.addChildNode(gameBoard)

        sessionState = .setup
        sceneView.session.delegate = self

        instructionLabel.clipsToBounds = true
        instructionLabel.layer.cornerRadius = 8.0
        
        if UserDefaults.standard.allowGameBoardAutoSize {
            sceneView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:))))
        }
        
        notificationLabel.clipsToBounds = true
        notificationLabel.layer.cornerRadius = 8.0

        buttonBeep = ButtonBeep(name: "button_forward.wav", volume: 0.5)
        backButtonBeep = ButtonBeep(name: "button_backward.wav", volume: 0.5)
        
        renderRoot.name = "_renderRoot"
        sceneView.scene.rootNode.addChildNode(renderRoot)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateThermalStateIndicator),
                                               name: ProcessInfo.thermalStateDidChangeNotification,
                                               object: nil)
        
        // this preloads the assets used by the level - materials and texture and compiles shaders
        // 加载各个级别中用到的素材--材质,纹理和着色器
        preloadLevel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureARSession()
        configureView()
    }
    
    @objc
    private func updateThermalStateIndicator() {
        DispatchQueue.main.async {
            // Show thermal state label if default enabled and state is critical
            // 当显示热状态label
            self.thermalStateLabel.isHidden = !(UserDefaults.standard.showThermalState && ProcessInfo.processInfo.thermalState == .critical)
        }
    }

    // MARK: - Configuration
    func configureView() {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

        var debugOptions: SCNDebugOptions = []
        
        // fix the scaling of the physics debug view to match the world
        // 修复缩放导致的物理视图bug,以匹配世界
        if UserDefaults.standard.showPhysicsDebug { debugOptions.insert(.showPhysicsShapes) }
        
        // show where ARKit is detecting feature points
        // 显示ARKit检测到的特征点
        if UserDefaults.standard.showARDebug { debugOptions.insert(ARSCNDebugOptions.showFeaturePoints) }
        
        // see high poly-count and LOD transitions - wireframe overlay
        // 显示多边形数目和细节级别
        if UserDefaults.standard.showWireframe { debugOptions.insert(SCNDebugOptions.showWireframe) }
        
        sceneView.debugOptions = debugOptions
        
        // perf stats
        // 性能统计
        sceneView.showsStatistics = UserDefaults.standard.showSceneViewStats
        
        trackingStateLabel.isHidden = !UserDefaults.standard.showTrackingState

        // smooth the edges by rendering at higher resolution
        // defaults to none on iOS, use on faster GPUs
        // 0, 2, 4 on iOS, 8, 16x on macOS
        // 提高分辨率进行边缘反锯齿
        // iOS上默认为none,用在更新更快的GPU上,0, 2, 4 on iOS, 8, 16x on macOS
        sceneView.antialiasingMode = UserDefaults.standard.antialiasingMode ? .multisampling4X : .none
        
        os_log(.info, "antialiasing set to: %s", UserDefaults.standard.antialiasingMode ? "4x" : "none")
        
        if let localizedInstruction = sessionState.localizedInstruction {
            instructionLabel.isHidden = false
            instructionLabel.text = localizedInstruction
        } else {
            instructionLabel.isHidden = true
        }

        if sessionState == .waitingForBoard {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
     
        if !UserDefaults.standard.showSettingsInGame {
            settingsButton.isHidden = true
        }

        if UserDefaults.standard.disableInGameUI {
            exitGameButton.setImage(nil, for: .normal)
        } else {
            exitGameButton.setImage(#imageLiteral(resourceName: "close"), for: .normal)
        }
        
        exitGameButton.isHidden = sessionState == .setup
        
        configureMappingUI()
        configureRelocalizationHelp()
        updateThermalStateIndicator()
    }

    func configureARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.isAutoFocusEnabled = UserDefaults.standard.autoFocus
        let options: ARSession.RunOptions
        switch sessionState {
        case .setup:
            // in setup
            os_log(.info, "AR session paused")
            sceneView.session.pause()
            return
        case .lookingForSurface, .waitingForBoard:
            // both server and client, go ahead and start tracking the world
            // 主机与从机,均开始追踪世界
            configuration.planeDetection = [.horizontal]
            options = [.resetTracking, .removeExistingAnchors]
            
            // Only reset session if not already running
            // 只有在已经不运行的情况下,才重置session
            if sceneView.isPlaying {
                return
            }
        case .placingBoard, .adjustingBoard:
            // we've found at least one surface, but should keep looking.
            // so no change to the running session
            // 我们已经发现了至少一个平面,但应该继续寻找.所以不要改变运行中的session
            return
        case .localizingToBoard:
            guard let targetWorldMap = targetWorldMap else { os_log(.error, "should have had a world map"); return }
            configuration.initialWorldMap = targetWorldMap
            configuration.planeDetection = [.horizontal]
            options = [.resetTracking, .removeExistingAnchors]
            gameBoard.anchor = targetWorldMap.boardAnchor
            if let boardAnchor = gameBoard.anchor {
                gameBoard.simdTransform = boardAnchor.transform
                gameBoard.simdScale = float3( Float(boardAnchor.size.width) )
            }
            gameBoard.hideBorder(duration: 0)
            
        case .setupLevel:
            // more init
            return
        case .gameInProgress:
            // The game is in progress, no change to the running session
            // 游戏正在进行中,不改变运行中的session
            return
        }
        
        // Turning light estimation off to test PBR on SceneKit file
        // 关闭光照估计来测试PBR在SceneKit文件上的效果
        configuration.isLightEstimationEnabled = false
        
        os_log(.info, "configured AR session")
        sceneView.session.run(configuration, options: options)
    }

    // MARK: - UI Buttons
    @IBAction func exitGamePressed(_ sender: UIButton) {
        let leaveAction = UIAlertAction(title: NSLocalizedString("Leave", comment: ""), style: .cancel) { _ in
            self.exitGame()
            // start looking for beacons again
            // 重新开始寻找beacons
            self.proximityManager.start()
        }
        let stayAction = UIAlertAction(title: NSLocalizedString("Stay", comment: ""), style: .default)
        let actions = [stayAction, leaveAction]
        
        let localizedTitle = NSLocalizedString("Are you sure you want to leave the game?", comment: "")
        var localizedMessage: String?
        
        if let isServer = gameManager?.isServer, isServer {
            localizedMessage = NSLocalizedString("You’re the host, so if you leave now the other players will have to leave too.", comment: "")
        }
        
        showAlert(title: localizedTitle, message: localizedMessage, actions: actions)
    }
    
    func exitGame() {
        backButtonBeep.play()
        gameManager?.releaseLevel()
        gameManager = nil
        showOverlay()
        
        // Cleanup the current loaded map
        // 清理当前加载过的地图
        targetWorldMap = nil
        teamACatapultImages.forEach {
            $0.isHidden = true
            $0.isHighlighted = false
        }
        teamBCatapultImages.forEach {
            $0.isHidden = true
            $0.isHighlighted = false
        }
        notificationLabel.isHidden = true
        
        UserDefaults.standard.hasOnboarded = false
        
        // Reset game board
        // 重置游戏的底座
        gameBoard.reset()
        if let boardAnchor = gameBoard.anchor {
            sceneView.session.remove(anchor: boardAnchor)
            gameBoard.anchor = nil
        }
    }

    func showAlert(title: String, message: String? = nil, actions: [UIAlertAction]? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if let actions = actions {
            actions.forEach { alertController.addAction($0) }
        } else {
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        present(alertController, animated: true, completion: nil)
    }

    var screenCenter: CGPoint {
        let bounds = sceneView.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Board management
    func updateGameBoard(frame: ARFrame) {
        
        if sessionState == .setupLevel {
            // this will advance the session state
            // 提升session状态
            setupLevel()
            return
        }
        
        // Only automatically update board when looking for surface or placing board
        // 只在寻找表面或放置底座过程中,才自动调整底座
        guard attemptingBoardPlacement else {
            return
        }
        
        // Make sure this is only run on the render thread
        // 确保只在渲染线程运行
        if gameBoard.parent == nil {
            sceneView.scene.rootNode.addChildNode(gameBoard)
        }
        
        // Perform hit testing only when ARKit tracking is in a good state.
        // 只有在ARKit追踪状态正常时,才执行命中测试
        if case .normal = frame.camera.trackingState {
            
            if let result = sceneView.hitTest(screenCenter, types: [.estimatedHorizontalPlane, .existingPlaneUsingExtent]).first {
                // Ignore results that are too close to the camera when initially placing
                // 当初始化放置时,忽略那些太靠近相机的点
                guard result.distance > 0.5 || sessionState == .placingBoard else { return }
                
                sessionState = .placingBoard
                gameBoard.update(with: result, camera: frame.camera)
            } else {
                sessionState = .lookingForSurface
                if !gameBoard.isBorderHidden {
                    gameBoard.hideBorder()
                }
            }
        }
    }
    
    private func process(boardAction: BoardSetupAction, from peer: Player) {
        switch boardAction {
        case .boardLocation(let location):
            switch location {
            case .worldMapData(let data):
                os_log(.info, "Received WorldMap data. Size: %d", data.count)
                loadWorldMap(from: data)
            case .manual:
                os_log(.info, "Received a manual board placement")
                sessionState = .lookingForSurface
            }
        case .requestBoardLocation:
            sendWorldTo(peer: peer)
        }
    }
    
    /// Load the World Map from archived data
    /// 从压缩数据中加载出世界地图
    func loadWorldMap(from archivedData: Data) {
        do {
            let uncompressedData = try archivedData.decompressed()
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: uncompressedData) else {
                os_log(.error, "The WorldMap received couldn't be read")
                DispatchQueue.main.async {
                    self.showAlert(title: "An error occured while loading the WorldMap (Failed to read)")
                    self.sessionState = .setup
                }
                return
            }
            
            DispatchQueue.main.async {
                self.targetWorldMap = worldMap
                self.sessionState = .localizingToBoard
            }
        } catch {
            os_log(.error, "The WorldMap received couldn't be decompressed")
            DispatchQueue.main.async {
                self.showAlert(title: "An error occured while loading the WorldMap (Failed to decompress)")
                self.sessionState = .setup
            }
        }
    }
    
    func preloadLevel() {
        os_signpost(.begin, log: .preload_assets, name: .preload_assets, signpostID: .preload_assets,
                    "Preloading assets started")

        let main = DispatchQueue.main
        let background = DispatchQueue.global()
        background.async {
            for level in GameLevel.allLevels {
                // this is just a dummy scene to preload data
                // this is not added to the sceneView
                // 这只是个场景的替身来预加载数据,它不会被加载到sceneView上
                let scene = SCNScene()
                // this may result in two callers loading the scene
                // 这里会导致两个调用者加载场景
                level.load()
                if let activeLevel = level.activeLevel {
                    self.setLevelLighting(activeLevel)
                    scene.rootNode.addChildNode(activeLevel)
                    scene.isPaused = true

                    // This doesn't actually add the scene to the ARSCNView, it just sets up a background task
                    // the preloading is done on a background thread, and the completion handler called

                    // prepare must be called from main thread
                    // 这里并不会真的将场景添加到ARSCNView上,它只是建立一个后台任务
                    // 预加载在后台线程完成,并调用completion handler
                    // 预加载必需是在主线程被调用
                    main.sync {
                        // preparing a scene compiles shaders
                        // 准备一个场景来编译着色器
                        self.sceneView.prepare([scene], completionHandler: { success in
                            if success {
                                os_signpost(.end, log: .preload_assets, name: .preload_assets, signpostID: .preload_assets,
                                            "Preloading assets succeeded")
                            } else {
                                os_signpost(.end, log: .preload_assets, name: .preload_assets, signpostID: .preload_assets,
                                            "Preloading assets failed")
                            }
                        })
                    }
                }
            }
        }
    }

    func setLevelLighting(_ node: SCNNode) {
        let light = node.childNode(withName: "LightNode", recursively: true)?.light
        light?.shadowRadius = 3
        light?.shadowSampleCount = 8
    }

    func setupLevel() {
        guard let gameManager = self.gameManager else {
            fatalError("gameManager not initialized")
        }
        
        os_log(.info, "Setting up level")
        
        if gameBoard.anchor == nil {
            let boardSize = CGSize(width: CGFloat(gameBoard.scale.x), height: CGFloat(gameBoard.scale.x * gameBoard.aspectRatio))
            gameBoard.anchor = BoardAnchor(transform: normalize(gameBoard.simdTransform), size: boardSize)
            sceneView.session.add(anchor: gameBoard.anchor!)
        }
        gameBoard.hideBorder()

        os_signpost(.begin, log: .setup_level, name: .setup_level, signpostID: .setup_level,
                    "Setting up Level")

        sessionState = .gameInProgress
        
        GameTime.setLevelStartTime()
        gameManager.start()
        gameManager.addLevel(to: renderRoot, gameBoard: gameBoard)
        gameManager.restWorld()

        if !UserDefaults.standard.disableInGameUI {
            teamBCatapultImages.forEach { $0.isHidden = false }
            teamACatapultImages.forEach { $0.isHidden = false }
        }

        // stop ranging for beacons after placing board
        // 在放置过底座后,停止监听beacons
        if UserDefaults.standard.gameRoomMode {
            proximityManager.stop()
            if let location = proximityManager.closestLocation {
                gameManager.updateSessionLocation(location)
            }
        }

        os_signpost(.end, log: .setup_level, name: .setup_level, signpostID: .setup_level,
                    "Finished Setting Up Level")
    }

    func sendWorldTo(peer: Player) {
        guard let gameManager = gameManager, gameManager.isServer else { os_log(.error, "i'm not the server"); return }

        switch UserDefaults.standard.boardLocatingMode {
        case .worldMap:
            os_log(.info, "generating worldmap for %s", "\(peer)")
            getCurrentWorldMapData { data, error in
                if let error = error {
                    os_log(.error, "didn't work! %s", "\(error)")
                    return
                }
                guard let data = data else { os_log(.error, "no data!"); return }
                os_log(.info, "got a compressed map, sending to %s", "\(peer)")
                let location = GameBoardLocation.worldMapData(data)
                DispatchQueue.main.async {
                    os_log(.info, "sending worldmap to %s", "\(peer)")
                    gameManager.send(boardAction: .boardLocation(location), to: peer)
                }
            }
        case .manual:
            gameManager.send(boardAction: .boardLocation(.manual), to: peer)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        os_log(.info, "segue!")
        guard let segueIdentifier = segue.identifier,
            let segueType = GameSegue(rawValue: segueIdentifier) else {
                os_log(.error, "unknown segue %s", String(describing: segue.identifier))
                return
        }
        
        switch segueType {
        case .embeddedOverlay:
            guard let overlayVC = segue.destination as? GameStartViewController else { return }
            overlayVC.delegate = self
            musicCoordinator.playMusic(name: "music_menu", fadeIn: 0.0)
        default:
            break
        }
    }
    
    func showOverlay() {
        UIView.transition(with: view, duration: 1.0, options: [.transitionCrossDissolve], animations: {
            self.overlayView.isHidden = false
            
            for button in self.inSceneButtons {
                button.isHidden = true
            }
            
            self.instructionLabel.isHidden = true
            
            self.settingsButton.isHidden = true
        }) { _ in
            self.overlayView.isUserInteractionEnabled = true
            UIApplication.shared.isIdleTimerDisabled = false
        }
        musicCoordinator.playMusic(name: "music_menu", fadeIn: 0.5)
    }
    
    func hideOverlay() {
        UIView.transition(with: view, duration: 1.0, options: [.transitionCrossDissolve], animations: {
            self.overlayView.isHidden = true
            
            for button in self.inSceneButtons {
                button.isHidden = false
            }
            
            self.instructionLabel.isHidden = false
            
            self.settingsButton.isHidden = !UserDefaults.standard.showSettingsInGame
        }) { _ in
            self.overlayView.isUserInteractionEnabled = false
            UIApplication.shared.isIdleTimerDisabled = true
        }
        
        musicCoordinator.stopMusic(name: "music_menu", fadeOut: 3)
    }
}

// MARK: - SCNViewDelegate
extension GameViewController: SCNSceneRendererDelegate {
    // This is the ordering of delegate calls
    // https://developer.apple.com/documentation/scenekit/scnscenerendererdelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        os_signpost(.begin, log: .render_loop, name: .render_loop, signpostID: .render_loop,
                    "Render loop started")
        os_signpost(.begin, log: .render_loop, name: .logic_update, signpostID: .render_loop,
                    "Game logic update started")
        
        if let gameManager = self.gameManager, gameManager.isInitialized {
            GameTime.updateAtTime(time: time)
            
            if let pointOfView = sceneView.pointOfView, let level = selectedLevel, level.placed {
                // make a copy of the camera data that other threads can access
                // ARKit has updated the transform right before this
                // 把相机数据复制一份,这样其他线程也能访问该数据.ARKit在此之前已经更新过了transform
                gameManager.copySimulationCamera()
                
                // these can use the pointOfView since the render thread scales/unscales the camera around rendering
                // 这里可以使用pointOfView,因为渲染线程在渲染前后缩小/放大了相机
                let cameraTransform = gameManager.renderSpaceTransformToSimulationSpace(transform: pointOfView.simdTransform)
                let cameraInfo = CameraInfo(transform: cameraTransform)
                
                gameManager.updateCamera(cameraInfo: cameraInfo)
                
                let canGrabCatapult = gameManager.canGrabACatapult(cameraRay: cameraInfo.ray)
                let isGrabbingCatapult = gameManager.isCurrentPlayerGrabbingACatapult()
                
                DispatchQueue.main.async {
                    if self.sessionState == .gameInProgress {
                        if !UserDefaults.standard.hasOnboarded && !UserDefaults.standard.disableInGameUI {
                            if isGrabbingCatapult {
                                self.instructionLabel.text = NSLocalizedString("Release to shoot.", comment: "")
                            } else if canGrabCatapult {
                                self.instructionLabel.text = NSLocalizedString("Tap anywhere and hold to pull back.", comment: "")
                            } else {
                                self.instructionLabel.text = NSLocalizedString("Move closer to a slingshot.", comment: "")
                            }
                        } else {
                            if !self.instructionLabel.isHidden && !self.isSessionInterrupted {
                                self.instructionLabel.isHidden = true
                            }
                        }
                    }
                }
            }

            gameManager.update(timeDelta: GameTime.deltaTime)
        }

        os_signpost(.end, log: .render_loop, name: .logic_update, signpostID: .render_loop,
                    "Game logic update finished")
    }

    func renderer(_ renderer: SCNSceneRenderer, didApplyConstraintsAtTime time: TimeInterval) {
        os_signpost(.begin, log: .render_loop, name: .post_constraints_update, signpostID: .render_loop,
                    "Post constraints update started")
        if let gameManager = gameManager, gameManager.isInitialized {
            // scale up/down the camera to render space
            // 缩小/放大相机到渲染空间
            gameManager.scaleCameraToRender()
            
            // render space from here until scaleCameraToSimulation() is called
            // 渲染空间,从这里直到scaleCameraToSimulation()被调用
            if let pointOfView = sceneView.pointOfView {
                audioListenerNode.simdWorldTransform = pointOfView.simdWorldTransform
            }
            
            // The only functionality currently controlled here is the trail on the projectile.
            // Therefore this part is used to turn on/off show projectile trail
            // 这里控制的功能是是否显示弹道尾迹
            if UserDefaults.standard.showProjectileTrail {
                gameManager.onDidApplyConstraints(renderer: renderer)
            }
        }

       os_signpost(.end, log: .render_loop, name: .post_constraints_update, signpostID: .render_loop,
                   "Post constraints update finished")
    }

    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        os_signpost(.begin, log: .render_loop, name: .render_scene, signpostID: .render_loop,
                    "Rendering scene started")
    }

    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        // update visibility properties in renderloop because we have to scale the physics world down to render properly
        // 更新渲染循环中的可见性属性,因为我们必须缩放物理世界到渲染属性
        if let gameManager = gameManager, gameManager.isInitialized {
        
            // this visibility test is in scaled space, using renderer frustum culling
            // 这个可见性测试是在缩放过的空间的,使用渲染器平头截体剔除
            if let pointOfView = sceneView.pointOfView {
                gameManager.updateCatapultVisibility(renderer: renderer, camera: pointOfView)
            }
            
            // return the pointOfView back from scaled space
            // 从缩放过的空间中返回pointOfView
            gameManager.scaleCameraToSimulation()
        }

        os_signpost(.end, log: .render_loop, name: .render_scene, signpostID: .render_loop,
                    "Rendering scene finished")
        os_signpost(.end, log: .render_loop, name: .render_loop, signpostID: .render_loop,
                    "Render loop finished")
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {

    }
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {

    }
}

// MARK: - ARSessionDelegate
extension GameViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        // Update game board placement in physical world
        // 更新游戏底座在物理世界的位置
        if gameManager != nil {
            // this is main thread calling into init code
            // 主线程调用
            updateGameBoard(frame: frame)
        }
        
        // Update mapping status for saving maps
        // 更新地图状态,以供保存
        updateMappingStatus(frame.worldMappingStatus)
    }
}

// MARK: - GameManagerDelegate
extension GameViewController: GameManagerDelegate {
    func manager(_ manager: GameManager, received boardAction: BoardSetupAction, from player: Player) {
        DispatchQueue.main.async {
            self.process(boardAction: boardAction, from: player)
        }
    }
    
    func manager(_ manager: GameManager, joiningHost host: Player) {
        // host joined the game
        // 主机加入游戏
        DispatchQueue.main.async {
            if self.sessionState == .waitingForBoard {
                manager.send(boardAction: .requestBoardLocation)
            }
            
            guard !UserDefaults.standard.disableInGameUI else { return }
            
            self.notificationLabel.text = "You joined the game!"
            self.notificationLabel.fadeInFadeOut(duration: 1.0)
        }
    }
    
    func manager(_ manager: GameManager, joiningPlayer player: Player) {
        // non-host player joined the game
        // 非主机玩家加入游戏
        guard !UserDefaults.standard.disableInGameUI else { return }
        
        DispatchQueue.main.async {
            self.notificationLabel.text = "\(player.username) joined the game."
            self.notificationLabel.fadeInFadeOut(duration: 1.0)
        }

        // If the gameplay music is already running, start it on the newly
        // connected client.
        // 如果游戏音乐已经在播放,在新接入的客户端上播放.
        if musicCoordinator.currentMusicPlayer?.name == "music_gameplay" {
            let musicTime = musicCoordinator.currentMusicTime()
            os_log(.debug, "music play position = %f", musicTime)
            if musicTime >= 0 {
                manager.startGameMusic(for: player)
            }
        }
    }
    
    func manager(_ manager: GameManager, leavingHost host: Player) {
        // host left the game
        // 主机离开游戏
        guard !UserDefaults.standard.disableInGameUI else { return }
        
        DispatchQueue.main.async {
            // the game can no longer continue
            // 游戏不能再存在了
            self.notificationLabel.text = "The host left the game. Please join another game or start your own!"
            self.notificationLabel.isHidden = false
        }
    }
    
    func manager(_ manager: GameManager, leavingPlayer player: Player) {
        // non-host player left the game
        // 非主机玩家离开游戏
        guard !UserDefaults.standard.disableInGameUI else { return }
        
        DispatchQueue.main.async {
            self.notificationLabel.text = "\(player.username) left the game."
            self.notificationLabel.fadeInFadeOut(duration: 1.0)
        }
    }
    
    func managerDidStartGame(_ manager: GameManager) {
    }
    
    func managerDidWinGame(_ manager: GameManager) {
        musicCoordinator.playMusic(name: "music_win")
    }
    
    func manager(_ manager: GameManager, hasNetworkDelay: Bool) {
        DispatchQueue.main.async {
            if UserDefaults.standard.showNetworkDebug {
                self.networkDelayText.isHidden = !hasNetworkDelay
            }
        }
    }

    func manager(_ manager: GameManager, updated gameState: GameState) {
        DispatchQueue.main.async {
            if self.sessionState == .gameInProgress {
                self.teamACatapultCount = gameState.teamACatapults
                self.teamBCatapultCountTemp = gameState.teamBCatapults
            }
        }
    }
}

// MARK: - GameStartViewControllerDelegate
extension GameViewController: GameStartViewControllerDelegate {
    private func createGameManager(for session: NetworkSession?) {
        let level = UserDefaults.standard.selectedLevel
        selectedLevel = level
        gameManager = GameManager(sceneView: sceneView,
                                  level: level,
                                  session: session,
                                  audioEnvironment: sceneView.audioEnvironmentNode,
                                  musicCoordinator: musicCoordinator)
    }
    
    func gameStartViewControllerSelectedSettings(_ _: UIViewController) {
        performSegue(withIdentifier: GameSegue.showSettings.rawValue, sender: self)
    }

    func gameStartViewController(_ _: UIViewController, didPressStartSoloGameButton: UIButton) {
        hideOverlay()
        createGameManager(for: nil)
    }
    
    func gameStartViewController(_ _: UIViewController, didStart game: NetworkSession) {
        hideOverlay()
        createGameManager(for: game)
    }
    
    func gameStartViewController(_ _: UIViewController, didSelect game: NetworkSession) {
        hideOverlay()
        createGameManager(for: game)
    }
}

