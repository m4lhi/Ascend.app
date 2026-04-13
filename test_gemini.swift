import Foundation

let apiKey = "AIzaSyCOKhRRR6Y7rLL_FPKZtHPVV12uVIA_xqw"
let context = "Test context"
let query = "Hello"

let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
guard let url = URL(string: urlString) else {
    print("Invalid URL")
    exit(1)
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

let body: [String: Any] = [
    "system_instruction": [
        "parts": [
            ["text": context]
        ]
    ],
    "contents": [
        [
            "role": "user",
            "parts": [
                ["text": query]
            ]
        ]
    ]
]

request.httpBody = try? JSONSerialization.data(withJSONObject: body)

let sema = DispatchSemaphore(value: 0)
let task = URLSession.shared.dataTask(with: request) { data, resp, err in
    if let err = err {
        print("Error: \(err)")
    }
    if let data = data, let str = String(data: data, encoding: .utf8) {
        print("Response: \(str)")
    }
    sema.signal()
}
task.resume()
sema.wait()
