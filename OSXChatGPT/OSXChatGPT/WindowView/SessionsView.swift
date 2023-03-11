//
//  SessionsView.swift
//  OSXChatGPT
//
//  Created by MustangYM on 2023/3/11.
//

import SwiftUI
import Colorful

struct SessionsView: View {
    @EnvironmentObject var viewModel: ViewModel
    @State private var searchText = ""
    @State var showNewConversationSheet = false
    
    var body: some View {
        
        ZStack {
            ColorfulView(colors: [.accentColor], colorCount: 4)
                .ignoresSafeArea()
            VStack {
                List(viewModel.conversations) { conversation in
                    NavigationLink(destination: ChatView(conversation: conversation).environmentObject(viewModel)) {
                        ChatRowContentView(chat: conversation).environmentObject(viewModel)
                    }
                        .cornerRadius(5)
                }
                .toolbar {
                    let aa = viewModel.addNewConversation()
                    NavigationLink(destination: ChatView(conversation: aa)) {
                        Button(action: {
                            viewModel.conversations.insert(aa, at: 0)
                            showNewConversationSheet = true
                        }) {
                            Label("New Conversation", systemImage: "plus")
                        }
                    }
                }
            }
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 300)
        }
    }
}

/// 左边会话列表
struct ChatRowContentView: View {
    @ObservedObject var chat: Conversation
    var body: some View {
        ChatRowContentNSView(chat: chat)
            .frame(minHeight: 50, idealHeight: 50, maxHeight: 50)
    }
}

/// 左边会话列表
struct ChatRowView: View {
    @ObservedObject var chat: Conversation
    var body: some View {
        HStack {
            Image("openAI_icon")
                .resizable()
                .frame(width: 30, height: 30)
                .padding(.leading, 5)
            VStack(alignment: .leading) {
                Text(chat.remark ?? chat.lastMessage?.text ?? "New Chat")
                    .font(.headline)
                    
            }.padding(.trailing, 5)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.trailing, 5)
    }
}
struct ChatRowContentNSView: NSViewRepresentable {
    @EnvironmentObject var viewModel: ViewModel
    @ObservedObject var chat: Conversation
    @State private var showMenu = false
    @State private var editNote: String = ""
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update view properties and state here.
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSMenuDelegate {
        var parent: ChatRowContentNSView
        
        init(_ parent: ChatRowContentNSView) {
            self.parent = parent
            super.init()
        }
        
        @objc func handleRightClick(_ sender: NSClickGestureRecognizer) {
            if sender.state == .ended {
                print("双击鼠标")
                
                let menu = NSMenu(title: "123")
                menu.delegate = self
                let editMenuItem = NSMenuItem(title: "编辑备注", action: #selector(edit), keyEquivalent: "")
                let deleteMenuItem = NSMenuItem(title: "删除会话", action: #selector(delete), keyEquivalent: "")
                editMenuItem.target = self
                deleteMenuItem.target = self
                menu.addItem(editMenuItem)
                menu.addItem(deleteMenuItem)
                menu.popUp(positioning: nil, at: sender.location(in: sender.view!), in: sender.view!)
                parent.showMenu = true
            }
        }
        func menuDidClose(_ menu: NSMenu) {
//            print("menu menuDidClose!")
        }
        
        @MainActor @objc func edit() {
            parent.editNote = parent.chat.remark ?? ""
            let alert = NSAlert()
            alert.messageText = "修改会话备注"
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            inputTextField.stringValue = parent.editNote
            alert.accessoryView = inputTextField
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                parent.chat.remark = inputTextField.stringValue
                parent.viewModel.updateConversation(sesstionId: parent.chat.sesstionId, remark: parent.chat.remark)
            }
        }
        
        @MainActor @objc func delete() {
            parent.viewModel.deleteConversation(parent.chat)
        }

    }
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 3
        let swiftUIView = ChatRowView(chat: chat)
            .frame(width: 300, height: 40)
        let hostingView = NSHostingView(rootView: swiftUIView)
        view.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        let gestureRecognizer = NSClickGestureRecognizer(target: context.coordinator,
                                                          action: #selector(Coordinator.handleRightClick(_:)))
        gestureRecognizer.buttonMask = 0x2 // 双击事件
        view.addGestureRecognizer(gestureRecognizer)
        return view
    }

}

struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsView()
    }
}
