//
//  TabbarController.swift
//  mantou
//
//  Created by samara on 5/17/24.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import SwiftUI
import UIKit

// 仅为了编译而提供临时类，避免重复声明
#if DEBUG
class LibraryViewController: UIViewController {}
// 移除SettingsViewController的临时声明，因为已经创建了真正的类
#endif

// 添加String扩展支持localized方法
extension String {
	static func localized(_ key: String) -> String {
		// 简单实现，直接返回一些常见的本地化文本
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
	}

	var body: some View {
		TabView(selection: $selectedTab) {
			tab(for: .store)
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
