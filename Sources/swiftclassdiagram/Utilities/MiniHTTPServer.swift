import Foundation
import Network

/// 极简 HTTP 服务器（零依赖）。
///
/// 基于 `NWListener` 手写 HTTP/1.1 解析，仅支持 Web 控制台所需的
/// `GET`/`POST`、`Content-Length` body 与 UTF-8 文本响应。
/// 不支持分块传输、Keep-Alive 复用等，够用即可。
final class MiniHTTPServer {
    /// 解析后的 HTTP 请求
    struct Request {
        let method: String
        /// 路径（不含查询串，如 `/api/render`）
        let path: String
        /// 原始查询串（不含 `?`，如 `autoGroup=1`；无查询时为空串）
        let query: String
        let body: Data
    }

    /// 极简 HTTP 响应
    struct Response {
        let statusCode: Int
        let contentType: String
        let body: Data

        static func html(_ string: String) -> Response {
            Response(statusCode: 200, contentType: "text/html; charset=utf-8", body: Data(string.utf8))
        }

        static func text(_ string: String, status: Int = 200) -> Response {
            Response(statusCode: status, contentType: "text/plain; charset=utf-8", body: Data(string.utf8))
        }

        static func json(_ string: String, status: Int = 200) -> Response {
            Response(statusCode: status, contentType: "application/json; charset=utf-8", body: Data(string.utf8))
        }

        /// 任意二进制响应（图片等）。
        static func data(_ body: Data, contentType: String, status: Int = 200) -> Response {
            Response(statusCode: status, contentType: contentType, body: body)
        }

        static let notFound = Response(statusCode: 404, contentType: "text/plain; charset=utf-8", body: Data("Not Found".utf8))
    }

    private let listener: NWListener
    private let handler: (Request) -> Response
    private let queue = DispatchQueue(label: "com.swiftclassdiagram.httpserver", attributes: .concurrent)

    /// - Parameters:
    ///   - port: 监听端口
    ///   - handler: 请求处理闭包（同步返回响应）
    init(port: UInt16, handler: @escaping (Request) -> Response) throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw MiniHTTPServerError.invalidPort(port)
        }
        listener = try NWListener(using: params, on: nwPort)
        self.handler = handler
    }

    /// 启动服务并阻塞当前线程（常驻）。
    func startAndWait() {
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let port = self?.listener.port?.rawValue ?? 0
                print("Web console ready at http://localhost:\(port)")
            case .failed(let error):
                print("Server failed: \(error.localizedDescription)")
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.receiveRequest(connection: connection, buffer: Data())
        }
        listener.start(queue: queue)
        dispatchMain()
    }

    // MARK: - HTTP 请求解析

    private func receiveRequest(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2 * 1024 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            var accumulated = buffer
            if let data, !data.isEmpty {
                accumulated.append(data)
            }

            if let (request, _) = parseRequest(from: accumulated) {
                let response = self.handler(request)
                let head = response.head
                connection.send(content: head + response.body, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            if let error {
                // 解析失败（无完整头/坏请求）：返回 400 后断开
                let response = Response.text("Bad Request: \(error)", status: 400)
                connection.send(content: response.head + response.body, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            if isComplete {
                connection.cancel()
                return
            }

            // 数据不足，继续接收
            self.receiveRequest(connection: connection, buffer: accumulated)
        }
    }

    /// 从缓冲区解析一个完整请求。成功返回请求与消耗的字节数。
    private func parseRequest(from buffer: Data) -> (Request, Int)? {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        guard let headText = String(data: buffer[..<headerEnd.lowerBound], encoding: .utf8) else { return nil }

        let lines = headText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0]).uppercased()
        let rawPath = String(parts[1])
        // 拆分路径与查询串，路由只匹配 path，查询参数单独读取
        let queryIndex = rawPath.firstIndex(of: "?")
        let path = queryIndex.map { String(rawPath[..<$0]) } ?? rawPath
        let query = queryIndex.map { String(rawPath[rawPath.index(after: $0)...]) } ?? ""

        // 提取 Content-Length
        var contentLength = 0
        for header in lines.dropFirst() {
            if header.lowercased().hasPrefix("content-length:") {
                contentLength = Int(header.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
            }
        }

        let bodyStart = headerEnd.upperBound
        guard buffer.count >= bodyStart + contentLength else { return nil }
        let body = buffer.subdata(in: bodyStart..<(bodyStart + contentLength))

        return (Request(method: method, path: path, query: query, body: body), bodyStart + contentLength)
    }
}

enum MiniHTTPServerError: Error, LocalizedError {
    case invalidPort(UInt16)

    var errorDescription: String? {
        switch self {
        case .invalidPort(let port):
            return "Invalid port: \(port)"
        }
    }
}

private extension MiniHTTPServer.Response {
    /// 响应头 + body
    var head: Data {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "OK"
        }
        let head = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
            + "Content-Type: \(contentType)\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: close\r\n"
            + "\r\n"
        return Data(head.utf8)
    }
}
