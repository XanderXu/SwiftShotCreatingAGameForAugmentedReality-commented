/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Custom anchor for saving camera screenshots in an ARWorldMap.
自定义锚点，用于保存相机截屏
*/

import ARKit

class KeyPositionAnchor: ARAnchor {
    let image: UIImage
    let mappingStatus: ARFrame.WorldMappingStatus
    
    init(image: UIImage, transform: float4x4, mappingStatus: ARFrame.WorldMappingStatus) {
        self.image = image
        self.mappingStatus = mappingStatus
        super.init(name: "KeyPosition", transform: transform)
    }
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    required init?(coder aDecoder: NSCoder) {
        if let image = aDecoder.decodeObject(of: UIImage.self, forKey: "image") {
            self.image = image
            let mappingValue = aDecoder.decodeInteger(forKey: "mappingStatus")
            self.mappingStatus = ARFrame.WorldMappingStatus(rawValue: mappingValue) ?? .notAvailable
        } else {
            return nil
        }
        super.init(coder: aDecoder)
    }

    // this is guaranteed to be called with something of the same class
    // 确保该类及子类会调用这个方法
    required init(anchor: ARAnchor) {
        let other = anchor as! KeyPositionAnchor
        self.image = other.image
        self.mappingStatus = other.mappingStatus
        super.init(anchor: other)
    }

    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(image, forKey: "image")
        aCoder.encode(mappingStatus.rawValue, forKey: "mappingStatus")
    }
}
