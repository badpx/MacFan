import Foundation
import IOKit

/// Minimal SMC (System Management Controller) reader.
/// Reads keys such as "FNum" (fan count) and "F0Ac" (fan actual RPM)
/// through the AppleSMC IOKit user client. Works on both Intel and
/// Apple Silicon Macs where the AppleSMC driver is present.
final class SMC {

    // MARK: - SMC protocol structures (packed, matching the kernel ABI)

    typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    struct Version {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    struct LimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    struct KeyData {
        var key: UInt32 = 0
        var vers = Version()
        var pLimitData = LimitData()
        var keyInfo = KeyInfo()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0,
                               0, 0, 0, 0, 0, 0, 0, 0,
                               0, 0, 0, 0, 0, 0, 0, 0,
                               0, 0, 0, 0, 0, 0, 0, 0)
    }

    private let kSMCHandleYPCEvent: UInt32 = 2
    private let kSMCReadKey: UInt8 = 5
    private let kSMCGetKeyInfo: UInt8 = 9

    enum SMCKitError: Error {
        case serviceNotFound
        case openFailed(kern_return_t)
        case keyNotFound
        case readFailed(kern_return_t)
    }

    // MARK: - Connection

    private var connection: io_connect_t = 0

    init() throws {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw SMCKitError.serviceNotFound }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else { throw SMCKitError.openFailed(result) }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    // MARK: - Key helpers

    static func fourCharCode(_ string: String) -> UInt32 {
        var code: UInt32 = 0
        for scalar in string.unicodeScalars.prefix(4) {
            code = (code << 8) | (scalar.value & 0xFF)
        }
        return code
    }

    private func callSMC(_ input: inout KeyData) throws -> KeyData {
        var output = KeyData()
        var outputSize = MemoryLayout<KeyData>.stride
        let inputSize = MemoryLayout<KeyData>.stride

        let result = IOConnectCallStructMethod(connection,
                                               kSMCHandleYPCEvent,
                                               &input,
                                               inputSize,
                                               &output,
                                               &outputSize)
        guard result == kIOReturnSuccess, output.result == 0 else {
            throw SMCKitError.readFailed(result)
        }
        return output
    }

    /// Reads raw bytes + type info for a key.
    func readKey(_ key: String) throws -> (bytes: [UInt8], type: String, size: Int) {
        var input = KeyData()
        input.key = SMC.fourCharCode(key)
        input.data8 = kSMCGetKeyInfo

        let info: KeyData
        do {
            info = try callSMC(&input)
        } catch {
            throw SMCKitError.keyNotFound
        }

        var readInput = KeyData()
        readInput.key = SMC.fourCharCode(key)
        readInput.keyInfo.dataSize = info.keyInfo.dataSize
        readInput.data8 = kSMCReadKey

        let output = try callSMC(&readInput)

        var typeCode = info.keyInfo.dataType
        var typeChars = [Character]()
        for _ in 0..<4 {
            typeChars.insert(Character(UnicodeScalar(typeCode & 0xFF) ?? " "), at: 0)
            typeCode >>= 8
        }

        let size = Int(info.keyInfo.dataSize)
        var bytes = [UInt8]()
        withUnsafeBytes(of: output.bytes) { raw in
            bytes = Array(raw.prefix(size))
        }
        return (bytes, String(typeChars), size)
    }

    // MARK: - Typed readers

    /// Decodes an SMC numeric value. Supports "flt " (Float32), "fpe2"/"sp78"
    /// (fixed point) and "ui8"/"ui16" integer formats.
    ///
    /// "flt " byte order differs by platform (little-endian on Apple Silicon,
    /// big-endian on older Intel SMCs). A float read with the wrong order
    /// lands in the denormal range (~1e-38), so decode natively first and
    /// fall back to the byte-swapped reading when the result is denormal.
    private func decodeNumber(bytes: [UInt8], type: String) -> Double? {
        switch type {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let native = bytes.withUnsafeBytes { $0.load(as: UInt32.self) }
            let value = Float(bitPattern: native)
            if value == 0 { return 0 }
            if abs(value) < 1e-30 {
                return Double(Float(bitPattern: native.byteSwapped))
            }
            return Double(value)
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            let raw = (Int(bytes[0]) << 8) | Int(bytes[1])
            return Double(raw) / 4.0
        case "ui8 ":
            return bytes.first.map { Double($0) }
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw = (Int(bytes[0]) << 8) | Int(bytes[1])
            return Double(raw) / 256.0
        default:
            return nil
        }
    }

    func readNumber(_ key: String) -> Double? {
        guard let value = try? readKey(key) else { return nil }
        return decodeNumber(bytes: value.bytes, type: value.type)
    }

    // MARK: - Convenience

    func fanCount() -> Int {
        Int(readNumber("FNum") ?? 0)
    }

    /// Actual RPM of fan `index`, or nil when unavailable.
    func fanRPM(_ index: Int) -> Double? {
        readNumber(String(format: "F%dAc", index))
    }

    /// Temperature for a given SMC key (Intel Macs mainly), e.g. "TC0P".
    func temperature(_ key: String) -> Double? {
        readNumber(key)
    }
}
