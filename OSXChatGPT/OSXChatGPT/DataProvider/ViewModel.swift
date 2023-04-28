//
//  ViewModel.swift
//  OSXChatGPT
//
//  Created by CoderChan on 2023/3/8.
//

import Foundation
import SwiftUI
import CoreData
import Splash



@MainActor class ViewModel: ObservableObject {
    @Published var showDynamicBackground: Bool = ProjectSettingManager.shared.showDynamicBackground//动态背景
    @Published var conversations: [Conversation] = []//所有会话
    @Published var messages: [Message] = []//当前会话的消息
    @Published var showUserInitialize: Bool = false//显示设置页
    @Published var showEditRemark: Bool = false//显示编辑备注
    @Published var showAIPrompt: Bool = false //显示自定义提示
    var editConversation: Conversation?//编辑备注的会话
    @Published var createNewChat: Bool = false//创建新会话
    @Published var changeMsgText: String = ""
    @State var scrollID = UUID()
    var currentConversation: Conversation?//当前会话
    
    @State var model: ChatGPTModel = ChatGPTManager.shared.model
    @Published var showStopAnswerBtn: Bool = false
    
    private var allChatRoomViews: [String:ChatRoomView] = [:]
    
    @Environment(\.colorScheme) private var colorScheme
    
    var theme: Splash.Theme {
        switch colorScheme {
        case .dark:
            return .wwdc17(withFont: .init(size: 16))
        default:
            return .sunset(withFont: .init(size: 16))
        }
    }
    
    func codeTheme(scheme: ColorScheme) -> Splash.Theme {
        switch scheme {
        case .dark:
            return .wwdc17(withFont: .init(size: 16))
        default:
            return .sunset(withFont: .init(size: 16))
        }
    }
    
    init() {
        fetchConversations()
    }
    func checkGPT(sesstion: Conversation?) {
        if sesstion?.chatGPT == nil {
            var gpt = ChatGPT(context: CoreDataManager.shared.container.viewContext)
            configChatGPT(&gpt)
            sesstion?.chatGPT = gpt
            if let idx = conversations.firstIndex(where: {$0.sesstionId == sesstion?.sesstionId}) {
                conversations[idx] = sesstion!
            }
            CoreDataManager.shared.saveData()
        }
    }
    func updateConversation(sesstion: Conversation?) {
        CoreDataManager.shared.saveData()
    }
    
    func updateConversation(sesstionId: String, prompt: Prompt) {
        var con = fetchConversation(sesstionId: sesstionId)
        if con == nil {
            con = Conversation(context: CoreDataManager.shared.container.viewContext)
            con?.sesstionId = sesstionId
            con?.id = UUID()
        }
        con!.updateData = Date()
        con?.prompt = prompt
        
        CoreDataManager.shared.saveData()
        if let index = conversations.firstIndex(where: { $0.sesstionId == sesstionId}) {
            conversations[index] = con!
        } else {
            conversations.insert(con!, at: 0)
        }
    }
    func updateConversation(sesstionId: String, message: Message?) {
        var con = fetchConversation(sesstionId: sesstionId)
        if con == nil {
            con = Conversation(context: CoreDataManager.shared.container.viewContext)
            con?.sesstionId = sesstionId
            con?.id = UUID()
        }
        con!.lastMessage = message
        con!.updateData = Date()
        CoreDataManager.shared.saveData()
        
        if let index = conversations.firstIndex(where: { $0.sesstionId == sesstionId}) {
            conversations[index] = con!
        } else {
            conversations.insert(con!, at: 0)
        }
    }
    func updateConversation(sesstionId: String, remark: String?) {
        var con = fetchConversation(sesstionId: sesstionId)
        if con == nil {
            con = Conversation(context: CoreDataManager.shared.container.viewContext)
            con?.sesstionId = sesstionId
            con?.id = UUID()
            con?.updateData = Date()
        }
        con?.remark = remark
        CoreDataManager.shared.saveData()
        if let index = conversations.firstIndex(where: { $0.sesstionId == sesstionId}) {
            conversations[index] = con!
        }
    }
    //**这里是一个Fake会话, 不需要存入数据库
    func addNewConversation() -> Conversation {
        let con = Conversation(context: CoreDataManager.shared.container.viewContext)
        con.sesstionId = createSesstionId()
        con.id = UUID()
        con.updateData = Date()
        if con.chatGPT == nil {
            var gpt = ChatGPT(context: CoreDataManager.shared.container.viewContext)
            configChatGPT(&gpt)
            con.chatGPT = gpt
        }
        currentConversation = con
        return con
    }
    func configChatGPT(_ gpt: inout ChatGPT) {
        gpt.temperature = 1
        gpt.context = .context3
        gpt.modelType = .gpt35turbo
    }
    func addConversation() {
        let con = Conversation(context: CoreDataManager.shared.container.viewContext)
        con.sesstionId = createSesstionId()
        con.updateData = Date()
        con.id = UUID()
        CoreDataManager.shared.saveData()
        fetchConversations()
    }
    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.sesstionId == conversation.sesstionId }
        deleteAllMessage(sesstionId: conversation.sesstionId)
        CoreDataManager.shared.delete(objects: [conversation])
        //删除会话对应的消息
        if currentConversation?.sesstionId == conversation.sesstionId {
            currentConversation = nil
        }
    }
    
    
    func createSesstionId() -> String {
        if #available(macOS 12, *) {
            return String(Date.now.timeIntervalSince1970 * 1000)
        } else {
            return String(Date().timeIntervalSince1970 * 1000)
        }
    }
    
    class func createSesstionId() -> String {
        if #available(macOS 12, *) {
            return String(Date.now.timeIntervalSince1970 * 1000)
        } else {
            return String(Date().timeIntervalSince1970 * 1000)
        }
    }
    
}
// MARK: - message
extension ViewModel {
    func fetchFirstMessage(sesstionId: String) {
        messages = []
        fetchMoreMessage(sesstionId: sesstionId)
    }
    func fetchMoreMessage(sesstionId: String) {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "sesstionId == %@", sesstionId)
        let timestampSortDescriptor = NSSortDescriptor(key: "createdDate", ascending: false)
        request.sortDescriptors = [timestampSortDescriptor]

