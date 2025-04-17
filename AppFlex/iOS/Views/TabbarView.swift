
import SwiftUI
import UIKit

#if DEBUG
class LibraryViewController: UIViewController {}
#endif

extension String {
	static func localized(_ key: String) -> String {
		switch key {
		case "TAB_SETTINGS":
			return "设置"
		case "TAB_SOURCES":
			return "源"
		case "TAB_LIBRARY":
			return "库"
		default:
			return key
		}
	}
}

struct TabbarView: View {
	@State private var selectedTab: Tab = Tab(rawValue: UserDefaults.standard.string(forKey: "selectedTab") ?? "store") ?? .store
	
	enum Tab: String {
		case store
		case settings
		case webcloud  // 添加网站导航选项
	}

	var body: some View {
		TabView(selection: $selectedTab) {
			tab(for: .store)
			tab(for: .webcloud)  // 添加网站导航标签
			tab(for: .settings)
		}
		.onChange(of: selectedTab) { newValue in
			UserDefaults.standard.set(newValue.rawValue, forKey: "selectedTab")
		}
	}

	@ViewBuilder
	func tab(for tab: Tab) -> some View {
		switch tab {
		case .store:
			NavigationViewController(StoreCollectionViewController.self, title: "应用商店")
				.edgesIgnoringSafeArea(.all)
				.tabItem { Label("应用商店", systemImage: "bag.fill") }
				.tag(Tab.store)
		case .webcloud:
			NavigationViewController(WebcloudCollectionViewController.self, title: "网站导航")
				.edgesIgnoringSafeArea(.all)
				.tabItem { Label("网站导航", systemImage: "globe") }
				.tag(Tab.webcloud)
		case .settings:
			NavigationViewController(SettingsViewController.self, title: String.localized("TAB_SETTINGS"))
				.edgesIgnoringSafeArea(.all)
				.tabItem { Label(String.localized("TAB_SETTINGS"), systemImage: "gearshape.2.fill") }
				.tag(Tab.settings)
		}
	}
}

struct NavigationViewController<Content: UIViewController>: UIViewControllerRepresentable {
	let content: Content.Type
	let title: String

	init(_ content: Content.Type, title: String) {
		self.content = content
		self.title = title
	}

	func makeUIViewController(context: Context) -> UINavigationController {
		let viewController = content.init()
		viewController.navigationItem.title = title
		return UINavigationController(rootViewController: viewController)
	}
	
	func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
