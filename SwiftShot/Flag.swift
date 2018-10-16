/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Flag simulation Metal compute wrapper.
旗帜模拟计算的包装。
*/

// References to Metal do not compile for the Simulator.
#if !targetEnvironment(simulator)
import Foundation
import Metal
import SceneKit

struct SimulationData {
    var wind: float3
    var pad1: Float = 0
    
    init(wind: float3) {
        self.wind = wind
    }
}

struct ClothData {
    var clothNode: SCNNode
    var meshData: ClothSimMetalNode
    
    init(clothNode: SCNNode, meshData: ClothSimMetalNode) {
        self.clothNode = clothNode
        self.meshData = meshData
    }
}

class ClothSimMetalNode {
    let geometry: SCNGeometry
    
    let vb1: MTLBuffer
    let vb2: MTLBuffer
    let normalBuffer: MTLBuffer
    let normalWorkBuffer: MTLBuffer
    let vertexCount: Int
    
    var velocityBuffers = [MTLBuffer]()
    
    var currentBufferIndex: Int = 0
    
    init(device: MTLDevice, width: uint, height: uint) {
        var vertices: [float3] = []
        var normals: [float3] = []
        var uvs: [float2] = []
        var indices: [UInt32] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let p = float3(Float(x), 0, Float(y))
                vertices.append(p)
                normals.append(float3(0, 1, 0))
                uvs.append(float2(p.x / Float(width), p.z / Float(height)))
            }
        }
        
        // 创建索引
        for y in 0..<(height - 1) {
            for x in 0..<(width - 1) {
                // make 2 triangles from the 4 vertices of a quad
                // 从四边形的 4 个顶点，构造出 2 个三角形。（i0是坐标(x,y)处的索引，i1 是右侧索引，i2 是下方点的索引，i3 是右下方的索引）
                let i0 = y * width + x
                let i1 = i0 + 1
                let i2 = i0 + width
                let i3 = i2 + 1
                
                // triangle 1
                indices.append(i0)
                indices.append(i2)
                indices.append(i3)
                
                // triangle 2
                indices.append(i0)
                indices.append(i3)
                indices.append(i1)
            }
        }
        // 顶点 Buffer 和顶点 GeometrySource，vertexBuffer2暂时为空
        let vertexBuffer1 = device.makeBuffer(bytes: vertices,
                                              length: vertices.count * MemoryLayout<float3>.size,
                                              options: [.cpuCacheModeWriteCombined])
        
        let vertexBuffer2 = device.makeBuffer(length: vertices.count * MemoryLayout<float3>.size,
                                              options: [.cpuCacheModeWriteCombined])
        
        let vertexSource = SCNGeometrySource(buffer: vertexBuffer1!,
                                             vertexFormat: .float3,
                                             semantic: .vertex,
                                             vertexCount: vertices.count,
                                             dataOffset: 0,
                                             dataStride: MemoryLayout<float3>.size)
        
        // 法线 Buffer 和法线 GeometrySource，normalWorkBuffer暂时为空
        let normalBuffer = device.makeBuffer(bytes: normals,
                                             length: normals.count * MemoryLayout<float3>.size,
                                             options: [.cpuCacheModeWriteCombined])
        
        let normalWorkBuffer = device.makeBuffer(length: normals.count * MemoryLayout<float3>.size,
                                                 options: [.cpuCacheModeWriteCombined])
        
        let normalSource = SCNGeometrySource(buffer: normalBuffer!,
                                             vertexFormat: .float3,
                                             semantic: .normal,
                                             vertexCount: normals.count,
                                             dataOffset: 0,
                                             dataStride: MemoryLayout<float3>.size)
        // uv贴图 Buffer 和uv贴图 GeometrySource
        let uvBuffer = device.makeBuffer(bytes: uvs,
                                         length: uvs.count * MemoryLayout<float2>.size,
                                         options: [.cpuCacheModeWriteCombined])
        
        let uvSource = SCNGeometrySource(buffer: uvBuffer!,
                                         vertexFormat: .float2,
                                         semantic: .texcoord,
                                         vertexCount: uvs.count,
                                         dataOffset: 0,
                                         dataStride: MemoryLayout<float2>.size)
        
        // 根据索引，及以上三种GeometrySource，创建几何体
        let indexElement = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [vertexSource, normalSource, uvSource], elements: [indexElement])
        
        // velocity buffers
        // 速度 buffer，暂时都为空
        let velocityBuffer1 = device.makeBuffer(length: vertices.count * MemoryLayout<float3>.size,
                                                options: [.cpuCacheModeWriteCombined])
        
        let velocityBuffer2 = device.makeBuffer(length: vertices.count * MemoryLayout<float3>.size,
                                                options: [.cpuCacheModeWriteCombined])
        // 保存
        self.geometry = geo
        self.vertexCount = vertices.count
        self.vb1 = vertexBuffer1!
        self.vb2 = vertexBuffer2!
        self.normalBuffer = normalBuffer!
        self.normalWorkBuffer = normalWorkBuffer!
        self.velocityBuffers = [velocityBuffer1!, velocityBuffer2!]
    }
}

