/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Tunes SceneKit camera setup using the entity definitions file.
使用entity定义文件调整SceneKit摄像机设置
*/

import Foundation
import simd
import SceneKit

struct GameCameraProps {
    var hdr = false
    var ambientOcclusion = 0.0
    var motionBlur = 0.0
}

class GameCamera {
    private var props = GameCameraProps()
    private var node: SCNNode
    
    init(_ node: SCNNode) {
        self.node = node
    }
    
    func updateProps() {
        guard let obj = node.gameObject else { return }
        
        // use the props data, or else use the defaults in the struct above
        // 使用道具数据，或者使用上面结构体中的默认值
        if let hdr = obj.propBool("hdr") {
            props.hdr = hdr
        }
        if let motionBlur = obj.propDouble("motionBlur") {
            props.motionBlur = motionBlur
        }
        if let ambientOcclusion = obj.propDouble("ambientOcclusion") {
            props.ambientOcclusion = ambientOcclusion
        }
    }
    
    func transferProps() {
        guard let camera = node.camera else { return }

        // Wide-gamut rendering is enabled by default on supported devices;
        // to opt out, set the SCNDisableWideGamut key in your app's Info.plist file.
        // 默认情况下，在支持的设备上启用宽色域渲染;
        // 要退出，请在应用的Info.plist文件中设置SCNDisableWideGamut键。
        camera.wantsHDR = props.hdr
        
        // Ambient occlusion doesn't work with defaults
        // 环境光遮蔽不适用于默认值
        camera.screenSpaceAmbientOcclusionIntensity = CGFloat(props.ambientOcclusion)
        
        // Motion blur is not supported when wide-gamut color rendering is enabled.
        // 启用宽色域渲染时，不支持运动模糊。
        camera.motionBlurIntensity = CGFloat(props.motionBlur)
    }
}