        request.fetchLimit = 15
        request.fetchOffset = messages.count
        var results: [Message] = CoreDataManager.shared.fetch(request: request)
        results = results.reversed()
        if results.count == 0 {
            return
        }
//        results.forEach { message in
//            if let tempArray = message.textModel.array as? [MessageText] {
//                tempArray.forEach { item in
//                    message.removeFromTextModel(item)
//                }
//                CoreDataManager.shared.delete(objects: tempArray)
//            }
//            if message.textModel.array.count == 0 {
//                let arr = self.generateContent(message.text ?? "")
//                arr.forEach { item in
//                    message.addToTextModel(item)
//                }
//            }
//        }
//        CoreDataManager.shared.saveData()
        
        if messages.count == 0 {
            if let last = results.last {
                if last.role == ChatGPTManager.shared.gptRoleString {
                    //最后一条是gpt消息，并且已经回复，则删除以前的回复中
                    if last.type != 1 {
                        let thinks = results.filter({$0.msgType == .waitingReply })
                        if thinks.count > 0 {
                            results.removeAll(where: {$0.msgType == .waitingReply})
                            CoreDataManager.shared.delete(objects: thinks)
                        }
                    }
                }
            }
            messages = results
        }else {
            // 需要优化滚动问题
            messages.insert(contentsOf: results, at: 0)
        }
    }
    func deleteMessage(message: Message) {
        messages.removeAll(where: {$0.id == message.id})
        CoreDataManager.shared.delete(object: message)
    }
    func deleteAllMessage(sesstionId: String) {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "sesstionId == %@", sesstionId)
        CoreDataManager.shared.delete(request: request)
    }
    func addGptThinkMessage(sesstionId: String) {
        removeGptThinkMessage()
        
        let msg = Message(context: CoreDataManager.shared.container.viewContext)
        msg.sesstionId = sesstionId
        msg.id = UUID()
        msg.createdDate = Date()
        msg.text = "......"
        msg.role = ChatGPTManager.shared.gptRoleString
        msg.msgType = .waitingReply
        messages.append(msg)
        CoreDataManager.shared.saveData()
    }
    func removeGptThinkMessage() {
        let msg = messages.filter({ $0.msgType == .waitingReply})
        if msg.count == 0 {
            return
        }
        if messages.contains(where: { $0.msgType == .waitingReply}) {
            messages.removeAll(where: { $0.msgType == .waitingReply} )
        }
        CoreDataManager.shared.delete(objects: msg)
        
    }
    func resendMessage(sesstionId: String, prompt: String?) {
        if let lastMsg = messages.last {
            messages.removeAll(where: {$0.id == lastMsg.id })
            CoreDataManager.shared.delete(objects: [lastMsg])
        }
        sendMessage(sesstionId: sesstionId, messages: messages, prompt:prompt) {
            
        }
    }
    func addNewMessage(sesstionId: String, text: String, role: String, prompt: String?, updateBlock: @escaping(() -> ())) {
        if sesstionId.isEmpty {
            return
        }
        if ChatGPTManager.shared.chatGPTSpeaking {
            return
        }
        let msg = Message(context: CoreDataManager.shared.container.viewContext)
        msg.sesstionId = sesstionId
        msg.text = text
        msg.role = role
        msg.id = UUID()
        msg.createdDate = Date()
        messages.append(msg)
        CoreDataManager.shared.saveData()
        updateConversation(sesstionId: sesstionId, message:messages.last)
        self.scrollID = msg.id!
        self.changeMsgText = text
        print("发送提问：\(text)")
        var sendMsgs = messages
        sendMsgs.removeAll(where: {$0.msgType == .waitingReply})
        sendMessage(sesstionId: sesstionId, messages: sendMsgs, prompt: prompt, updateBlock: updateBlock)
    }
    func cancel() {
        ChatGPTManager.shared.stopResponse()
        self.removeGptThinkMessage()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            //停止后保存数据到数据库
            CoreDataManager.shared.saveData()
            //删除最后一天没有内容的消息
            if let lastMsg = self.messages.last {
                if lastMsg.text == nil || lastMsg.text!.isEmpty {
                    self.messages.removeAll(where: {$0.id == lastMsg.id})
                    CoreDataManager.shared.delete(object: lastMsg)
                }
            }
        }
    }
    private func sendMessage(sesstionId: String, messages: [Message], prompt: String?, updateBlock: @escaping(() -> ())) {
        var isFeedback = false
        var newMsg: Message?
        if ChatGPTManager.shared.answerType.valueBool {
            self.showStopAnswerBtn = true
        }
        
//        var stream: String = ""
        ChatGPTManager.shared.askChatGPTStream(messages: messages, prompt: prompt, chatGpt: currentConversation?.chatGPT) { rsp in
            if rsp.request.answerType == .stream {
                isFeedback = true
                //流式请求
                if rsp.state == .replyStart {
//                    stream = ""
                    DispatchQueue.main.async {
                        self.removeGptThinkMessage()
                        newMsg = Message(context: CoreDataManager.shared.container.viewContext)
                        newMsg?.sesstionId = sesstionId
                        newMsg?.role = ChatGPTManager.shared.gptRoleString
                        newMsg?.id = UUID()
                        newMsg?.createdDate = Date()
                        newMsg?.msgTextType = .none
//                        let textModel = MessageText(context: CoreDataManager.shared.container.viewContext)
//                        textModel.id = UUID()
//                        textModel.textType = .text
//                        newMsg?.addToTextModel(textModel)
                        
                        if self.currentConversation?.sesstionId == sesstionId {
                            self.messages.append(newMsg!)
                        }
                        CoreDataManager.shared.saveData()
                        self.updateConversation(sesstionId: sesstionId, message:newMsg)
                        if self.currentConversation?.sesstionId == sesstionId {
                            self.scrollID = newMsg!.id!
                            self.changeMsgText = ""//更新滚动
                        }
                    }
                }else if rsp.state == .replying {
                    if newMsg == nil {
                        return
                    }
                    
//                    stream += rsp.stream
//                    if stream.contains("```") {//有代码块
//                        let arr = stream.components(separatedBy: "```")
//                        let first = arr.first ?? ""
//                        let second = arr.last ?? ""
//                        let textModel = newMsg?.textModel.array.last as? MessageText
//                        textModel?.text = first
//                        if newMsg!.msgTextType == .text || newMsg!.msgTextType == .none {
//                            //文本变代码块
//                            textModel?.textType = .text
//                            textModel?.isFull = true
//                            textModel?.text = textModel?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
//
//                            stream = second
//                            newMsg?.msgTextType = .code
//                            DispatchQueue.main.async {
//                                let codeModel = MessageText(context: CoreDataManager.shared.container.viewContext)
//                                codeModel.text = second
//                                codeModel.id = UUID()
//                                codeModel.textType = .code
//                                newMsg?.msgTextType = .code
//                                newMsg?.addToTextModel(codeModel)
////                                CoreDataManager.shared.saveData()
//                            }
//                        }else if newMsg!.msgTextType == .code {
//                            //代码块变文本
//                            textModel?.textType = .code
//                            textModel?.isFull = true
//                            textModel?.text = textModel?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
//
//                            stream = second
//                            newMsg?.msgTextType = .text
//                            DispatchQueue.main.async {
//                                let codeModel = MessageText(context: CoreDataManager.shared.container.viewContext)
//                                codeModel.text = second
//                                codeModel.id = UUID()
//                                codeModel.textType = .text
//                                newMsg?.msgTextType = .text
//                                newMsg?.addToTextModel(codeModel)
////                                CoreDataManager.shared.saveData()
//                            }
//                        }
//
//
//                    }else {//没有新代码块，则添加到最后一个
//                        let textModel = newMsg?.textModel.array.last as? MessageText
//                        textModel?.text = stream
//                    }

                    DispatchQueue.main.async {
                        if self.currentConversation?.sesstionId == sesstionId {
                            self.scrollID = newMsg!.id!
                            newMsg?.text = rsp.text
                            self.messages[self.messages.count - 1] = newMsg!//更新UI
                            self.changeMsgText = rsp.text//更新滚动
                        }
                    }
                }else if rsp.state == .replyFial {
                    DispatchQueue.main.async {
                        self.removeGptThinkMessage()
                        if newMsg == nil {
                            newMsg = Message(context: CoreDataManager.shared.container.viewContext)
                            newMsg?.sesstionId = sesstionId
                            newMsg?.role = ChatGPTManager.shared.gptRoleString
                            newMsg?.id = UUID()
                            newMsg?.msgType = .fialMsg
                            newMsg?.createdDate = Date()
                            if self.currentConversation?.sesstionId == sesstionId {
                                self.messages.append(newMsg!)
                            }
                        }
                        CoreDataManager.shared.saveData()
                        //失败
                        newMsg?.text = rsp.text
                        if self.currentConversation?.sesstionId == sesstionId {
                            if self.messages.count > 0 {
                                self.messages[self.messages.count - 1] = newMsg!//更新UI
                            }
                            self.changeMsgText = rsp.text//更新滚动
                        }
                        self.showStopAnswerBtn = false
                        updateBlock()
                    }
                }else if rsp.state == .replyFinish {
                    DispatchQueue.main.async {
//                        let arr = self.generateContent(rsp.text)
//                        if let taskListTasks = newMsg?.textModel.array as? [MessageText] {
//                            taskListTasks.forEach({ item in
//                                newMsg?.removeFromTextModel(item)
//                            })
//                            CoreDataManager.shared.delete(objects: taskListTasks)
//                        }
//                        arr.forEach { item in
//                            newMsg?.addToTextModel(item)
//                        }
                        self.updateConversation(sesstionId: sesstionId, message:newMsg)
                        CoreDataManager.shared.saveData()
                        if self.currentConversation?.sesstionId == sesstionId {
                            self.changeMsgText = rsp.text//更新滚动
                        }
                        self.showStopAnswerBtn = false
                        updateBlock()
                    }
                }
            }else {
                isFeedback = true
                //完整请求
                if rsp.state == .replyStart {
                    DispatchQueue.main.async {
                        self.removeGptThinkMessage()
                        newMsg = Message(context: CoreDataManager.shared.container.viewContext)
                        newMsg?.sesstionId = sesstionId
                        newMsg?.role = ChatGPTManager.shared.gptRoleString
                        newMsg?.id = UUID()
                        newMsg?.createdDate = Date()
                        CoreDataManager.shared.saveData()
                        self.updateConversation(sesstionId: sesstionId, message:newMsg)
                        if self.currentConversation?.sesstionId == sesstionId {
                            self.scrollID = newMsg!.id!
                            self.messages.append(newMsg!)
                            self.changeMsgText = rsp.text//更新滚动
                        }
                    }
                }else if rsp.state == .replyFial {
                    DispatchQueue.main.async {
                        //失败
                        if newMsg == nil {
                            newMsg = Message(context: CoreDataManager.shared.container.viewContext)
                            newMsg?.sesstionId = sesstionId
                            newMsg?.role = ChatGPTManager.shared.gptRoleString
                            newMsg?.id = UUID()
                            newMsg?.msgType = .fialMsg
                            newMsg?.createdDate = Date()
                        }
                        newMsg?.text = rsp.text
                        CoreDataManager.shared.saveData()
                        if self.currentConversation?.sesstionId == sesstionId {
                            self.scrollID = newMsg!.id!
                            self.updateConversation(sesstionId: sesstionId, message:newMsg)
                            self.messages[self.messages.count - 1] = newMsg!//更新UI
                            self.changeMsgText = rsp.text//更新滚动
                        }
                        updateBlock()
                    }
                }else if rsp.state == .replyFinish {
                    DispatchQueue.main.async {
                        //成功
                        newMsg?.text = rsp.text
                        CoreDataManager.shared.saveData()
                        if self.currentConversation?.sesstionId == sesstionId {
                            self.scrollID = newMsg!.id!
                            self.updateConversation(sesstionId: sesstionId, message:newMsg)
                            self.messages[self.messages.count - 1] = newMsg!//更新UI
                            self.changeMsgText = rsp.text//更新滚动
                        }
                        updateBlock()
                    }
                }
                
            }
            
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !isFeedback {
                self.addGptThinkMessage(sesstionId: sesstionId)
                if let lastId = self.messages.last?.id {
                    self.scrollID = lastId
                }
                self.changeMsgText = ""//更新滚动
            }
        }
    }
    
}
extension ViewModel {
    func getChatRoomView(conversation: Conversation?) -> ChatRoomView {
        if conversation == nil || conversation!.sesstionId == "" {
            let view = ChatRoomView(conversation: conversation)
            return view
        }
        if let view = allChatRoomViews[conversation?.sesstionId ?? ""] {
            return view
        }
        let view = ChatRoomView(conversation: conversation)
        allChatRoomViews[conversation!.sesstionId] = view
        return view
    }
}

