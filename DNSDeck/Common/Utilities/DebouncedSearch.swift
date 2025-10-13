import Combine
import Foundation

@MainActor
class DebouncedSearch: ObservableObject {
    @Published var searchText = ""
    @Published var debouncedSearchText = ""

    private var cancellables = Set<AnyCancellable>()
    private let debounceDelay: TimeInterval

    init(debounceDelay: TimeInterval = 0.3) {
        self.debounceDelay = debounceDelay

        $searchText
            .debounce(for: .seconds(debounceDelay), scheduler: RunLoop.main)
            .assign(to: \.debouncedSearchText, on: self)
            .store(in: &cancellables)
    }

    func clear() {
        searchText = ""
        debouncedSearchText = ""
    }
}
