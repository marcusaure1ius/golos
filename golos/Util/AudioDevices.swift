import CoreAudio
import Foundation

enum AudioDevices {
    /// Returns a list of input audio devices as (uid, name) pairs.
    /// Returns an empty array if enumeration fails.
    static func list() -> [(uid: String, name: String)] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                             &address, 0, nil, &dataSize) == noErr,
              dataSize > 0 else {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return []
        }

        var results: [(uid: String, name: String)] = []

        for deviceID in deviceIDs {
            // Check if this device has input streams
            var streamsAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamsSize: UInt32 = 0
            let streamsErr = AudioObjectGetPropertyDataSize(deviceID, &streamsAddress, 0, nil, &streamsSize)
            guard streamsErr == noErr, streamsSize > 0 else { continue }

            // Get device UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uidRef: CFString? = nil
            var uidSize = UInt32(MemoryLayout<CFString?>.size)
            guard AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uidRef) == noErr,
                  let uid = uidRef as String? else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameRef: CFString? = nil
            var nameSize = UInt32(MemoryLayout<CFString?>.size)
            guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &nameRef) == noErr,
                  let name = nameRef as String? else { continue }

            results.append((uid: uid, name: name))
        }

        return results
    }

    /// Looks up an AudioDeviceID for a given UID string. Returns nil if not found.
    static func audioDeviceID(forUid uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var translation = AudioValueTranslation(
            mInputData: Unmanaged.passRetained(uid as CFString).autorelease().toOpaque(),
            mInputDataSize: UInt32(MemoryLayout<CFString>.size),
            mOutputData: UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<AudioDeviceID>.size, alignment: MemoryLayout<AudioDeviceID>.alignment),
            mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        defer { translation.mOutputData.deallocate() }
        var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
        let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                              &address, 0, nil, &size, &translation)
        guard err == noErr else { return nil }
        let deviceID = translation.mOutputData.load(as: AudioDeviceID.self)
        return deviceID == kAudioDeviceUnknown ? nil : deviceID
    }
}