extension ViewModel {
    private func getNowData() -> Int64 {
        if #available(macOS 12, *) {
            return Int64(Date.now.timeIntervalSince1970)
        } else {
            return Int64(Date().timeIntervalSince1970)
        }
    }
    
    private func generateContent(_ content:String) -> [MessageText] {
            var array: [MessageText] = []
            if !content.contains("```") {
                let codeModel = MessageText(context: CoreDataManager.shared.container.viewContext)
                codeModel.text = content
                codeModel.id = UUID()
                codeModel.textType = .text
                array.append(codeModel)
            }else {
                let components = content.components(separatedBy: "```")
                var idx: Int = 0// 0: code， 1: text
                for (index, str) in components.enumerated() {
                    if index == 0 {
                        if (content.hasPrefix("```")) {
                            idx = 0
                        }else {
                            idx = 1
                        }
                        if idx == 0 {
                            let model = self.createMessageCodeModel(text: str)
                            array.append(model)
                            
                        }else {
                            let content = str.trimmingCharacters(in: .whitespacesAndNewlines)
                            let codeModel = MessageText(context: CoreDataManager.shared.container.viewContext)
                            codeModel.text = content
                            codeModel.id = UUID()
                            codeModel.textType = .text
                            array.append(codeModel)
                        }
                        if idx == 0 {
                            idx = 1
                        }else {
                            idx = 0
                        }
    
                    }else {
                        if idx == 0 {
                            let model = self.createMessageCodeModel(text: str)
                            array.append(model)
                        }else {
                            let content = str.trimmingCharacters(in: .whitespacesAndNewlines)
                            let codeModel = MessageText(context: CoreDataManager.shared.container.viewContext)
                            codeModel.text = content
                            codeModel.id = UUID()
                            codeModel.textType = .text
                            array.append(codeModel)
                        }
                        if idx == 0 {
                            idx = 1
                        }else {
                            idx = 0
                        }
                    }
    
                }
            }
            return array
        }
    
        private func createMessageCodeModel(text: String) -> MessageText {
            let lines = text.components(separatedBy: "\n")
            let secondLine = lines[0]
            var content = String(text)
            let startIndex = text.index(text.startIndex, offsetBy: 0)
            let endIndex = text.index(text.startIndex, offsetBy: secondLine.count)
            let range = startIndex..<endIndex
            content = text.replacingCharacters(in: range, with: "")
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let codeModel = MessageText(context: CoreDataManager.shared.container.viewContext)
            codeModel.text = content
            codeModel.id = UUID()
            codeModel.textType = .code
            return codeModel
        }
}

extension ViewModel {
    func fetchConversations() {
        let completedDateSort = NSSortDescriptor(keyPath: \Conversation.updateData, ascending: false)
        var aa: [Conversation] = CoreDataManager.shared.fetch("Conversation", sorting: [completedDateSort])
        let remove = aa.filter { $0.lastMessage == nil && $0.prompt == nil }
        CoreDataManager.shared.delete(objects: remove)
        aa.removeAll { $0.lastMessage == nil && $0.prompt == nil}
        aa.forEach { con in
            if con.chatGPT == nil {
                var gpt = ChatGPT(context: CoreDataManager.shared.container.viewContext)
                configChatGPT(&gpt)
                con.chatGPT = gpt
            }
        }
        CoreDataManager.shared.saveData()
        conversations = aa
    }
    private func fetchConversation(sesstionId: String) -> Conversation? {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "sesstionId == %@", sesstionId)
        let results: [Conversation] = CoreDataManager.shared.fetch(request: request)
        return results.first
        
    }
}


extension ViewModel {
    
}
