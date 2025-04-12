//
//  listCollectionViewController.swift
//  mantou
//
//  Created by mantou on 2025/3/28.
//

import UIKit
import SafariServices
import CoreData

class ListCollectionViewController: UIViewController {
    
    // MARK: - 属性
    
    private var collectionView: UICollectionView!
    private var apps: [StoreApp] = []
    private let cellIdentifier = "AppCell"
    private var appStoreData: StoreAppStoreData?
    private var isLoading = false
    private var refreshControl = UIRefreshControl()
    private var announcementView: UIView?
    private var filterView: UIView?
    private var isFilterViewVisible = false
    private var emptyStateView: UIView?
    
    // 接收的参数
    private let sourceURL: String
    private let sourceName: String
    
    // 分类筛选数据
    private let categories = ["全部", "应用", "游戏", "影音", "工具", "插件"]
    private let priceFilters = ["全部", "免费", "收费"]
    private let sortOptions = ["默认", "最新", "最旧"]
    private var selectedCategory = "全部"
    private var selectedPriceFilter = "全部"
    private var selectedSortOption = "默认"
    
    // MARK: - 初始化
    
    init(sourceURL: String, sourceName: String) {
        self.sourceURL = sourceURL
        self.sourceName = sourceName
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureNavBar()
        loadData()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIPAImport(_:)),
            name: NSNotification.Name("ImportIPAFile"),
            object: nil
        )
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 设置CollectionView布局
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // 计算卡片大小
        let screenWidth = UIScreen.main.bounds.width
        let itemsPerRow: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        let availableWidth = screenWidth - layout.sectionInset.left - layout.sectionInset.right - (itemsPerRow - 1) * layout.minimumInteritemSpacing
        let itemWidth = availableWidth / itemsPerRow
        let itemHeight = itemWidth * 1.4
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        
        // 创建CollectionView
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(AppCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true
        view.addSubview(collectionView)
        
        // 添加下拉刷新
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        refreshControl.tintColor = .systemBlue
        collectionView.refreshControl = refreshControl
    }
    
    private func configureNavBar() {
        title = sourceName
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // 设置导航栏样式
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = .systemBlue
        
        // 添加右上角筛选按钮
        let filterButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle.fill"), style: .plain, target: self, action: #selector(toggleFilterView))
        navigationItem.rightBarButtonItem = filterButton
        
        // 添加下载链接按钮
        let downloadLinkButton = UIBarButtonItem(image: UIImage(systemName: "link.badge.plus"), style: .plain, target: self, action: #selector(showURLInputDialogAction))
        
        // 合并导航栏按钮
        navigationItem.rightBarButtonItems = [filterButton, downloadLinkButton]
    }
    
    // 创建顶部公告视图
    private func setupAnnouncementView(withMessage message: String) {
        guard !message.isEmpty else { return }
        
        let screenWidth = UIScreen.main.bounds.width
        let messageHeight = message.heightWithConstrainedWidth(width: screenWidth - 32, font: UIFont.systemFont(ofSize: 14))
        let announcementHeight: CGFloat = messageHeight + 32
        
        announcementView?.removeFromSuperview()
        
        announcementView = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: announcementHeight))
        announcementView?.backgroundColor = .secondarySystemBackground
        
        // 添加模糊效果
        let blurEffect = UIBlurEffect(style: .systemThickMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: announcementHeight)
        announcementView?.addSubview(blurView)
        
        // 添加公告图标
        let iconImageView = UIImageView(image: UIImage(systemName: "megaphone.fill"))
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.frame = CGRect(x: 16, y: (announcementHeight - 24) / 2, width: 24, height: 24)
        blurView.contentView.addSubview(iconImageView)
        
        // 添加公告文本
        let messageLabel = UILabel(frame: CGRect(x: 50, y: 16, width: screenWidth - 66, height: messageHeight))
        messageLabel.text = message
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = .label
        blurView.contentView.addSubview(messageLabel)
        
        // 添加底部分隔线
        let separatorLine = UIView(frame: CGRect(x: 0, y: announcementHeight - 1, width: screenWidth, height: 1))
        separatorLine.backgroundColor = .separator
        blurView.contentView.addSubview(separatorLine)
        
        view.addSubview(announcementView!)
        
        // 调整CollectionView的contentInset以适应顶部公告
        collectionView.contentInset = UIEdgeInsets(top: announcementHeight, left: 0, bottom: 0, right: 0)
    }
    
    // 创建筛选视图
    private func setupFilterView() {
        let screenWidth = UIScreen.main.bounds.width
        let filterHeight: CGFloat = 350 // 增加一点高度以容纳更好的UI
        
        filterView?.removeFromSuperview()
        
        // 创建模糊背景
        let backgroundView = UIView(frame: view.bounds)
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        backgroundView.alpha = 0
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissFilterView))
        backgroundView.addGestureRecognizer(tapGesture)
        
        // 创建筛选面板
        filterView = UIView(frame: CGRect(x: 0, y: view.bounds.height, width: screenWidth, height: filterHeight))
        filterView?.backgroundColor = .systemBackground
        filterView?.layer.cornerRadius = 20
        filterView?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        filterView?.layer.masksToBounds = true
        
        // 创建头部指示器 (拖动条)
        let handleView = UIView(frame: CGRect(x: (screenWidth - 40) / 2, y: 8, width: 40, height: 5))
        handleView.backgroundColor = .systemGray4
        handleView.layer.cornerRadius = 2.5
        filterView?.addSubview(handleView)
        
        // 创建标题
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 24, width: screenWidth, height: 30))
        titleLabel.text = "筛选和排序"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        filterView?.addSubview(titleLabel)
        
        // 创建分类筛选
        let categoryLabel = createFilterSectionLabel(text: "分类", y: 70)
        filterView?.addSubview(categoryLabel)
        
        let categoryStackView = createFilterButtonGroup(items: categories, y: 100, selectedItem: selectedCategory, action: #selector(categorySelected(_:)))
        filterView?.addSubview(categoryStackView)
        
        // 创建付费筛选
        let priceLabel = createFilterSectionLabel(text: "付费类型", y: 160)
        filterView?.addSubview(priceLabel)
        
        let priceStackView = createFilterButtonGroup(items: priceFilters, y: 190, selectedItem: selectedPriceFilter, action: #selector(priceFilterSelected(_:)))
        filterView?.addSubview(priceStackView)
        
        // 创建排序筛选
        let sortLabel = createFilterSectionLabel(text: "排序方式", y: 250)
        filterView?.addSubview(sortLabel)
        
        let sortStackView = createFilterButtonGroup(items: sortOptions, y: 280, selectedItem: selectedSortOption, action: #selector(sortOptionSelected(_:)))
        filterView?.addSubview(sortStackView)
        
        // 添加应用按钮
        let applyButton = UIButton(type: .system)
        applyButton.frame = CGRect(x: 20, y: filterHeight - 60, width: screenWidth - 40, height: 50)
        applyButton.backgroundColor = .systemBlue
        applyButton.setTitle("应用筛选", for: .normal)
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        applyButton.layer.cornerRadius = 12
        applyButton.addTarget(self, action: #selector(dismissFilterView), for: .touchUpInside)
        filterView?.addSubview(applyButton)
        
        view.addSubview(backgroundView)
        view.addSubview(filterView!)
        
        // 动画显示
        UIView.animate(withDuration: 0.3) {
            backgroundView.alpha = 1.0
            self.filterView?.frame.origin.y = self.view.bounds.height - filterHeight
        }
    }
    
    private func createFilterSectionLabel(text: String, y: CGFloat) -> UILabel {
        let label = UILabel(frame: CGRect(x: 20, y: y, width: 200, height: 22))
        label.text = text
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }
    
    private func createFilterButtonGroup(items: [String], y: CGFloat, selectedItem: String, action: Selector) -> UIScrollView {
        let screenWidth = UIScreen.main.bounds.width
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: y, width: screenWidth, height: 44))
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillProportionally
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        var totalWidth: CGFloat = 0
        
        for (index, item) in items.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(item, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            button.tag = index
            button.addTarget(self, action: action, for: .touchUpInside)
            
            // 设置按钮样式
            button.layer.cornerRadius = 15
            button.layer.masksToBounds = true
            
            // 设置内边距，兼容iOS 15+
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                button.configuration = config
            } else {
                button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            }
            
            if item == selectedItem {
                button.backgroundColor = .systemBlue
                button.setTitleColor(.white, for: .normal)
            } else {
                button.backgroundColor = .secondarySystemBackground
                button.setTitleColor(.label, for: .normal)
            }
            
            stackView.addArrangedSubview(button)
            
            // 计算按钮宽度
            let buttonWidth = item.size(withAttributes: [.font: UIFont.systemFont(ofSize: 15, weight: .medium)]).width + 40
            totalWidth += buttonWidth + 12
        }
        
        scrollView.addSubview(stackView)
        
        // 设置stackView约束
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // 设置scrollView内容大小
        scrollView.contentSize = CGSize(width: totalWidth, height: 44)
        
        return scrollView
    }
    
    @objc private func dismissFilterView() {
        guard let filterView = self.filterView else { return }
        
        // 移除背景
        if let backgroundView = filterView.superview?.subviews.first(where: { $0 !== filterView }) {
            UIView.animate(withDuration: 0.3) {
                backgroundView.alpha = 0
                filterView.frame.origin.y = self.view.bounds.height
            } completion: { _ in
                backgroundView.removeFromSuperview()
                filterView.removeFromSuperview()
                self.isFilterViewVisible = false
            }
        }
    }
    
    @objc private func toggleFilterView() {
        if isFilterViewVisible {
            dismissFilterView()
        } else {
            setupFilterView()
            isFilterViewVisible = true
        }
    }
    
    @objc private func categorySelected(_ sender: UIButton) {
        selectedCategory = categories[sender.tag]
        setupFilterView() // 刷新筛选视图
        applyFilters()
    }
    
    @objc private func priceFilterSelected(_ sender: UIButton) {
        selectedPriceFilter = priceFilters[sender.tag]
        setupFilterView() // 刷新筛选视图
        applyFilters()
    }
    
    @objc private func sortOptionSelected(_ sender: UIButton) {
        selectedSortOption = sortOptions[sender.tag]
        setupFilterView() // 刷新筛选视图
        applyFilters()
    }
    
    private func applyFilters() {
        // 这里应该根据选择的筛选条件过滤数据
        // 简单的模拟实现，实际应用中需要根据实际数据结构进行过滤
        if let originalData = appStoreData?.apps {
            var filteredApps = originalData
            
            // 应用分类筛选
            if selectedCategory != "全部" {
                // 类型筛选逻辑，这里假设type字段表示分类
                // 这里只是示例，实际应用中需要根据实际数据结构进行过滤
                if selectedCategory == "应用" {
                    filteredApps = filteredApps.filter { $0.type == 0 }
                } else if selectedCategory == "游戏" {
                    filteredApps = filteredApps.filter { $0.type == 1 }
                }
                // 其他分类筛选...
            }
            
            // 应用付费筛选
            if selectedPriceFilter != "全部" {
                // 付费筛选逻辑，这里假设lock字段表示付费状态
                if selectedPriceFilter == "免费" {
                    filteredApps = filteredApps.filter { !$0.isLocked }
                } else if selectedPriceFilter == "收费" {
                    filteredApps = filteredApps.filter { $0.isLocked }
                }
            }
            
            // 应用排序
            if selectedSortOption == "最新" {
                filteredApps.sort { app1, app2 in
                    return app1.versionDate > app2.versionDate
                }
            } else if selectedSortOption == "最旧" {
                filteredApps.sort { app1, app2 in
                    return app1.versionDate < app2.versionDate
                }
            }
            
            apps = filteredApps
            collectionView.reloadData()
        }
    }
    
    // 设置空状态视图
    private func setupEmptyStateView() {
        if apps.isEmpty && !isLoading {
            if emptyStateView == nil {
                let emptyView = UIView()
                emptyView.translatesAutoresizingMaskIntoConstraints = false
                
                let stackView = UIStackView()
                stackView.axis = .vertical
                stackView.spacing = 16
                stackView.alignment = .center
                stackView.translatesAutoresizingMaskIntoConstraints = false
                
                let imageView = UIImageView(image: UIImage(systemName: "square.grid.2x2"))
                imageView.tintColor = .systemGray3
                imageView.contentMode = .scaleAspectFit
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.heightAnchor.constraint(equalToConstant: 80).isActive = true
                imageView.widthAnchor.constraint(equalToConstant: 80).isActive = true
                
                let titleLabel = UILabel()
                titleLabel.text = "没有找到应用"
                titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
                titleLabel.textColor = .label
                
                let descLabel = UILabel()
                descLabel.text = "尝试调整筛选条件，或刷新页面"
                descLabel.font = UIFont.systemFont(ofSize: 16)
                descLabel.textColor = .secondaryLabel
                descLabel.textAlignment = .center
                descLabel.numberOfLines = 0
                
                let refreshButton = UIButton(type: .system)
                refreshButton.setTitle("刷新", for: .normal)
                refreshButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
                refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                refreshButton.backgroundColor = .systemBlue
                refreshButton.setTitleColor(.white, for: .normal)
                refreshButton.tintColor = .white
                refreshButton.layer.cornerRadius = 20
                
                if #available(iOS 15.0, *) {
                    var config = UIButton.Configuration.filled()
                    config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
                    config.image = UIImage(systemName: "arrow.clockwise")
                    config.imagePlacement = .leading
                    config.imagePadding = 8
                    config.title = "刷新"
                    config.baseBackgroundColor = .systemBlue
                    config.baseForegroundColor = .white
                    refreshButton.configuration = config
                } else {
                    refreshButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
                }
                
                refreshButton.addTarget(self, action: #selector(refreshData), for: .touchUpInside)
                
                stackView.addArrangedSubview(imageView)
                stackView.addArrangedSubview(titleLabel)
                stackView.addArrangedSubview(descLabel)
                stackView.addArrangedSubview(refreshButton)
                
                emptyView.addSubview(stackView)
                
                NSLayoutConstraint.activate([
                    stackView.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
                    stackView.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor, constant: -50),
                    stackView.leadingAnchor.constraint(greaterThanOrEqualTo: emptyView.leadingAnchor, constant: 40),
                    stackView.trailingAnchor.constraint(lessThanOrEqualTo: emptyView.trailingAnchor, constant: -40)
                ])
                
                collectionView.backgroundView = emptyView
                emptyStateView = emptyView
            }
        } else {
            collectionView.backgroundView = nil
            emptyStateView = nil
        }
    }
    
    // MARK: - 数据操作
    
    private func loadData() {
        guard !isLoading else { return }
        isLoading = true
        
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
        
        // 获取UDID
        let udid = UserDefaults.standard.string(forKey: "deviceUDID") ?? ""
        
        // 构建请求URL
        var urlComponents = URLComponents(string: sourceURL)
        var queryItems = urlComponents?.queryItems ?? []
        
        // 添加UDID参数
        if !udid.isEmpty {
            queryItems.append(URLQueryItem(name: "udid", value: udid))
        }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            showError(message: "无效的URL")
            isLoading = false
            return
        }
        
        // 发起网络请求
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.refreshControl.endRefreshing()
                
                // 恢复筛选按钮
                let filterButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle.fill"), style: .plain, target: self, action: #selector(self?.toggleFilterView))
                let downloadLinkButton = UIBarButtonItem(image: UIImage(systemName: "link.badge.plus"), style: .plain, target: self, action: #selector(self?.showURLInputDialogAction))
                self?.navigationItem.rightBarButtonItems = [filterButton, downloadLinkButton]
                
                if let error = error {
                    self?.showError(message: "网络错误: \(error.localizedDescription)")
                    self?.setupEmptyStateView()
                    return
                }
                
                guard let data = data else {
                    self?.showError(message: "没有返回数据")
                    self?.setupEmptyStateView()
                    return
                }
                
                do {
                    // 使用JSONDecoder解析数据，而不是JSONSerialization
                    if let jsonString = String(data: data, encoding: .utf8),
                       let jsonData = jsonString.data(using: .utf8) {
                        let decoder = JSONDecoder()
                        if let storeData = try? decoder.decode(StoreAppStoreData.self, from: jsonData) {
                            self?.appStoreData = storeData
                            self?.apps = storeData.apps
                            
                            // 设置顶部公告
                            if !storeData.message.isEmpty {
                                self?.setupAnnouncementView(withMessage: storeData.message)
                            }
                            
                            self?.collectionView.reloadData()
                            self?.setupEmptyStateView()
                            return
                        }
                    }
                    
                    // 备用解码方法：JSONSerialization + 自定义decode
                    guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw NSError(domain: "数据格式错误", code: -1, userInfo: nil)
                    }
                    
                    // 使用安全的静态解码方法
                    guard let storeData = StoreAppStoreData.decode(from: jsonObject) else {
                        throw NSError(domain: "数据解析失败", code: -2, userInfo: nil)
                    }
                    
                    self?.appStoreData = storeData
                    self?.apps = storeData.apps
                    
                    // 设置顶部公告
                    if !storeData.message.isEmpty {
                        self?.setupAnnouncementView(withMessage: storeData.message)
                    }
                    
                    self?.collectionView.reloadData()
                    self?.setupEmptyStateView()
                    
                } catch {
                    self?.showError(message: "数据解析错误: \(error.localizedDescription)")
                    self?.setupEmptyStateView()
                }
            }
        }.resume()
    }
    
    @objc private func refreshData() {
        loadData()
    }
    
    // 通用下载方法，处理各种链接类型
    func downloadIPAFromURL(urlString: String) {
        // 显示加载指示器
        let loadingAlert = UIAlertController(title: nil, message: "正在解析链接...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // 创建一个会处理重定向的URL会话配置
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        guard let url = URL(string: urlString) else {
            loadingAlert.dismiss(animated: true) {
                self.showError(message: "无效的URL")
            }
            return
        }
        
        // 创建一个请求，我们会跟踪重定向
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // 先用HEAD请求检查文件类型和大小
        
        session.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    loadingAlert.dismiss(animated: true) {
                        self?.showError(message: "链接检查失败: \(error.localizedDescription)")
                    }
                    return
                }
                
                // 获取最终URL（处理重定向后）
                guard let httpResponse = response as? HTTPURLResponse,
                      let finalURL = response?.url else {
                    loadingAlert.dismiss(animated: true) {
                        self?.showError(message: "无法获取文件信息")
                    }
                    return
                }
                
                // 检查内容类型和文件名
                let contentType = httpResponse.allHeaderFields["Content-Type"] as? String ?? ""
                let filename = self?.extractFilename(from: httpResponse) ?? "下载文件.ipa"
                let isIPA = filename.hasSuffix(".ipa") || contentType.contains("application/octet-stream")
                
                if !isIPA {
                    loadingAlert.message = "正在分析页面..."
                    
                    // 如果不是直接IPA文件，尝试解析页面内容
                    self?.analyzeWebPage(url: finalURL, session: session) { result in
                        DispatchQueue.main.async {
                            loadingAlert.dismiss(animated: true) {
                                switch result {
                                case .success(let downloadURL):
                                    self?.startIPADownload(from: downloadURL, filename: filename)
                                case .failure(let error):
                                    self?.showError(message: "链接解析失败: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                } else {
                    // 直接是IPA文件，开始下载
                    loadingAlert.dismiss(animated: true) {
                        self?.startIPADownload(from: finalURL, filename: filename)
                    }
                }
            }
        }.resume()
    }
    
    // 从HTTP响应中提取文件名
    private func extractFilename(from response: HTTPURLResponse) -> String? {
        // 从Content-Disposition头中获取文件名
        if let disposition = response.allHeaderFields["Content-Disposition"] as? String {
            let components = disposition.components(separatedBy: "filename=")
            if components.count > 1 {
                let filename = components[1].replacingOccurrences(of: "\"", with: "")
                if filename.hasSuffix(".ipa") {
                    return filename
                }
            }
        }
        
        // 从URL路径中获取文件名
        let urlPath = response.url?.path ?? ""
        let components = urlPath.components(separatedBy: "/")
        if let lastComponent = components.last, lastComponent.hasSuffix(".ipa") {
            return lastComponent
        }
        
        // 默认文件名
        return "download_\(Int(Date().timeIntervalSince1970)).ipa"
    }
    
    // 分析网页内容，寻找IPA下载链接
    private func analyzeWebPage(url: URL, session: URLSession, completion: @escaping (Result<URL, Error>) -> Void) {
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                let error = NSError(domain: "无法解析页面内容", code: -2, userInfo: nil)
                completion(.failure(error))
                return
            }
            
            // 查找可能的下载链接
            let possibleLinks = self.extractDownloadLinks(from: html, baseURL: url)
            
            if let ipaLink = possibleLinks.first {
                completion(.success(ipaLink))
            } else {
                // 如果未能找到标准下载链接，尝试处理特殊网站
                self.handleSpecialSite(url: url, html: html) { result in
                    switch result {
                    case .success(let downloadURL):
                        completion(.success(downloadURL))
                    case .failure(_):
                        // 如果特殊网站处理也失败，返回原始错误
                        let error = NSError(domain: "未找到IPA下载链接", code: -3, userInfo: nil)
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    // 从HTML中提取可能的IPA下载链接
    private func extractDownloadLinks(from html: String, baseURL: URL) -> [URL] {
        var links: [URL] = []
        
        // 1. 查找常见的下载按钮或链接
        let downloadPatterns = [
            // 直接IPA文件链接
            "href=[\"'](.*?\\.ipa)[\"']",
            // 下载关键词链接
            "href=[\"'](.*?download.*?)[\"']",
            "href=[\"'](.*?/download/.*?)[\"']",
            // 数据属性链接
            "data-url=[\"'](.*?)[\"']",
            "url: [\"'](.*?)[\"']",
            // JavaScript链接
            "window.location.href=[\"'](.*?)[\"']",
            "location.href=[\"'](.*?)[\"']",
            // 更多常见链接模式
            "href=[\"'](.*?/file/.*?)[\"']",
            "href=[\"'](.*?get\\?.*?)[\"']",
            "src=[\"'](.*?\\.ipa)[\"']",
            "content=[\"'](.*?\\.ipa)[\"']",
            // MIME类型相关
            "href=[\"'](.*?)[\"'].*?type=[\"']application/octet-stream[\"']",
            "href=[\"'](.*?)[\"'].*?type=[\"']application/x-itunes-ipa[\"']",
            // plist文件 (可能指向IPA)
            "href=[\"'](.*?\\.plist)[\"']"
        ]
        
        for pattern in downloadPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(html.startIndex..<html.endIndex, in: html)
                let matches = regex.matches(in: html, options: [], range: range)
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: html) {
                        let urlString = String(html[range])
                        if let url = URL(string: urlString, relativeTo: baseURL) {
                            links.append(url)
                        }
                    }
                }
            }
        }
        
        // 2. 寻找可能的JSON数据中的下载链接
        if let jsonDataRange = html.range(of: "\\{[^\\{\\}]*\"download\"[^\\{\\}]*\\}", options: .regularExpression) {
            let jsonData = String(html[jsonDataRange])
            if let urlMatch = jsonData.range(of: "\"url\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
                // 提取URL部分
                let matchedText = jsonData[urlMatch]
                if let urlValueRange = matchedText.range(of: "\"([^\"]+)\"", options: .regularExpression) {
                    // 去掉引号
                    let urlWithQuotes = String(matchedText[urlValueRange])
                    let urlString = urlWithQuotes.replacingOccurrences(of: "\"", with: "")
                    if let url = URL(string: urlString, relativeTo: baseURL) {
                        links.append(url)
                    }
                }
            }
        }
        
        // 3. 特别处理蓝奏云等特定网站
        if baseURL.host?.contains("lanzou") == true || baseURL.host?.contains("123") == true {
            // 特别处理蓝奏云
            if let ajaxDataRange = html.range(of: "var ajaxdata = '(.+?)'", options: .regularExpression),
               let _ = html[ajaxDataRange].split(separator: "'").dropFirst().first {
                
                let domain = "\(baseURL.scheme ?? "https")://\(baseURL.host ?? "www.123912.com")"
                if let ajaxURL = URL(string: "\(domain)/ajaxm.php") {
                    links.append(ajaxURL)
                }
            }
        }
        
        return links
    }
    
    // 开始下载IPA文件
    private func startIPADownload(from url: URL, filename: String) {
        // 显示下载确认对话框
        let alert = UIAlertController(
            title: "下载IPA",
            message: "确定要下载\(filename)吗？下载后将自动保存至IPA库。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        alert.addAction(UIAlertAction(title: "下载", style: .default) { [weak self] _ in
            // 显示下载进度
            let progressAlert = UIAlertController(title: "正在下载", message: "请稍候...", preferredStyle: .alert)
            
            let progressView = UIProgressView(progressViewStyle: .default)
            progressView.frame = CGRect(x: 10, y: 70, width: 250, height: 2)
            progressView.progress = 0.0
            progressAlert.view.addSubview(progressView)
            
            self?.present(progressAlert, animated: true)
            
            // 创建下载任务
            let downloadTask = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
                DispatchQueue.main.async {
                    progressAlert.dismiss(animated: true) {
                        if let error = error {
                            self?.showError(message: "下载失败: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let tempURL = tempURL else {
                            self?.showError(message: "下载失败: 无法获取文件")
                            return
                        }
                        
                        do {
                            // 创建IPA库目录
                            let fileManager = FileManager.default
                            let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                            let ipaLibraryURL = documentsURL.appendingPathComponent("IPALibrary", isDirectory: true)
                            
                            if !fileManager.fileExists(atPath: ipaLibraryURL.path) {
                                try fileManager.createDirectory(at: ipaLibraryURL, withIntermediateDirectories: true)
                            }
                            
                            // 创建文件名（使用应用名称和版本）
                            let cleanFilename = filename.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_")
                            let fileURL = ipaLibraryURL.appendingPathComponent(cleanFilename)
                            
                            // 如果文件已存在，先删除
                            if fileManager.fileExists(atPath: fileURL.path) {
                                try fileManager.removeItem(at: fileURL)
                            }
                            
                            // 将下载的文件移动到IPA库
                            try fileManager.moveItem(at: tempURL, to: fileURL)
                            
                            // 成功保存后，自动触发导入流程
                            self?.importIPAFile(at: fileURL)
                            
                            // 通知IPA库更新
                            NotificationCenter.default.post(name: NSNotification.Name("IPALibraryUpdated"), object: nil)
                            
                        } catch {
                            self?.showError(message: "保存失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            // 观察下载进度
            let observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
                DispatchQueue.main.async {
                    progressView.progress = Float(progress.fractionCompleted)
                    progressAlert.message = "下载中...(\(Int(progress.fractionCompleted * 100))%)"
                }
            }
            
            // 开始下载
            downloadTask.resume()
            
            // 在适当的时候，可以释放观察者
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                observation.invalidate()
            }
        })
        
        present(alert, animated: true)
    }
    
    // 修改importIPAFile方法，直接调用AppDelegate中的自动导入流程
    private func importIPAFile(at fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            showError(message: "无法找到IPA文件")
            return
        }
        
        // 显示加载提示
        let loadingAlert = UIAlertController(title: nil, message: "正在导入IPA...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // 在后台线程中处理导入
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // 使用随机UUID避免文件名冲突
                let uuid = UUID().uuidString
                let dl = AppDownload()
                
                // 使用全局处理函数进行IPA导入
                try handleIPAFile(destinationURL: fileURL, uuid: uuid, dl: dl)
                
                DispatchQueue.main.async {
                    // 关闭加载提示
                    loadingAlert.dismiss(animated: true) {
                        // 查找新导入的应用
                        if let downloadedApp = CoreDataManager.shared.getDatedDownloadedApps().first(where: { $0.uuid == uuid }) {
                            // 发送通知给LibraryViewController处理
                            NotificationCenter.default.post(
                                name: Notification.Name("InstallDownloadedApp"),
                                object: nil,
                                userInfo: ["downloadedApp": downloadedApp]
                            )
                            
                            // 显示成功消息
                            self?.showMessage(title: "导入成功", message: "IPA文件已导入并准备安装")
                            
                            // 切换到Library标签页
                            if let tabBarController = self?.tabBarController {
                                tabBarController.selectedIndex = 1
                            }
                        } else {
                            self?.showMessage(title: "导入完成", message: "IPA文件已导入到应用库")
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self?.showError(message: "导入IPA文件失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func showUnlockDialog() {
        let alertController = UIAlertController(title: "解锁应用", message: "请输入解锁码", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "解锁码"
            textField.autocapitalizationType = .none
            textField.clearButtonMode = .whileEditing
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        let unlockAction = UIAlertAction(title: "解锁", style: .default) { [weak self, weak alertController] _ in
            guard let code = alertController?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !code.isEmpty else {
                return
            }
            
            self?.unlockApp(code: code)
        }
        
        // 添加跳转到购买页面的按钮
        if let payURL = appStoreData?.payURL, !payURL.isEmpty, let url = URL(string: payURL) {
            let buyAction = UIAlertAction(title: "购买解锁码", style: .default) { [weak self] _ in
                let safariVC = SFSafariViewController(url: url)
                self?.present(safariVC, animated: true)
            }
            alertController.addAction(buyAction)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(unlockAction)
        
        present(alertController, animated: true)
    }
    
    private func unlockApp(code: String) {
        // 获取UDID
        guard let udid = UserDefaults.standard.string(forKey: "deviceUDID"), !udid.isEmpty else {
            showError(message: "无法获取设备UDID，请先获取UDID")
            return
        }
        
        // 构建解锁请求URL
        var urlComponents = URLComponents(string: sourceURL)
        var queryItems = urlComponents?.queryItems ?? []
        
        // 添加UDID和code参数
        queryItems.append(URLQueryItem(name: "udid", value: udid))
        queryItems.append(URLQueryItem(name: "code", value: code))
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            showError(message: "无效的URL")
            return
        }
        
        // 显示加载指示器
        let loadingAlert = UIAlertController(title: nil, message: "正在验证...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // 发起解锁请求
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if let error = error {
                        self?.showError(message: "网络错误: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data else {
                        self?.showError(message: "没有返回数据")
                        return
                    }
                    
                    do {
                        // 使用JSONSerialization解析数据
                        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let codeValue = jsonObject["code"] as? Int,
                              let msgValue = jsonObject["msg"] as? String else {
                            throw NSError(domain: "无效的响应格式", code: -1, userInfo: nil)
                        }
                        
                        // 创建响应对象
                        let unlockResponse = StoreUnlockResponse(code: codeValue, msg: msgValue)
                        
                        // 判断解锁结果
                        if unlockResponse.code == 0 {
                            // 解锁成功，刷新数据
                            self?.showMessage(title: "解锁成功", message: unlockResponse.msg) {
                                self?.loadData()
                            }
                        } else {
                            // 解锁失败
                            self?.showError(message: unlockResponse.msg)
                        }
                        
                    } catch {
                        self?.showError(message: "数据解析错误: \(error.localizedDescription)")
                    }
                }
            }
        }.resume()
    }
    
    private func showDetailForApp(_ app: StoreApp) {
        let alertController = UIAlertController(
            title: app.name,
            message: "版本: \(app.version)\n更新日期: \(formatDate(app.versionDate))\n\n\(app.versionDescription)",
            preferredStyle: .alert
        )
        
        // 根据应用锁定状态添加不同的操作按钮
        if app.isLocked {
            alertController.addAction(UIAlertAction(title: "解锁", style: .default) { [weak self] _ in
                self?.showUnlockDialog()
            })
        } else {
            alertController.addAction(UIAlertAction(title: "下载", style: .default) { [weak self] _ in
                // 确保下载URL不为空
                if !app.downloadURL.isEmpty {
                    self?.downloadIPAFromURL(urlString: app.downloadURL)
                } else {
                    self?.showError(message: "下载链接无效")
                }
            })
        }
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    // MARK: - 辅助方法
    
    private func formatDate(_ dateString: String) -> String {
        // 将日期字符串转换为更友好的格式
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        guard let date = dateFormatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
    
    private func showError(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showMessage(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    // 处理蓝奏云等特殊网站
    private func handleSpecialSite(url: URL, html: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // 获取域名信息，用于识别网站类型
        let host = url.host?.lowercased() ?? ""
        
        // 蓝奏云特殊处理
        if host.contains("lanzou") || host.contains("lanzoux") || host.contains("lanzoui") {
            // 解析蓝奏云页面
            if let range = html.range(of: "var ajaxdata = '(.+?)'", options: .regularExpression) {
                let ajaxData = String(html[range].dropFirst(14).dropLast(1))
                
                // 构建API请求参数
                let domain = "\(url.scheme ?? "https")://\(url.host ?? "")"
                let apiURL = "\(domain)/ajaxm.php"
                
                var request = URLRequest(url: URL(string: apiURL)!)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = "action=downprocess&sign=\(ajaxData)&ves=1".data(using: .utf8)
                
                // 获取真实下载链接
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    guard let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let downloadURLString = json["url"] as? String,
                          let downloadURL = URL(string: downloadURLString) else {
                        let error = NSError(domain: "解析下载链接失败", code: -3, userInfo: nil)
                        completion(.failure(error))
                        return
                    }
                    
                    completion(.success(downloadURL))
                }.resume()
                return
            }
        }
        
        // 123云盘特殊处理
        else if host.contains("123pan") || host.contains("123") {
            // 查找包含文件信息的JSON数据
            let pattern = "window\\.locals\\s*=\\s*\\{(.+?)\\};"
            if let range = html.range(of: pattern, options: .regularExpression) {
                let jsonStr = String(html[range])
                
                // 提取文件ID和其他必要信息
                var fileId: String?
                var shareKey: String?
                
                // 寻找ItemId
                if let idMatch = jsonStr.range(of: "\"ItemId\":\\s*\"([^\"]+)\"", options: .regularExpression) {
                    let matchedIdText = jsonStr[idMatch]
                    // 使用正则表达式提取双引号中间的内容
                    if let valueRange = matchedIdText.range(of: "\"([^\"]+)\"", options: .regularExpression, range: matchedIdText.range(of: ":")!.upperBound..<matchedIdText.endIndex) {
                        let idWithQuotes = String(matchedIdText[valueRange])
                        fileId = idWithQuotes.replacingOccurrences(of: "\"", with: "")
                    }
                }
                
                // 寻找ShareKey
                if let keyMatch = jsonStr.range(of: "\"ShareKey\":\\s*\"([^\"]+)\"", options: .regularExpression) {
                    let matchedKeyText = jsonStr[keyMatch]
                    // 使用正则表达式提取双引号中间的内容
                    if let valueRange = matchedKeyText.range(of: "\"([^\"]+)\"", options: .regularExpression, range: matchedKeyText.range(of: ":")!.upperBound..<matchedKeyText.endIndex) {
                        let keyWithQuotes = String(matchedKeyText[valueRange])
                        shareKey = keyWithQuotes.replacingOccurrences(of: "\"", with: "")
                    }
                }
                
                if let fileId = fileId, let shareKey = shareKey {
                    // 构建API请求
                    let apiURL = "https://www.123pan.com/api/share/download/file"
                    var request = URLRequest(url: URL(string: apiURL)!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let requestBody: [String: Any] = [
                        "fileId": fileId,
                        "shareKey": shareKey,
                        "isFolder": false
                    ]
                    
                    if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) {
                        request.httpBody = jsonData
                        
                        URLSession.shared.dataTask(with: request) { data, response, error in
                            if let error = error {
                                completion(.failure(error))
                                return
                            }
                            
                            guard let data = data,
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let results = json["data"] as? [String: Any],
                                  let downloadURLString = results["downloadUrl"] as? String,
                                  let downloadURL = URL(string: downloadURLString) else {
                                let error = NSError(domain: "解析123云盘链接失败", code: -4, userInfo: nil)
                                completion(.failure(error))
                                return
                            }
                            
                            completion(.success(downloadURL))
                        }.resume()
                        return
                    }
                }
            }
        }
        
        // 天翼云盘特殊处理
        else if host.contains("cloud.189") {
            // 查找包含文件信息的参数
            if let accessTokenMatch = html.range(of: "accessToken\\s*=\\s*'([^']+)'", options: .regularExpression) {
                let matchedTokenText = html[accessTokenMatch]
                var accessToken = ""
                
                // 提取单引号中的内容
                if let valueRange = matchedTokenText.range(of: "'([^']+)'", options: .regularExpression) {
                    let tokenWithQuotes = String(matchedTokenText[valueRange])
                    accessToken = tokenWithQuotes.replacingOccurrences(of: "'", with: "")
                }
                
                // 从URL中提取文件ID
                let urlString = url.absoluteString
                if let fileIdMatch = urlString.range(of: "fileId=([^&]+)", options: .regularExpression) {
                    let matchedIdText = urlString[fileIdMatch]
                    var fileId = ""
                    
                    // 提取等号后面的内容
                    if let valueRange = matchedIdText.range(of: "=([^&]+)", options: .regularExpression) {
                        let fileIdWithEquals = String(matchedIdText[valueRange])
                        fileId = fileIdWithEquals.replacingOccurrences(of: "=", with: "")
                        
                        // 构建下载API请求
                        let apiURL = "https://cloud.189.cn/api/open/file/getFileDownloadUrl.action"
                        var components = URLComponents(string: apiURL)
                        components?.queryItems = [
                            URLQueryItem(name: "fileId", value: fileId),
                            URLQueryItem(name: "accessToken", value: accessToken)
                        ]
                        
                        if let requestURL = components?.url {
                            URLSession.shared.dataTask(with: requestURL) { data, response, error in
                                if let error = error {
                                    completion(.failure(error))
                                    return
                                }
                                
                                guard let data = data,
                                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                      let downloadURLString = json["fileDownloadUrl"] as? String,
                                      let downloadURL = URL(string: downloadURLString) else {
                                    let error = NSError(domain: "解析天翼云盘链接失败", code: -5, userInfo: nil)
                                    completion(.failure(error))
                                    return
                                }
                                
                                completion(.success(downloadURL))
                            }.resume()
                            return
                        }
                    }
                }
            }
        }
        
        // TODO: 可以添加更多特殊网站的处理逻辑
        
        // 如果没有特殊处理，返回失败
        completion(.failure(NSError(domain: "不支持的网站", code: -5, userInfo: nil)))
    }
    
    private func showURLInputDialog() {
        let alertController = UIAlertController(
            title: "输入下载链接",
            message: "请输入IPA文件的下载链接，支持直接链接或网盘分享链接",
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.placeholder = "https://example.com/app.ipa"
            textField.autocapitalizationType = .none
            textField.keyboardType = .URL
            textField.clearButtonMode = .whileEditing
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        let downloadAction = UIAlertAction(title: "下载", style: .default) { [weak self, weak alertController] _ in
            guard let link = alertController?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !link.isEmpty else {
                return
            }
            
            self?.downloadIPAFromURL(urlString: link)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(downloadAction)
        
        present(alertController, animated: true)
    }
    
    @objc private func showURLInputDialogAction() {
        showURLInputDialog()
    }
    
    // 添加处理方法
    @objc private func handleIPAImport(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let fileURL = userInfo["fileURL"] as? URL {
            // 执行实际的导入逻辑
            // ...
            
            // 发送通知告知IPA库刷新
            NotificationCenter.default.post(name: NSNotification.Name("ReloadIPALibrary"), object: nil)
        }
    }
}

// MARK: - UICollectionView 数据源与代理

extension ListCollectionViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return apps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? AppCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        let app = apps[indexPath.item]
        cell.configure(with: app)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let app = apps[indexPath.item]
        showDetailForApp(app)
    }
}

// MARK: - 自定义集合视图单元格

class AppCollectionViewCell: UICollectionViewCell {
    
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let versionLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let downloadButton = UIButton(type: .system)
    private let lockIconView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // 设置卡片外观
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        
        // 添加阴影效果
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.1
        layer.masksToBounds = false
        layer.cornerRadius = 16
        
        // 图标
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 16
        iconImageView.layer.masksToBounds = true
        iconImageView.backgroundColor = UIColor.systemGray6
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)
        
        // 名称标签
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textAlignment = .left
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        // 版本标签
        versionLabel.font = UIFont.systemFont(ofSize: 13)
        versionLabel.textColor = .secondaryLabel
        versionLabel.textAlignment = .left
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(versionLabel)
        
        // 描述标签
        descriptionLabel.font = UIFont.systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 2
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)
        
        // 下载按钮
        downloadButton.setImage(UIImage(systemName: "icloud.and.arrow.down"), for: .normal)
        downloadButton.tintColor = .systemBlue
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(downloadButton)
        
        // 锁定图标
        lockIconView.image = UIImage(systemName: "lock.fill")
        lockIconView.tintColor = .systemYellow
        lockIconView.contentMode = .scaleAspectFit
        lockIconView.isHidden = true
        lockIconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(lockIconView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            iconImageView.heightAnchor.constraint(equalTo: iconImageView.widthAnchor), // 1:1 宽高比
            
            nameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            versionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            versionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            downloadButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            downloadButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            downloadButton.widthAnchor.constraint(equalToConstant: 40),
            downloadButton.heightAnchor.constraint(equalToConstant: 40),
            
            lockIconView.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 8),
            lockIconView.trailingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: -8),
            lockIconView.widthAnchor.constraint(equalToConstant: 20),
            lockIconView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with app: StoreApp) {
        nameLabel.text = app.name
        versionLabel.text = "v\(app.version) · \(app.size)"
        descriptionLabel.text = app.versionDescription.isEmpty ? "暂无描述" : app.versionDescription
        
        // 设置锁定状态
        lockIconView.isHidden = !app.isLocked
        
        // 加载图标（如果有）
        if let iconURLString = app.iconURL {
            iconImageView.safeLoadImage(from: iconURLString, placeholder: UIImage(systemName: "square.fill"))
        } else {
            // 使用默认图标
            iconImageView.image = UIImage(systemName: "square.fill")
            iconImageView.tintColor = .systemBlue
            
            // 尝试使用自定义颜色
            if let tintHex = app.tintColor {
                let color = UIColor(hex: tintHex)
                iconImageView.tintColor = color
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        lockIconView.isHidden = true
    }
}

// MARK: - 辅助扩展

extension String {
    func heightWithConstrainedWidth(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        return ceil(boundingBox.height)
    }
}

// 软件源数据模型 - 删除NSSecureCoding，仅使用Codable
class StoreAppStoreData: Codable {
    let name: String
    let message: String
    let identifier: String
    let sourceURL: String?
    let sourceicon: String?
    let payURL: String
    let unlockURL: String
    let apps: [StoreApp]
    
    // 标准初始化方法
    init(name: String, message: String, identifier: String, sourceURL: String?, sourceicon: String?, payURL: String, unlockURL: String, apps: [StoreApp]) {
        self.name = name
        self.message = message
        self.identifier = identifier
        self.sourceURL = sourceURL
        self.sourceicon = sourceicon
        self.payURL = payURL
        self.unlockURL = unlockURL
        self.apps = apps
    }
    
    // 自定义解码方法 - 用于JSON解析
    static func decode(from jsonObject: [String: Any]) -> StoreAppStoreData? {
        guard let name = jsonObject["name"] as? String,
              let message = jsonObject["message"] as? String,
              let identifier = jsonObject["identifier"] as? String,
              let payURL = jsonObject["payURL"] as? String,
              let unlockURL = jsonObject["unlockURL"] as? String,
              let appsArray = jsonObject["apps"] as? [[String: Any]] else {
            return nil
        }
        
        // 构建应用数组
        var apps: [StoreApp] = []
        for appDict in appsArray {
            if let app = StoreApp.decode(from: appDict) {
                apps.append(app)
            }
        }
        
        return StoreAppStoreData(
            name: name,
            message: message,
            identifier: identifier,
            sourceURL: jsonObject["sourceURL"] as? String,
            sourceicon: jsonObject["sourceicon"] as? String,
            payURL: payURL,
            unlockURL: unlockURL,
            apps: apps
        )
    }
}

class StoreApp: Codable {
    let name: String
    let type: Int
    let version: String
    let versionDate: String
    let versionDescription: String
    let lock: String
    let downloadURL: String
    let isLanZouCloud: String
    let iconURL: String?
    let tintColor: String?
    let size: String
    
    var isLocked: Bool {
        return lock == "1"
    }
    
    // 标准初始化方法
    init(name: String, type: Int, version: String, versionDate: String, versionDescription: String, 
         lock: String, downloadURL: String, isLanZouCloud: String, iconURL: String?, tintColor: String?, size: String) {
        self.name = name
        self.type = type
        self.version = version
        self.versionDate = versionDate
        self.versionDescription = versionDescription
        self.lock = lock
        self.downloadURL = downloadURL
        self.isLanZouCloud = isLanZouCloud
        self.iconURL = iconURL
        self.tintColor = tintColor
        self.size = size
    }
    
    // 自定义解码方法 - 用于JSON解析
    static func decode(from dictionary: [String: Any]) -> StoreApp? {
        guard let name = dictionary["name"] as? String,
              let typeValue = dictionary["type"] as? Int,
              let version = dictionary["version"] as? String,
              let versionDate = dictionary["versionDate"] as? String,
              let versionDescription = dictionary["versionDescription"] as? String,
              let lock = dictionary["lock"] as? String,
              let downloadURL = dictionary["downloadURL"] as? String,
              let isLanZouCloud = dictionary["isLanZouCloud"] as? String,
              let size = dictionary["size"] as? String else {
            return nil
        }
        
        return StoreApp(
            name: name,
            type: typeValue,
            version: version,
            versionDate: versionDate,
            versionDescription: versionDescription,
            lock: lock,
            downloadURL: downloadURL,
            isLanZouCloud: isLanZouCloud,
            iconURL: dictionary["iconURL"] as? String,
            tintColor: dictionary["tintColor"] as? String,
            size: size
        )
    }
}

// 解锁响应模型
struct StoreUnlockResponse: Codable {
    let code: Int
    let msg: String
}

extension UIImageView {
    // 安全加载图片，避免使用NSObject解码
    func safeLoadImage(from urlString: String, placeholder: UIImage? = nil) {
        // 先设置占位图像
        if let placeholder = placeholder {
            self.image = placeholder
        }
        
        guard let url = URL(string: urlString) else { return }
        
        // 使用URLSession直接加载图像数据，避免使用不安全的NSObject解码
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                return
            }
            
            // 在主线程中更新UI
            DispatchQueue.main.async {
                if let image = UIImage(data: data) {
                    self.image = image
                }
            }
        }
        task.resume()
    }
}

