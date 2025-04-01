import SwiftUI
import UIKit

struct TextInputField: View {
    @Binding var text: String
    var onSend: () -> Void
    var onMediaButtonTap: (() -> Void)?  // 미디어 버튼 탭 핸들러 추가
    var isStreaming: Bool = false // 스트리밍 중인지 여부
    
    @State private var textEditorHeight: CGFloat = 36
    @State private var isExpanded: Bool = false
    @FocusState private var isFocused: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let minHeight: CGFloat = 36
    private let maxHeight: CGFloat = 120
    private let collapsedWidth: CGFloat = 200  // 축소 상태 너비
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 알약 모양의 텍스트 필드 컨테이너
            ZStack {
                // 배경 레이어 (더 강화된 글래스 효과)
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        colorScheme == .dark 
                            ? Color.black.opacity(0.2) 
                            : Color.white.opacity(0.7)
                    )
                    .background(
                        // 블러 효과로 글래스 모피즘 강화
                        RoundedRectangle(cornerRadius: 25)
                            .fill(.ultraThinMaterial)
                            .blur(radius: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                
                // 내부 그림자 테두리 (더 미묘하게 개선)
                RoundedRectangle(cornerRadius: 25)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.15)
                            : Color.black.opacity(0.08),
                        lineWidth: 0.5
                    )
                
                // 실제 내용물
                HStack(alignment: .center) {
                    // 미디어 추가 버튼 (왼쪽에 배치)
                    if let onMediaButtonTap = onMediaButtonTap {
                        Button(action: onMediaButtonTap) {
                            Image(systemName: "plus")
                                .font(.system(size: 18))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .opacity(isStreaming ? 0.5 : 1.0) // 스트리밍 중에는 반투명하게
                                .frame(width: 28, height: 28)
                        }
                        .padding(.leading, 12)
                        .contentShape(Rectangle())
                        .disabled(isStreaming) // 스트리밍 중에는 비활성화
                    }
                    
                    // 텍스트 에디터 (여러 줄 입력 지원)
                    ZStack(alignment: .topLeading) {
                        // 플레이스홀더 (포커스 상태에 따라 표시/숨김)
                        if text.isEmpty {
                            Text("메시지 입력")
                                .foregroundColor(Color.gray.opacity(isExpanded ? 0 : 0.8))
                                .padding(.top, 8)
                                .padding(.leading, isFocused ? 3 : 0)
                                .lineLimit(1)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFocused)
                        }
                        
                        // 실제 텍스트 에디터 - 완전히 투명한 배경
                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(height: max(minHeight, min(textEditorHeight, maxHeight)))
                            .focused($isFocused)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .opacity(isStreaming ? 0.7 : 1.0) // 스트리밍 중에는 반투명하게
                            .disabled(isStreaming) // 스트리밍 중에는 비활성화
                            .onChange(of: text) { oldValue, newValue in
                                // 텍스트 높이 계산 - 더 부드러운 애니메이션
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    textEditorHeight = calculateHeight(for: newValue)
                                    
                                    // 텍스트가 입력되면 확장
                                    if !newValue.isEmpty {
                                        isExpanded = true
                                    }
                                }
                            }
                            .onChange(of: isFocused) { oldValue, newValue in
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isExpanded = newValue || !text.isEmpty
                                }
                            }
                    }
                    .padding(.leading, onMediaButtonTap != nil ? 4 : 12)
                    .padding(.trailing, 4)
                    .padding(.vertical, 4)
                    
                    Spacer()
                    
                    // 전송 버튼 (이미지 크기 조정 및 애니메이션 개선)
                    Button(action: {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming {
                            onSend()
                            // 전송 후 텍스트가 비워지면 축소 상태로
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isExpanded = false
                                // 포커스는 유지 (바로 새 메시지 입력 가능)
                            }
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: isFocused || isExpanded ? 30 : 24))
                            .foregroundColor(
                                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming ? 
                                Color.gray.opacity(0.5) : 
                                Color.accentColor
                            )
                            .contentShape(Rectangle())
                            // 전송 버튼 스케일 애니메이션 추가
                            .scaleEffect(isFocused || isExpanded ? 1.0 : 0.9)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFocused)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 4)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
                .padding(.vertical, 2)
            }
            .background(.clear)
            .frame(
                width: isExpanded ? nil : collapsedWidth,
                height: isExpanded ? max(44, min(textEditorHeight + 20, maxHeight + 10)) : 44
            )
            // 포커스 시 테두리 효과 개선
            .overlay(
                Group {
                    if isFocused {
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.accentColor.opacity(0.8), lineWidth: 1.2)
                            .shadow(color: Color.accentColor.opacity(0.25), radius: 4)
                            // 테두리 밝기 애니메이션 효과 추가
                            .opacity(0.8)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isFocused)
                    }
                }
            )
            // 그림자 효과 개선 (더 자연스럽게)
            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
        .background(.clear)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: textEditorHeight)
    }
    
    // 텍스트 내용의 높이 계산 (더 정확한 계산)
    private func calculateHeight(for text: String) -> CGFloat {
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 16)
            ]
        )
        
        // 더 정확한 너비 계산
        let screenWidth = UIScreen.main.bounds.width
        let constraintWidth = screenWidth > 500 ? 500.0 : screenWidth - 120
        
        let constraintBox = CGSize(width: constraintWidth, height: .greatestFiniteMagnitude)
        let rect = attributedString.boundingRect(
            with: constraintBox,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        // 여유 공간 추가
        return max(minHeight, ceil(rect.height + 12))
    }
}

// 간단한 테스트 뷰
struct TextInputDemo: View {
    @State private var inputText = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.05)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // 입력된 텍스트 표시
                if !inputText.isEmpty {
                    Text("입력된 텍스트: \(inputText)")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.7)))
                        .padding()
                }
                
                Spacer()
                
                // 입력 영역 배경
                ZStack {
                    
                    // 텍스트 입력 필드
                    TextInputField(text: $inputText, onSend: {
                        // 전송 버튼 클릭 시 액션
                        print("전송됨: \(inputText)")
                        inputText = ""
                    }, onMediaButtonTap: {
                        print("미디어 버튼 탭")
                    })
                    .padding(.horizontal)
                }
                .background(.clear)
            }
        }
    }
}

// 프리뷰
struct TextInputField_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TextInputDemo()
                .previewDisplayName("라이트 모드")
            
            TextInputDemo()
                .preferredColorScheme(.dark)
                .previewDisplayName("다크 모드")
        }
    }
} 
