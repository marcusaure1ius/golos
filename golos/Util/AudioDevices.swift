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

            // Пропускаем служебные устройства, которые не являются реальными микрофонами:
            // macOS создаёт скрытый агрегат `CADefaultDeviceAggregate-…` при включении
            // Voice Processing (шумоподавления). Фильтруем по имени/uid и по transport type.
            if name.hasPrefix("CADefaultDeviceAggregate") || uid.hasPrefix("CADefaultDeviceAggregate") {
                continue
            }
            var transportAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transport: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(deviceID, &transportAddress, 0, nil, &transportSize, &transport) == noErr,
               transport == kAudioDeviceTransportTypeAggregate {
                continue
            }

            results.append((uid: uid, name: name))
        }

        return results
    }

    /// Looks up an AudioDeviceID for a given UID string. Returns nil if not found.
    /// Enumerates all devices and compares UIDs — the AudioValueTranslation-based
    /// kAudioHardwarePropertyDeviceForUID pattern is unreliable from Swift (CoreAudio
    /// dereferences the input CFString in a way that crashes on Unmanaged.toOpaque pointers).
    static func audioDeviceID(forUid uid: String) -> AudioDeviceID? {
        guard !uid.isEmpty else { return nil }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                             &address, 0, nil, &dataSize) == noErr,
              dataSize > 0 else { return nil }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &dataSize, &ids) == noErr else {
            return nil
        }

        for id in ids {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uidRef: CFString? = nil
            var uidSize = UInt32(MemoryLayout<CFString?>.size)
            guard AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &uidSize, &uidRef) == noErr,
                  let candidate = uidRef as String? else { continue }
            if candidate == uid { return id }
        }
        return nil
    }
}
