import Foundation

/// Field numbers follow PiliPlus's bilibili.metadata schemas.
enum PrivateMessageGRPC {
    static func headers(accessKey: String, buvid: String, sessionID: String) -> [String: String] {
        let metadata = protobuf(strings: [1: accessKey, 2: "android_hd", 3: "android", 5: "master", 6: buvid, 7: "android"], integers: [4: 2001100])
        let device = protobuf(strings: [3: buvid, 4: "android_hd", 5: "android", 7: "master", 8: "android", 9: "android", 10: "15", 13: "2.0.1"], integers: [1: 5, 2: 2001100])
        return [
            "Authorization": "identify_v1 \(accessKey)",
            "User-Agent": "Mozilla/5.0 BiliDroid/2.0.1 (bbcallen@gmail.com) os/android mobi_app/android_hd build/2001100 channel/master",
            "buvid": buvid,
            "x-bili-metadata-bin": metadata.base64EncodedString(),
            "x-bili-device-bin": device.base64EncodedString(),
            "x-bili-fawkes-req-bin": protobuf(strings: [1: "android_hd", 2: "prod", 3: sessionID]).base64EncodedString(),
            "x-bili-network-bin": protobuf(integers: [1: 1]).base64EncodedString(),
            "grpc-accept-encoding": "identity"
        ]
    }

    static func protobuf(strings: [Int: String] = [:], integers: [Int: UInt64] = [:]) -> Data {
        var data = Data()
        for field in Set(strings.keys).union(integers.keys).sorted() {
            if let value = strings[field], !value.isEmpty {
                let bytes = Data(value.utf8)
                data.append(varint(UInt64(field << 3 | 2)))
                data.append(varint(UInt64(bytes.count)))
                data.append(bytes)
            } else if let value = integers[field] {
                data.append(varint(UInt64(field << 3)))
                data.append(varint(value))
            }
        }
        return data
    }

    private static func varint(_ value: UInt64) -> Data {
        var number = value
        var result = Data()
        repeat {
            var byte = UInt8(number & 0x7f)
            number >>= 7
            if number > 0 { byte |= 0x80 }
            result.append(byte)
        } while number > 0
        return result
    }

    // google.rpc.Status -> repeated Any -> embedded bilibili.rpc.Status.
    static func errorDetails(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let padded = raw + String(repeating: "=", count: (4 - raw.count % 4) % 4)
        guard let data = Data(base64Encoded: padded) else { return nil }
        let fields = lengthDelimitedFields(data)
        let details = (fields[3] ?? []).flatMap { lengthDelimitedFields($0)[2] ?? [] }
        let messages = details.flatMap { lengthDelimitedFields($0)[2] ?? [] }
            .compactMap { String(data: $0, encoding: .utf8) }.filter { !$0.isEmpty }
        if !messages.isEmpty { return messages.joined(separator: "\n") }
        return fields[2]?.first.flatMap { String(data: $0, encoding: .utf8) }
    }

    private static func lengthDelimitedFields(_ data: Data) -> [Int: [Data]] {
        let bytes = Array(data)
        var offset = 0
        func readVarint() -> UInt64? {
            var value: UInt64 = 0
            for shift in stride(from: 0, to: 64, by: 7) {
                guard offset < bytes.count else { return nil }
                let byte = bytes[offset]; offset += 1
                if shift == 63 && byte > 1 { return nil }
                value |= UInt64(byte & 0x7f) << shift
                if byte & 0x80 == 0 { return value }
            }
            return nil
        }
        var fields: [Int: [Data]] = [:]
        while offset < bytes.count {
            guard let tag = readVarint() else { break }
            switch tag & 7 {
            case 0: guard readVarint() != nil else { return fields }
            case 1: offset += 8
            case 5: offset += 4
            case 2:
                guard let count = readVarint(), count <= UInt64(bytes.count - offset) else { return fields }
                let end = offset + Int(count)
                fields[Int(tag >> 3), default: []].append(Data(bytes[offset..<end]))
                offset = end
            default: return fields
            }
        }
        return fields
    }
}
