//: MetalPlay: A chance to quickly explore how Metal works on macOS.

import Cocoa
import Metal
import PlaygroundSupport

// a few of these commands require a try/catch, so we'll wrap the entire process.
do {

    // STEP 1: get the device
    let device = MTLCreateSystemDefaultDevice()

    // STEP 2: create data & buffer for data source
    let vertexData: [Float] = [
        0.0,1.0,0.0,
        -1.0,-1.0,0.0,
        1.0,-1.0,0.0
    ]
    let dataSize = vertexData.count * MemoryLayout.stride(ofValue: vertexData[0]) // use stride instead of size, as this properly reflects memory usage.
    let vertexArray = device?.makeBuffer(bytes: vertexData, length: dataSize, options: [])
    
    // STEP 3: create render pipeline
    
    // vertex layout descriptor
    let descriptor = MTLRenderPipelineDescriptor()

    // create a shader library in source (not precompiled)
    let runtimeLibrary = try device?.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;

        vertex float4 copy_vertex(
            const device packed_float3* vertex_array [[buffer(0)]],
                                     unsigned int vid [[vertex_id]]) {
            return float4(vertex_array[vid], 1.0);
        }

        fragment half4 constant_color() {
            return half4(0.75,0.95,0.35,1.0);
        }
    """, options: nil)

    // vertex & fragment shader
    descriptor.vertexFunction = runtimeLibrary?.makeFunction(name: "copy_vertex")
    descriptor.fragmentFunction = runtimeLibrary?.makeFunction(name: "constant_color")

    // framebuffer format
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    // compile to MTLPRenderPipelineState
    let renderPipeline = try device?.makeRenderPipelineState(descriptor: descriptor)

    // INTERMISSION: create an NSView, with a metal layer as its backing layer.
    let metalLayer = CAMetalLayer()
    metalLayer.device = device
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
    view.layer = metalLayer
    PlaygroundPage.current.liveView = view

    // STEP 4: prepare our command buffer and drawable
    let commandQueue = device?.makeCommandQueue()
    let buffer = commandQueue?.makeCommandBuffer()
    let drawable = metalLayer.nextDrawable()
    
    // create the render pass descriptor
    let rpDesc = MTLRenderPassDescriptor()
    rpDesc.colorAttachments[0].texture = drawable?.texture
    rpDesc.colorAttachments[0].loadAction = .clear
    rpDesc.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0)
    
    // STEP 5: create a buffer of actual render commands
    let encoder = buffer?.makeRenderCommandEncoder(descriptor: rpDesc)
    encoder?.setRenderPipelineState(renderPipeline!)
    encoder?.setVertexBuffer(vertexArray, offset: 0, index: 0)
    encoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder?.endEncoding()
    
    // show the buffer.
    if let drawable = drawable {
        buffer?.present(drawable)
        buffer?.commit()
    }


} catch {
    print(error)
}