/*
 Encapsulate the 'Metal stuff' within a single class to handle setup and execution
 of the compute shaders.
 将'Metal stuff'封装在一个类中以处理设置和执行计算着色器。
 */
class MetalClothSimulator {
    let device: MTLDevice
    
    let commandQueue: MTLCommandQueue
    let defaultLibrary: MTLLibrary
    let functionClothSim: MTLFunction
    let functionNormalUpdate: MTLFunction
    let functionNormalSmooth: MTLFunction
    let pipelineStateClothSim: MTLComputePipelineState
    let pipelineStateNormalUpdate: MTLComputePipelineState
    let pipelineStateNormalSmooth: MTLComputePipelineState

    let width: uint = 32
    let height: uint = 20
    
    var clothData = [ClothData]()
    
    init(device: MTLDevice) {
        self.device = device
        
        commandQueue = device.makeCommandQueue()!
        
        // 读取加载 Flag.metal 中的三个着色器
        defaultLibrary = device.makeDefaultLibrary()!
        functionClothSim = defaultLibrary.makeFunction(name: "updateVertex")!
        functionNormalUpdate = defaultLibrary.makeFunction(name: "updateNormal")!
        functionNormalSmooth = defaultLibrary.makeFunction(name: "smoothNormal")!

        // 创建计算管线
        do {
            pipelineStateClothSim = try device.makeComputePipelineState(function: functionClothSim)
            pipelineStateNormalUpdate = try device.makeComputePipelineState(function: functionNormalUpdate)
            pipelineStateNormalSmooth = try device.makeComputePipelineState(function: functionNormalSmooth)
        } catch {
            fatalError("\(error)")
        }
    }
    /// 从一个 Node 创建旗帜模拟
    func createFlagSimulationFromNode(_ node: SCNNode) {
        // 创建指定尺寸的风格数据，并构建成 clothNode
        let meshData = ClothSimMetalNode(device: device, width: width, height: height)
        let clothNode = SCNNode(geometry: meshData.geometry)
        
        guard let flag = node.childNode(withName: "flagStaticWave", recursively: true) else { return }
        
        // 处理缩放和旋转，材质
        let boundingBox = flag.simdBoundingBox
        let existingFlagBV = boundingBox.max - boundingBox.min
        let rescaleToMatchSizeMatrix = float4x4(scale: existingFlagBV.x / Float(width))
        
        let rotation = simd_quatf(angle: .pi / 2, axis: float3(1, 0, 0))
        let localTransform = rescaleToMatchSizeMatrix * float4x4(rotation)
        
        clothNode.simdTransform = flag.simdTransform * localTransform
        
        clothNode.geometry?.firstMaterial = flag.geometry?.firstMaterial
        clothNode.geometry?.firstMaterial?.isDoubleSided = true

        // 将 flag 节点替换为 clothNode
        flag.parent?.replaceChildNode(flag, with: clothNode)
        
        // 设置材质，颜色，并修复法线贴图
        clothNode.setupPaintColorMask(clothNode.geometry!, name: "flag_flagA")//内部通过一个 shader 实现
        clothNode.setPaintColors()
        clothNode.fixNormalMaps()
        
        clothData.append( ClothData(clothNode: clothNode, meshData: meshData) )
    }
    
