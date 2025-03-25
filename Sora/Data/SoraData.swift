import Foundation
import SwiftData
import Security

class SoraAPIKeys {
    static let shared = SoraAPIKeys()
    
    private init() {} // 싱글톤 인스턴스

    /// Keychain에 API 키 저장
    func save(api: APIType, key: String) {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: api.rawValue,
            kSecValueData as String: data
        ]

        // 기존 값 삭제 후 저장
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    /// Keychain에서 API 키 불러오기
    func load(api: APIType) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: api.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &dataTypeRef) == noErr,
           let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Keychain에서 API 키 삭제
    func delete(api: APIType) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: api.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// API 종류 정의
enum APIType: String {
    case gemini = "gemini_api_key"
    case openai = "openai_api_key"
}



struct SoraDataManager {
    static let shared = SoraDataManager()
    
    private init() {} // 싱글톤 패턴 적용
    /// `SoraSettings`에서 `defaultModel` 값을 가져오는 함수


    func newConversation(modelContext: ModelContext, chatType: String) -> SoraConversationsDatabase {
        let defaultModel = "gemini-2.0-flash"
        let conversation = SoraConversationsDatabase(chatType: chatType, model: defaultModel)
        modelContext.insert(conversation)
        return conversation
    }
    
    
}
