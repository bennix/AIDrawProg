import Foundation

struct ZenMuxError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum ZenMux {
    /// 流式调用 ZenMux chat/completions，逐块产出正文文本。
    static func streamCompletion(
        apiKey: String,
        model: String,
        systemPrompt: String,
        userText: String,
        imageBase64JPEG: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: URL(string: AppSettings.baseURL + "/chat/completions")!)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 60
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "messages": [
                            ["role": "system", "content": systemPrompt],
                            ["role": "user", "content": [
                                ["type": "text", "text": userText],
                                ["type": "image_url",
                                 "image_url": ["url": "data:image/jpeg;base64,\(imageBase64JPEG)"]],
                            ]],
                        ],
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw ZenMuxError(message: "无效的服务器响应")
                    }
                    guard http.statusCode == 200 else {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        let text = String(data: data, encoding: .utf8) ?? ""
                        switch http.statusCode {
                        case 401:
                            throw ZenMuxError(message: "API Key 无效，请到设置页检查（HTTP 401）")
                        case 429:
                            throw ZenMuxError(message: "请求过于频繁或额度不足，请稍后再试（HTTP 429）")
                        default:
                            throw ZenMuxError(message: "请求失败（HTTP \(http.statusCode)）：\(text.prefix(200))")
                        }
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard
                            let json = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                            let choices = json["choices"] as? [[String: Any]],
                            let delta = choices.first?["delta"] as? [String: Any],
                            let content = delta["content"] as? String,
                            !content.isEmpty
                        else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 基于已生成的回答继续流式追问。
    static func streamFollowUp(
        apiKey: String,
        model: String,
        systemPrompt: String,
        previousResponse: String,
        question: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: URL(string: AppSettings.baseURL + "/chat/completions")!)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 60
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "messages": [
                            ["role": "system", "content": systemPrompt],
                            ["role": "user", "content": "请基于此前对手绘图的代码讲解继续回答。"],
                            ["role": "assistant", "content": previousResponse],
                            ["role": "user", "content": question],
                        ],
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw ZenMuxError(message: "无效的服务器响应")
                    }
                    guard http.statusCode == 200 else {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        let text = String(data: data, encoding: .utf8) ?? ""
                        switch http.statusCode {
                        case 401:
                            throw ZenMuxError(message: "API Key 无效，请到设置页检查（HTTP 401）")
                        case 429:
                            throw ZenMuxError(message: "请求过于频繁或额度不足，请稍后再试（HTTP 429）")
                        default:
                            throw ZenMuxError(message: "请求失败（HTTP \(http.statusCode)）：\(text.prefix(200))")
                        }
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard
                            let json = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                            let choices = json["choices"] as? [[String: Any]],
                            let delta = choices.first?["delta"] as? [String: Any],
                            let content = delta["content"] as? String,
                            !content.isEmpty
                        else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
