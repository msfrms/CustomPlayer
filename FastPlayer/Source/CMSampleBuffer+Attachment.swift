import AVFoundation

extension CMSampleBuffer {
    typealias Key = CMSampleBuffer.PerSampleAttachmentsDictionary.Key

    func setAttachmentValue(for key: Key, value: Bool) {
        guard
            let attachments: CFArray = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true), 0 < CFArrayGetCount(attachments) else {
            return
        }
        let attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        CFDictionarySetValue(
            attachment,
            Unmanaged.passUnretained(key.rawValue).toOpaque(),
            Unmanaged.passUnretained(value ? kCFBooleanTrue : kCFBooleanFalse).toOpaque()
        )
    }
    
    func attachmentValue<T>(for key: Key) -> T? {
        guard
            let attachments: CFArray = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true), 0 < CFArrayGetCount(attachments) else {
            return nil
        }
        
        let attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        
        guard let dict = attachment as? [Key: AnyObject] else {
            return nil
        }
        
        return dict[key] as? T
    }
}
