import AVFoundation

extension AVAssetReader {
    enum Response {
        struct Decoding {
            let video: [CMSampleBuffer]
            let audio: [CMSampleBuffer]
        }
        case completed(Decoding)
        case failed
        case cancelled
    }
    
    func decode() async throws -> Response {
        let audioTrack = try await self.asset.loadTracks(withMediaType: .audio).first
        let videoTrack = try await self.asset.loadTracks(withMediaType: .video).first
        
        return try await withCheckedThrowingContinuation { continuation in
            
            let audioOutput = audioTrack.map {
                AVAssetReaderTrackOutput(
                    track: $0,
                    outputSettings: nil
                )
            }
            
            let videoOutput = videoTrack.map {
                AVAssetReaderTrackOutput(
                    track: $0,
                    outputSettings: nil
                )
            }
            
            audioOutput.map(add(_:))
            videoOutput.map(add(_:))
            
            startReading()
            
            var audioSampleBuffers: [CMSampleBuffer] = []
            var videoSampleBuffers: [CMSampleBuffer] = []
            
            while status == .reading {
                guard !Task.isCancelled else {
                    cancelReading()
                    return continuation.resume(returning: .cancelled)
                }
                
                audioOutput?.copyNextSampleBuffer().map {
                    audioSampleBuffers.append($0)
                }
                videoOutput?.copyNextSampleBuffer().map {
                    videoSampleBuffers.append($0)
                }
            }
            
            let filePath = (self.asset as? AVURLAsset)?.url
            
            switch status {
            case .cancelled:
                print("reader cancelled for path: \(filePath?.absoluteString ?? "")")
                continuation.resume(with: .success(Response.cancelled))
                
            case .failed, .reading, .unknown:
                print("reader failed for path: \(filePath?.absoluteString ?? "")")
                continuation.resume(with: .success(Response.failed))
                
            case .completed:
                print("reader completed decoding for path: \(filePath?.absoluteString ?? "")")
                continuation.resume(
                    with: .success(
                        Response.completed(
                            Response.Decoding(
                                video: videoSampleBuffers,
                                audio: audioSampleBuffers
                            )
                        )
                    )
                )
            @unknown default:
                fatalError()
            }
        }
    }
}
