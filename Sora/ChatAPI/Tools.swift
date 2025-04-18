import Foundation

public struct ToolCall {
    public let name       : String
    public let arguments  : [String: Any]
    public let description: String
    public let id, callId : String
    
    public init(name: String, arguments: [String: Any], id: String = UUID().uuidString, description: String = "", callId: String = UUID().uuidString) {
        self.name = name
        self.arguments = arguments
        self.id = id
        self.description = description
        self.callId = callId
    }
}