    // 更新，计算风的效果
    func update(_ node: SCNNode) {
       
        for cloth in clothData {
            let wind = float3(1.8, 0.0, 0.0)
            
            // The multiplier is to rescale ball to flag model space.
            // The correct value should be passed in.
            // 这个乘数的作用是将小球重缩放到旗帜模型空间。应传入正确的值。
            let simData = SimulationData(wind: wind)
            
            deform(cloth.meshData, simData: simData)
        }
    }

    // 将数值传入给管线对应的 shader 中
    func deform(_ mesh: ClothSimMetalNode, simData: SimulationData) {
        var simData = simData
        
        // 设置布料模拟的管线状态
        let w = pipelineStateClothSim.threadExecutionWidth
        let threadsPerThreadgroup = MTLSizeMake(w, 1, 1)
        
        let threadgroupsPerGrid = MTLSize(width: (mesh.vertexCount + w - 1) / w,
                                          height: 1,
                                          depth: 1)
        
        let clothSimCommandBuffer = commandQueue.makeCommandBuffer()
        let clothSimCommandEncoder = clothSimCommandBuffer?.makeComputeCommandEncoder()
        
        clothSimCommandEncoder?.setComputePipelineState(pipelineStateClothSim)
        
        
        // 设置各种 buffer
        clothSimCommandEncoder?.setBuffer(mesh.vb1, offset: 0, index: 0)
        clothSimCommandEncoder?.setBuffer(mesh.vb2, offset: 0, index: 1)
        clothSimCommandEncoder?.setBuffer(mesh.velocityBuffers[mesh.currentBufferIndex], offset: 0, index: 2)
        mesh.currentBufferIndex = (mesh.currentBufferIndex + 1) % 2
        clothSimCommandEncoder?.setBuffer(mesh.velocityBuffers[mesh.currentBufferIndex], offset: 0, index: 3)
        clothSimCommandEncoder?.setBytes(&simData, length: MemoryLayout<SimulationData>.size, index: 4)
        // 线程
        clothSimCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        // 提交
        clothSimCommandEncoder?.endEncoding()
        clothSimCommandBuffer?.commit()
        
        
        // 同上，设置法线的计算管线
        
        let normalComputeCommandBuffer = commandQueue.makeCommandBuffer()
        let normalComputeCommandEncoder = normalComputeCommandBuffer?.makeComputeCommandEncoder()
        
        normalComputeCommandEncoder?.setComputePipelineState(pipelineStateNormalUpdate)
        normalComputeCommandEncoder?.setBuffer(mesh.vb2, offset: 0, index: 0)
        normalComputeCommandEncoder?.setBuffer(mesh.vb1, offset: 0, index: 1)
        normalComputeCommandEncoder?.setBuffer(mesh.normalWorkBuffer, offset: 0, index: 2)
        normalComputeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        normalComputeCommandEncoder?.endEncoding()
        normalComputeCommandBuffer?.commit()

        //同上，设置平滑过的法线计算管线
        
        let normalSmoothComputeCommandBuffer = commandQueue.makeCommandBuffer()
        let normalSmoothComputeCommandEncoder = normalSmoothComputeCommandBuffer?.makeComputeCommandEncoder()
        
        normalSmoothComputeCommandEncoder?.setComputePipelineState(pipelineStateNormalSmooth)
        normalSmoothComputeCommandEncoder?.setBuffer(mesh.normalWorkBuffer, offset: 0, index: 0)
        normalSmoothComputeCommandEncoder?.setBuffer(mesh.normalBuffer, offset: 0, index: 1)
        normalSmoothComputeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

        normalSmoothComputeCommandEncoder?.endEncoding()
        normalSmoothComputeCommandBuffer?.commit()
    }
}
#endif

