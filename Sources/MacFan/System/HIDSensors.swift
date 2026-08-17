import Foundation
import IOKit

/// Reads temperature sensors on Apple Silicon Macs through the private
/// IOHIDEventSystem API (symbols are exported by IOKit but absent from the
/// public SDK headers, so they are resolved with dlopen/dlsym).
/// No elevated privileges required.
final class HIDSensors {

    // Apple HID sensor usage page / usage for temperature events.
    private let kHIDPageAppleVendor: Int = 0xFF00
    private let kHIDUsageAppleVendorTemperatureSensor: Int = 0x0005
    private let kIOHIDEventTypeTemperature: Int64 = 15
    private let kIOHIDEventFieldTemperatureLevel: Int32 = 15 << 16

    // Resolved private symbols.
    private let createClient: (@convention(c) (CFAllocator?) -> Unmanaged<CFTypeRef>?)?
    private let copyServices: (@convention(c) (CFTypeRef) -> Unmanaged<CFArray>?)?
    private let copyEvent: (@convention(c) (CFTypeRef, Int64, Int32, Int32) -> Unmanaged<CFTypeRef>?)?
    private let eventFloatValue: (@convention(c) (CFTypeRef, Int32) -> Double)?
    private let copyProperty: (@convention(c) (CFTypeRef, CFString) -> Unmanaged<CFTypeRef>?)?

    init?() {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",
                                  RTLD_LAZY) else { return nil }

        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let pointer = dlsym(handle, name) else { return nil }
            return unsafeBitCast(pointer, to: T.self)
        }

        guard let create = symbol("IOHIDEventSystemClientCreate",
                                  as: (@convention(c) (CFAllocator?) -> Unmanaged<CFTypeRef>?)?.self),
              let services = symbol("IOHIDEventSystemClientCopyServices",
                                    as: (@convention(c) (CFTypeRef) -> Unmanaged<CFArray>?)?.self),
              let event = symbol("IOHIDServiceClientCopyEvent",
                                 as: (@convention(c) (CFTypeRef, Int64, Int32, Int32) -> Unmanaged<CFTypeRef>?)?.self),
              let floatValue = symbol("IOHIDEventGetFloatValue",
                                      as: (@convention(c) (CFTypeRef, Int32) -> Double)?.self) else {
            dlclose(handle)
            return nil
        }

        self.createClient = create
        self.copyServices = services
        self.copyEvent = event
        self.eventFloatValue = floatValue
        self.copyProperty = symbol("IOHIDServiceClientCopyProperty",
                                   as: (@convention(c) (CFTypeRef, CFString) -> Unmanaged<CFTypeRef>?)?.self) ?? nil
    }

    /// Returns the current readings (in °C) of all HID temperature sensors,
    /// e.g. "pACC MTR Temp Sensor0", "gas gauge battery", PMU sensors...
    func temperatureReadings() -> [(name: String, value: Double)] {
        guard let createClient, let copyServices, let copyEvent, let eventFloatValue,
              let clientRef = createClient(kCFAllocatorDefault) else { return [] }
        let client = clientRef.takeRetainedValue()

        guard let servicesRef = copyServices(client) else { return [] }
        let services = servicesRef.takeRetainedValue() as [CFTypeRef]

        var readings: [(String, Double)] = []
        for service in services {
            guard let usagePage = property(service, key: "PrimaryUsagePage") as? Int,
                  let usage = property(service, key: "PrimaryUsage") as? Int,
                  usagePage == kHIDPageAppleVendor,
                  usage == kHIDUsageAppleVendorTemperatureSensor else { continue }

            guard let eventRef = copyEvent(service, kIOHIDEventTypeTemperature, 0, 0) else { continue }
            let event = eventRef.takeRetainedValue()

            let value = eventFloatValue(event, kIOHIDEventFieldTemperatureLevel)
            guard value > 0 else { continue }

            let name = (property(service, key: "Product") as? String) ?? "Unknown"
            readings.append((name, value))
        }
        return readings
    }

    private func property(_ service: CFTypeRef, key: String) -> Any? {
        guard let copyProperty,
              let value = copyProperty(service, key as CFString) else { return nil }
        return value.takeRetainedValue()
    }
}
