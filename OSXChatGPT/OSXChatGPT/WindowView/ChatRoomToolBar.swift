//
//  ChatRoomToolBar.swift
//  OSXChatGPT
//
//  Created by CoderChan on 2023/3/25.
//

import SwiftUI

struct ChatRoomToolBar: View {
    @State private var showPopover = false
    @State private var showInputView = false
    @EnvironmentObject var viewModel: ViewModel
    
    @State private var isAnswerTypeTrue = ChatGPTManager.shared.answerType.valueBool
    var body: some View {
        Spacer()
        HStack {
            BrowserView(items: ChatGPTModel.allCases, title: "模型", item: ChatGPTManager.shared.model) { model in
                ChatGPTManager.shared.model = model
            }
            .frame(width: 60)
            BrowserView(items: ChatGPTContext.allCases, title: "上下文", item: ChatGPTManager.shared.askContextCount) { model in
                ChatGPTManager.shared.askContextCount = model
            }
            .frame(width: 70)
            BrowserView(items: ChatGPTAnswerType.allCases, title: "应答", item: ChatGPTManager.shared.answerType) { model in
                ChatGPTManager.shared.answerType = model
            }
            .frame(width: 60)
            
            Button("修饰语") {
                showPopover.toggle()
            }
            .popover(isPresented: $showPopover) {
                AIPromptPopView(showInputView: $showInputView, showPopover: $showPopover).environmentObject(viewModel)
            }
            
            Button("清空消息") {
                viewModel.messages.removeAll()
                viewModel.deleteAllMessage(sesstionId: viewModel.currentConversation?.sesstionId ?? "")
                viewModel.updateConversation(sesstionId: viewModel.currentConversation?.sesstionId ?? "", message: nil)
            }
            
            Spacer()
            if viewModel.showStopAnswerBtn {
                Button("停止生成") {
                    viewModel.cancel()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewModel.showStopAnswerBtn = false
                    }
                }.padding(.trailing, 15)
            }
            
            
        }
        .padding(.leading, 12)
        .background(Color.clear)
        
    }
}

protocol ToolBarMenuProtocol: Hashable {
    var value: String { get }
    
}

struct BrowserView<T: ToolBarMenuProtocol>: View {
    let items: [T]
    let title: String
    @State var item: T
    var callback: ((T) -> Void)
    
    private let checkedSymbol: String = "checkmark.square.fill"
    
    var body: some View {
        VStack() {
            MenuButton(title) {
                ForEach(items, id: \.self) { item in
                    Button {
                        self.item = item
                        callback(item)
                    } label: {
                        HStack {
                            if self.item == item {
                                Image(systemName: checkedSymbol)
                            }
                            Text("\(item.value)")
                        }
                    }
                }
            }
            .menuButtonStyle(DefaultMenuButtonStyle())
            .padding(0)
            .foregroundColor(.white)
        }
    }
}
