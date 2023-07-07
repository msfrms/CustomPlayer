import AVFoundation

final class FastPlayer {
    struct Frames {
        let audio: [CMSampleBuffer]
        let video: [CMSampleBuffer]
    }
    
    private let queue: DispatchQueue
    private let audio: AVSampleBufferAudioRenderer
    private let audioRenderer: SampleBufferRendering
    private var videoRenderer: SampleBufferRendering
    private let synchronizer = AVSampleBufferRenderSynchronizer()
    private var frames = Frames(audio: [], video: [])
    
    private var isPlaying: Bool {
        synchronizer.rate > 0.0
    }
    
    let layer: AVSampleBufferDisplayLayer
    
    @Published
    private(set) var timeInSeconds: Double = 0.0
    
    private var isEmptySync: Bool {
        frames.video.isEmpty && frames.audio.isEmpty
    }
    
    var isEmpty: Bool {
        var isEmpty = false
        queue.sync { [unowned self] in
            isEmpty = self.isEmptySync
        }
        return isEmpty
    }
    
    private var isPreparedToPlay = false
    
    var isMuted: Bool {
        get {
            var isMuted = false
            queue.sync { [unowned self] in
                isMuted = self.audio.isMuted
            }
            return isMuted
        }
        set {
            queue.async { [unowned self] in
                self.audio.isMuted = newValue
            }
        }
    }
    
    init(looping: Bool = true, isMuted: Bool = false) {
        self.queue = DispatchQueue(label: "private.fast.player.queue \(UUID().uuidString)")
        
        let audio = AVSampleBufferAudioRenderer()
        
        audio.isMuted = isMuted
        
        audioRenderer = SampleBufferRendering(renderer: audio)
        
        self.audio = audio
        
        layer = AVSampleBufferDisplayLayer()        
        videoRenderer = SampleBufferRendering(renderer: layer)

        renders.forEach {
            $0.attach(to: synchronizer)
        }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 1000)
        
        synchronizer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 10),
            queue: queue,
            using: { [weak self] time in
                guard let self else {
                    return
                }
                self.timeInSeconds = time.seconds
            }
        )
        
        synchronizer.addPeriodicTimeObserver(
            forInterval: interval,
            queue: queue,
            using: { [weak self] time in
                guard let self else {
                    return
                }
                
                let isEnd = time >= self.frames.lastTimestamp

                guard isEnd else {
                    return
                }

                self.renders.forEach {
                    $0.stopRender()
                    $0.flush()
                }
                
                guard looping else {
                    return
                }
                
                self.audioRenderer.replace(buffers: self.frames.audio)
                self.videoRenderer.replace(buffers: self.frames.video)
                
                self.renders.forEach {
                    $0.render(on: self.queue)
                }
                
                self.synchronizer.setRate(1.0, time: .zero)
            }
        )
    }
    
    func replace(frames: Frames) {
        queue.async { [weak self] in
            guard let self else {
                return
            }
            self.synchronizer.setRate(0.0, time: .zero)
            self.frames = frames
            self.audioRenderer.replace(buffers: frames.audio)
            self.videoRenderer.replace(buffers: frames.video)
            self.prepareToPlaySync()
        }
    }

    private func prepareToPlaySync() {
        layer.flushAndRemoveImage()
        audio.flush()
        videoRenderer.prepareToPlay()
    }
    
    func play() {
        queue.async { [unowned self] in
            guard !self.isEmptySync else {
                return
            }
            
            self.renders.forEach {
                $0.reset()
            }
            self.timeInSeconds = 0.0
            self.synchronizer.setRate(1.0, time: .zero)
        }
        
        renders.forEach {
            $0.render(on: queue)
        }
    }
    
    func seek(at time: CMTime) {
        guard !isEmpty else {
            return
        }
        queue.async { [unowned self] in
            self.renders.forEach {
                $0.seek(at: time)
                $0.render(on: self.queue)
            }
            self.synchronizer.setRate(1.0, time: time)
        }
    }
    
    func pause() {
        guard !isEmpty else {
            return
        }
        queue.async { [unowned self] in
            self.synchronizer.setRate(0.0, time: .zero)
            self.timeInSeconds = 0.0
            self.audioRenderer.flush()
            self.layer.flushAndRemoveImage()
            self.renders.forEach {
                $0.stopRender()
                $0.reset()
            }
        }
    }
    
    func clean() {
        queue.async { [unowned self] in
            guard !self.isPlaying else {
                return
            }
            self.synchronizer.setRate(0.0, time: .zero)
            self.audioRenderer.flush()
            self.layer.flushAndRemoveImage()
            self.renders.forEach {
                $0.clean()
            }
            self.frames = .zero
            self.timeInSeconds = 0.0
        }
    }
}

private extension FastPlayer {
    var renders: [SampleBufferRendering] {
        [audioRenderer, videoRenderer]
    }
}


extension FastPlayer.Frames {
    fileprivate var lastTimestamp: CMTime {
        let lastAudioTimestamp = audio.last?.outputPresentationTimeStamp ?? .zero
        let lastVideoTimestamp = video.last?.outputPresentationTimeStamp ?? .zero
        return max(lastAudioTimestamp, lastVideoTimestamp)
    }
    
    static var zero: Self {
        FastPlayer.Frames(audio: [], video: [])
    }
}
