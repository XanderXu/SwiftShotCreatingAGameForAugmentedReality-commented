/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Tunes SceneKit lighting/shadows using the entity definitions file.
 使用entity定义文件调整SceneKit摄像机光照/阴影
*/

import Foundation
import simd
import SceneKit
import os.log

struct GameLightProps {
    var shadowMapSize = float2(2048, 4096)
    var angles = float3(-90, 0, 0)
    var shadowMode: Int = 0
}

class GameLight {
    private var props = GameLightProps()
    private var node: SCNNode
    
    init(_ node: SCNNode) {
        self.node = node
    }
    
    func updateProps() {
        
        guard let obj = node.gameObject else { return }
        
        // use the props data, or else use the defaults in the struct above
        // 使用道具数据，或者使用上面结构体中的默认值
        if let shadowMapSize = obj.propFloat2("shadowMapSize") {
            props.shadowMapSize = shadowMapSize
        }
        if let angles = obj.propFloat3("angles") {
            let toRadians = Float.pi / 180.0
            props.angles = angles * toRadians
        }
        if let shadowMode = obj.propInt("shadowMode") {
            props.shadowMode = shadowMode
        }
    }
    
    func transferProps() {
        // are euler's set at refeference (ShadowLight) or internal node (LightNode)
        // 欧拉角设置，相对于参考节点(ShadowLight)或内部节点(LightNode)
        let lightNode = node.childNode(withName: "LightNode", recursively: true)!
        let light = lightNode.light!
    
        // As shadow map size is reduced get a softer shadow but more acne
        // and bias results in shadow offset.  Mostly thin geometry like the boxes
        // and the shadow plane have acne.  Turn off z-writes on the shadow plane.
        // 随着阴影贴图尺寸的减小，阴影会更柔和，但更多的毛刺和偏差导致阴影偏移。一般瘦几何体比如立方体和阴影平面会有毛刺。关闭阴影平面的 z-write。
        switch props.shadowMode {
        case 0:
            // activate special filtering mode with 16 sample fixed pattern
            // this slows down the rendering by 2x
            // 启用特殊过滤模式为 16 倍固定模式采样
            // 这会导致渲染速度变慢 2x
            light.shadowRadius = 0
            light.shadowSampleCount = 16
            
        case 1:
            light.shadowRadius = 3 // 2.5
            light.shadowSampleCount = 8
        
        case 2:
            // as resolution decreases more acne, use bias and cutoff in shadowPlane shaderModifier
            // 因为分辨率会降低阴影，在shadowPlane shaderModifier中使用偏差和截断
            light.shadowRadius = 1
            light.shadowSampleCount = 1
            
        default:
            os_log(.error, "unknown shadow mode")
        }
        
        // when true, this reduces acne, but is causing shadow to separate
        // not seeing much acne, so turn it off for now
        // 当是 true 时，这项为减少毛刺，但会导致阴影分离
        // 当前没有很多毛刺，所以先关闭它
        light.forcesBackFaceCasters = false
        
        light.shadowMapSize = CGSize(width: CGFloat(props.shadowMapSize.x),
                                     height: CGFloat(props.shadowMapSize.y))
        
        // Can turn on cascades with auto-adjust disabled here, but not in editor.
        // Based on shadowDistance where next cascade starts.  These are the defaults.
        // 可以在这里打开cascades设置为禁用自动调整，不要在编辑器界面中处理
        // 基于shadowDistance，开始下一个cascade。这些是默认值。
        // light.shadowCascadeCount = 2
        // light.shadowCascadeSplittingFactor = 0.15
        
        // this is a square volume that is mapped to the shadowMapSize
        // may need to adjust this based on the angle of the light and table size
        // setting angles won't work until we isolate angles in the level file to a single node
        // 这是一个映射到shadowMapSize的方形体积
        // 可能需要根据灯光和工作台尺寸的角度进行调整
        // 在我们将关卡文件中的角度设置为单独节点之前，设置角度是不起作用的
        // lightNode.parent.angles = prop.angles
        light.orthographicScale = 15.0
        light.zNear = 1.0
        light.zFar = 30.0
    }
}

