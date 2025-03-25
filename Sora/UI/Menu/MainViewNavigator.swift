//
//  MainViewNavigator.swift
//  Sora
//
//  Created by 김윤 on 3/4/25.
//

import SwiftUI

struct MainViewNavigator: View {
    var body: some View {
        VStack {
            HStack {
                Text("대화 목록")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
            .padding(.leading, 20)
            HStack {
                Text("Vision")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 50)
            .padding(.leading, 20)
            Spacer()
            
        }
        .frame(width: 230, alignment: .leading)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    MainViewNavigator()
}
