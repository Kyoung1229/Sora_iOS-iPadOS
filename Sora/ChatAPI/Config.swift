import Foundation
import Security // Keychain 사용을 위해 Security 프레임워크를 import 합니다.



// --- Keychain 설정 ---

// Keychain 항목을 식별하기 위한 고유 서비스 이름 (앱 번들 ID 등을 사용하는 것이 좋습니다)
private let keychainService = "com.yourapp.apikey.service" // "com.yourapp" 부분을 실제 앱 정보로 변경하세요.

// 각 API 키를 위한 고유 계정 이름
private enum KeychainAccount: String {
    case openai = "openai_api_key"
    case gemini = "gemini_api_key"
}

// --- Keychain 도우미 함수 ---

/// 지정된 계정에 대한 API 키를 Keychain에 저장합니다.
/// - Parameters:
///   - key: 저장할 API 키 문자열
///   - account: 키를 저장할 계정 (KeychainAccount enum)
/// - Returns: 저장 성공 여부 (Bool)
fileprivate func saveKeyToKeychain(key: String, for account: KeychainAccount) -> Bool {
    guard let data = key.data(using: .utf8) else { return false }

    // 기존 키 확인을 위한 쿼리
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: account.rawValue
    ]

    // 기존 키 삭제 시도 (업데이트를 위해)
    SecItemDelete(query as CFDictionary)

    // 새 키 추가를 위한 쿼리
    let addQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: account.rawValue,
        kSecValueData as String: data,
        // 필요에 따라 접근성 수준 조정 가능 (예: kSecAttrAccessibleWhenUnlocked)
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]

    let status = SecItemAdd(addQuery as CFDictionary, nil)
    return status == errSecSuccess
}

/// 지정된 계정에 대한 API 키를 Keychain에서 불러옵니다.
/// - Parameter account: 키를 불러올 계정 (KeychainAccount enum)
/// - Returns: 불러온 API 키 문자열. 키가 없거나 오류 발생 시 nil을 반환합니다.
fileprivate func getKeyFromKeychain(for account: KeychainAccount) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: account.rawValue,
        kSecReturnData as String: kCFBooleanTrue!,
        kSecMatchLimit as String: kSecMatchLimitOne // 하나의 결과만 필요
    ]

    var dataTypeRef: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

    if status == errSecSuccess {
        if let retrievedData = dataTypeRef as? Data,
           let key = String(data: retrievedData, encoding: .utf8) {
            return key
        }
    } else if status != errSecItemNotFound {
        // 키를 찾지 못한 경우 외의 다른 에러는 로그 출력 (디버깅 목적)
        print("Error retrieving key \(account.rawValue) from keychain: \(status)")
    }
    return nil // 키를 찾지 못했거나 오류 발생
}

// --- API 키 접근 함수 ---

/// 지정된 모델 제공자에 대한 API 키를 Keychain에서 가져옵니다.
/// - Parameter provider: API 키를 가져올 모델 제공자 (.openai 또는 .gemini)
/// - Returns: 해당 제공자의 API 키 문자열. 키가 Keychain에 없으면 빈 문자열을 반환합니다.
func getAPI(for provider: ModelProvider) -> String {
    let account: KeychainAccount = (provider == .openai) ? .openai : .gemini
    return getKeyFromKeychain(for: account) ?? ""
}

// --- 초기 키 설정 (예시) ---
// 앱의 설정 화면이나 초기 실행 시점에 사용자의 API 키를 받아 Keychain에 저장하는 로직이 필요합니다.
// 아래 함수는 예시이며, 실제 앱에서는 UI와 연동해야 합니다.
/*
func setupInitialKeys() {
    // 예: 사용자 입력 또는 다른 안전한 방법으로 키를 가져옵니다.
    let userOpenAIKey = "YOUR_OPENAI_API_KEY_HERE"
    let userGeminiKey = "YOUR_GEMINI_API_KEY_HERE"

    if !userOpenAIKey.isEmpty && userOpenAIKey != "YOUR_OPENAI_API_KEY_HERE" {
        let savedOpenAI = saveKeyToKeychain(key: userOpenAIKey, for: .openai)
        print("OpenAI Key saving result: \(savedOpenAI)")
    }

    if !userGeminiKey.isEmpty && userGeminiKey != "YOUR_GEMINI_API_KEY_HERE" {
        let savedGemini = saveKeyToKeychain(key: userGeminiKey, for: .gemini)
        print("Gemini Key saving result: \(savedGemini)")
    }
}
*/

// 참고: ModelProvider enum은 ModelProvider.swift 파일에 정의되어 있어야 합니다.
// enum ModelProvider { case openai, gemini }
