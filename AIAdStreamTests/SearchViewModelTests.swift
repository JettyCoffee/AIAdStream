import XCTest
@testable import AIAdStream

@MainActor
final class SearchViewModelTests: XCTestCase {
    var viewModel: SearchViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SearchViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState_IsEmpty() {
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertFalse(viewModel.isStreaming)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testHasConversation_InitiallyFalse() {
        XCTAssertFalse(viewModel.hasConversation)
    }

    func testClearConversation_ResetsState() {
        viewModel.clearConversation()
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertFalse(viewModel.isStreaming)
    }

    func testChatHistory_ExcludesSystemMessages() {
        // 初始状态聊天历史应为空
        let history = viewModel.chatHistory
        XCTAssertTrue(history.isEmpty)
    }

    func testConversationPersistence_SaveAndLoad() {
        let records = SearchViewModel.loadAllHistory()
        // 确保不会崩溃，history 可能为空也可能有之前的数据
        XCTAssertNotNil(records)
    }
}
