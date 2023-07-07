import AVFoundation

final class SampleBufferRendering {
    private let renderer: AVQueuedSampleBufferRendering
    private var buffers: [CMSampleBuffer] = []
    private var bufferIndex = 0
    
    init(renderer: AVQueuedSampleBufferRendering) {
        self.renderer = renderer
    }
    
    func replace(buffers: [CMSampleBuffer]) {
        stopRender()
        self.buffers = buffers
        self.bufferIndex = 0
    }
    
    func reset() {
        self.bufferIndex = 0
    }
    
    func prepareToPlay() {
        let buffers = self.buffers.prefix(5)
        for buffer in buffers {
            buffer.setAttachmentValue(for: .doNotDisplay, value: true)
            renderer.enqueue(buffer)
        }
    }
    
    func clean() {
        replace(buffers: [])
    }
    
    func render(on queue: DispatchQueue) {
        renderer.requestMediaDataWhenReady(on: queue) { [weak self] in
            guard let self else {
                return
            }

            while self.renderer.isReadyForMoreMediaData {
                guard self.buffers.indices.contains(self.bufferIndex) else {
                    return
                }
                let frame = self.buffers[self.bufferIndex]
                
                frame.setAttachmentValue(for: .doNotDisplay, value: false)
                
                self.renderer.enqueue(frame)
                self.bufferIndex += 1
            }
        }
    }
    
    func seek(at time: CMTime) {
        let indexOfBuffer = self.buffers.firstIndex {
            $0.presentationTimeStamp >= time
        }
        
        guard let index = indexOfBuffer?.advanced(by: 0) else {
            return
        }
        
        self.bufferIndex = index
    }
    
    func stopRender() {
        renderer.stopRequestingMediaData()
    }
    
    func flush() {
        renderer.flush()
    }
    
    func attach(to synchronizer: AVSampleBufferRenderSynchronizer) {
        synchronizer.addRenderer(renderer)
    }
}
