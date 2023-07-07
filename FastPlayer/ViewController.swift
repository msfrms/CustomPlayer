import UIKit
import AVFoundation

class ViewController: UIViewController {
    typealias Decoding = AVAssetReader.Response.Decoding
    
    private let videoLayer = AVSampleBufferDisplayLayer()
    private var decoding = Decoding(video: [], audio: [])
    private let player = FastPlayer(looping: true, isMuted: false)
    
    func prepareToPlay() async throws {
        let path = Bundle.main.url(forResource: "SaveInsta.App - 2967460557389172716", withExtension: "mp4")!
        let asset = AVURLAsset(url: path)
        let reader = try AVAssetReader(asset: asset)
        let result = try await reader.decode()
        switch result {
        case let .completed(decoding):
            self.decoding = decoding
        case .cancelled:
            print("cancelled decode")
        case .failed:
            print("failed decode")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layer.addSublayer(player.layer)
        player.layer.frame = view.bounds
        player.layer.backgroundColor = UIColor.black.cgColor
        
        Task {
            try await self.prepareToPlay()
            self.player.replace(
                frames: FastPlayer.Frames(
                    audio: self.decoding.audio,
                    video: self.decoding.video
                )
            )
            self.player.play()
        }
    }
}
