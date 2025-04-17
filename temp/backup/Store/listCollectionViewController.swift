
import UIKit
import SafariServices
import CoreData

class ListCollectionViewController: UIViewController {
    
    
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
    
    private let sourceURL: String
    private let sourceName: String
    
    private let categories = ["全部", "应用", "游戏", "影音", "工具", "插件"]
    private let priceFilters = ["全部", "免费", "收费"]
    private let sortOptions = ["默认", "最新", "最旧"]
    private var selectedCategory = "全部"
    private var selectedPriceFilter = "全部"
    private var selectedSortOption = "默认"
    
    
    init(sourceURL: String, sourceName: String) {
        self.sourceURL = sourceURL
        self.sourceName = sourceName
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
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
    
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        let screenWidth = UIScreen.main.bounds.width
        let itemsPerRow: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        let availableWidth = screenWidth - layout.sectionInset.left - layout.sectionInset.right - (itemsPerRow - 1) * layout.minimumInteritemSpacing
        let itemWidth = availableWidth / itemsPerRow
        let itemHeight = itemWidth * 1.4
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(AppCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true
        view.addSubview(collectionView)
        
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        refreshControl.tintColor = .systemBlue
        collectionView.refreshControl = refreshControl
    }
    
    private func configureNavBar() {
        title = sourceName
        navigationController?.navigationBar.prefersLargeTitles = false
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = .systemBlue
        
        let filterButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle.fill"), style: .plain, target: self, action: #selector(toggleFilterView))
        navigationItem.rightBarButtonItem = filterButton
        
        let downloadLinkButton = UIBarButtonItem(image: UIImage(systemName: "link.badge.plus"), style: .plain, target: self, action: #selector(showURLInputDialogAction))
        
        navigationItem.rightBarButtonItems = [filterButton, downloadLinkButton]
    }
    
    private func setupAnnouncementView(withMessage message: String) {
        guard !message.isEmpty else { return }
        
        let screenWidth = UIScreen.main.bounds.width
        let messageHeight = message.heightWithConstrainedWidth(width: screenWidth - 32, font: UIFont.systemFont(ofSize: 14))
        let announcementHeight: CGFloat = messageHeight + 32
        
        announcementView?.removeFromSuperview()
        
        announcementView = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: announcementHeight))
        announcementView?.backgroundColor = .secondarySystemBackground
        
        let blurEffect = UIBlurEffect(style: .systemThickMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: announcementHeight)
        announcementView?.addSubview(blurView)
        
        let iconImageView = UIImageView(image: UIImage(systemName: "megaphone.fill"))
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.frame = CGRect(x: 16, y: (announcementHeight - 24) / 2, width: 24, height: 24)
        blurView.contentView.addSubview(iconImageView)
        
        let messageLabel = UILabel(frame: CGRect(x: 50, y: 16, width: screenWidth - 66, height: messageHeight))
        messageLabel.text = message
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = .label
        blurView.contentView.addSubview(messageLabel)
        
        let separatorLine = UIView(frame: CGRect(x: 0, y: announcementHeight - 1, width: screenWidth, height: 1))
        separatorLine.backgroundColor = .separator
        blurView.contentView.addSubview(separatorLine)
        
        view.addSubview(announcementView!)
        
        collectionView.contentInset = UIEdgeInsets(top: announcementHeight, left: 0, bottom: 0, right: 0)
    }
    
    private func setupFilterView() {
        let screenWidth = UIScreen.main.bounds.width
        let filterHeight: CGFloat = 350 // 增加一点高度以容纳更好的UI
        
        filterView?.removeFromSuperview()
        
        let backgroundView = UIView(frame: view.bounds)
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        backgroundView.alpha = 0
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissFilterView))
        backgroundView.addGestureRecognizer(tapGesture)
        
        filterView = UIView(frame: CGRect(x: 0, y: view.bounds.height, width: screenWidth, height: filterHeight))
        filterView?.backgroundColor = .systemBackground
        filterView?.layer.cornerRadius = 20
        filterView?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        filterView?.layer.masksToBounds = true
        
        let handleView = UIView(frame: CGRect(x: (screenWidth - 40) / 2, y: 8, width: 40, height: 5))
        handleView.backgroundColor = .systemGray4
        handleView.layer.cornerRadius = 2.5
        filterView?.addSubview(handleView)
        
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 24, width: screenWidth, height: 30))
        titleLabel.text = "筛选和排序"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        filterView?.addSubview(titleLabel)
        
        let categoryLabel = createFilterSectionLabel(text: "分类", y: 70)
        filterView?.addSubview(categoryLabel)
        
        let categoryStackView = createFilterButtonGroup(items: categories, y: 100, selectedItem: selectedCategory, action: #selector(categorySelected(_:)))
        filterView?.addSubview(categoryStackView)
        
        let priceLabel = createFilterSectionLabel(text: "付费类型", y: 160)
        filterView?.addSubview(priceLabel)
        
        let priceStackView = createFilterButtonGroup(items: priceFilters, y: 190, selectedItem: selectedPriceFilter, action: #selector(priceFilterSelected(_:)))
        filterView?.addSubview(priceStackView)
        
        let sortLabel = createFilterSectionLabel(text: "排序方式", y: 250)
        filterView?.addSubview(sortLabel)
        
        let sortStackView = createFilterButtonGroup(items: sortOptions, y: 280, selectedItem: selectedSortOption, action: #selector(sortOptionSelected(_:)))
        filterView?.addSubview(sortStackView)
        
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
            
            button.layer.cornerRadius = 15
            button.layer.masksToBounds = true
            
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
            
            let buttonWidth = item.size(withAttributes: [.font: UIFont.systemFont(ofSize: 15, weight: .medium)]).width + 40
            totalWidth += buttonWidth + 12
        }
        
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        scrollView.contentSize = CGSize(width: totalWidth, height: 44)
        
        return scrollView
    }
    
    @objc private func dismissFilterView() {
        guard let filterView = self.filterView else { return }
        
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
        if let originalData = appStoreData?.apps {
            var filteredApps = originalData
            
            if selectedCategory != "全部" {
                if selectedCategory == "应用" {
                    filteredApps = filteredApps.filter { $0.type == 0 }
                } else if selectedCategory == "游戏" {
                    filteredApps = filteredApps.filter { $0.type == 1 }
                }
            }
            
            if selectedPriceFilter != "全部" {
                if selectedPriceFilter == "免费" {
                    filteredApps = filteredApps.filter { !$0.isLocked }
                } else if selectedPriceFilter == "收费" {
                    filteredApps = filteredApps.filter { $0.isLocked }
                }
            }
            
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
    
    
    private func loadData() {
        guard !isLoading else { return }
        isLoading = true
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
        
        let udid = UserDefaults.standard.string(forKey: "deviceUDID") ?? ""
        
        var urlComponents = URLComponents(string: sourceURL)
        var queryItems = urlComponents?.queryItems ?? []
        
        if !udid.isEmpty {
            queryItems.append(URLQueryItem(name: "udid", value: udid))
        }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            showError(message: "无效的URL")
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.refreshControl.endRefreshing()
                
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
                    if let jsonString = String(data: data, encoding: .utf8),
                       let jsonData = jsonString.data(using: .utf8) {
                        let decoder = JSONDecoder()
                        if let storeData = try? decoder.decode(StoreAppStoreData.self, from: jsonData) {
                            self?.appStoreData = storeData
                            self?.apps = storeData.apps
                            
                            if !storeData.message.isEmpty {
                                self?.setupAnnouncementView(withMessage: storeData.message)
                            }
                            
                            self?.collectionView.reloadData()
                            self?.setupEmptyStateView()
                            return
                        }
                    }
                    
                    guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw NSError(domain: "数据格式错误", code: -1, userInfo: nil)
                    }
                    
                    guard let storeData = StoreAppStoreData.decode(from: jsonObject) else {
                        throw NSError(domain: "数据解析失败", code: -2, userInfo: nil)
                    }
                    
                    self?.appStoreData = storeData
                    self?.apps = storeData.apps
                    
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
    
    func downloadIPAFromURL(urlString: String) {
        let loadingAlert = UIAlertController(title: nil, message: "正在解析链接...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        guard let url = URL(string: urlString) else {
            loadingAlert.dismiss(animated: true) {
                self.showError(message: "无效的URL")
            }
            return
        }
        
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
                
                guard let httpResponse = response as? HTTPURLResponse,
                      let finalURL = response?.url else {
                    loadingAlert.dismiss(animated: true) {
                        self?.showError(message: "无法获取文件信息")
                    }
                    return
                }
                
                let contentType = httpResponse.allHeaderFields["Content-Type"] as? String ?? ""
                let filename = self?.extractFilename(from: httpResponse) ?? "下载文件.ipa"
                let isIPA = filename.hasSuffix(".ipa") || contentType.contains("application/octet-stream")
                
                if !isIPA {
                    loadingAlert.message = "正在分析页面..."
                    
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
                    loadingAlert.dismiss(animated: true) {
                        self?.startIPADownload(from: finalURL, filename: filename)
                    }
                }
            }
        }.resume()
    }
    
    private func extractFilename(from response: HTTPURLResponse) -> String? {
        if let disposition = response.allHeaderFields["Content-Disposition"] as? String {
            let components = disposition.components(separatedBy: "filename=")
            if components.count > 1 {
                let filename = components[1].replacingOccurrences(of: "\"", with: "")
                if filename.hasSuffix(".ipa") {
                    return filename
                }
            }
        }
        
        let urlPath = response.url?.path ?? ""
        let components = urlPath.components(separatedBy: "/")
        if let lastComponent = components.last, lastComponent.hasSuffix(".ipa") {
            return lastComponent
        }
        
        return "download_\(Int(Date().timeIntervalSince1970)).ipa"
    }
    
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
            
            let possibleLinks = self.extractDownloadLinks(from: html, baseURL: url)
            
            if let ipaLink = possibleLinks.first {
                completion(.success(ipaLink))
            } else {
                self.handleSpecialSite(url: url, html: html) { result in
                    switch result {
                    case .success(let downloadURL):
                        completion(.success(downloadURL))
                    case .failure(_):
                        let error = NSError(domain: "未找到IPA下载链接", code: -3, userInfo: nil)
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    private func extractDownloadLinks(from html: String, baseURL: URL) -> [URL] {
        var links: [URL] = []
        
        let downloadPatterns = [
            "href=[\"'](.*?\\.ipa)[\"']",
            "href=[\"'](.*?download.*?)[\"']",
            "href=[\"'](.*?/download/.*?)[\"']",
            "data-url=[\"'](.*?)[\"']",
            "url: [\"'](.*?)[\"']",
            "window.location.href=[\"'](.*?)[\"']",
            "location.href=[\"'](.*?)[\"']",
            "href=[\"'](.*?/file/.*?)[\"']",
            "href=[\"'](.*?get\\?.*?)[\"']",
            "src=[\"'](.*?\\.ipa)[\"']",
            "content=[\"'](.*?\\.ipa)[\"']",
            "href=[\"'](.*?)[\"'].*?type=[\"']application/octet-stream[\"']",
            "href=[\"'](.*?)[\"'].*?type=[\"']application/x-itunes-ipa[\"']",
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
        
        if let jsonDataRange = html.range(of: "\\{[^\\{\\}]*\"download\"[^\\{\\}]*\\}", options: .regularExpression) {
            let jsonData = String(html[jsonDataRange])
            if let urlMatch = jsonData.range(of: "\"url\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
                let matchedText = jsonData[urlMatch]
                if let urlValueRange = matchedText.range(of: "\"([^\"]+)\"", options: .regularExpression) {
                    let urlWithQuotes = String(matchedText[urlValueRange])
                    let urlString = urlWithQuotes.replacingOccurrences(of: "\"", with: "")
                    if let url = URL(string: urlString, relativeTo: baseURL) {
                        links.append(url)
                    }
                }
            }
        }
        
        if baseURL.host?.contains("lanzou") == true || baseURL.host?.contains("123") == true {
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
    
    private func startIPADownload(from url: URL, filename: String) {
        let alert = UIAlertController(
            title: "下载IPA",
            message: "确定要下载\(filename)吗？下载后将自动保存至IPA库。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        alert.addAction(UIAlertAction(title: "下载", style: .default) { [weak self] _ in
            let progressAlert = UIAlertController(title: "正在下载", message: "请稍候...", preferredStyle: .alert)
            
            let progressView = UIProgressView(progressViewStyle: .default)
            progressView.frame = CGRect(x: 10, y: 70, width: 250, height: 2)
            progressView.progress = 0.0
            progressAlert.view.addSubview(progressView)
            
            self?.present(progressAlert, animated: true)
            
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
                            let fileManager = FileManager.default
                            let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                            let ipaLibraryURL = documentsURL.appendingPathComponent("IPALibrary", isDirectory: true)
                            
                            if !fileManager.fileExists(atPath: ipaLibraryURL.path) {
                                try fileManager.createDirectory(at: ipaLibraryURL, withIntermediateDirectories: true)
                            }
                            
                            let cleanFilename = filename.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_")
                            let fileURL = ipaLibraryURL.appendingPathComponent(cleanFilename)
                            
                            if fileManager.fileExists(atPath: fileURL.path) {
                                try fileManager.removeItem(at: fileURL)
                            }
                            
                            try fileManager.moveItem(at: tempURL, to: fileURL)
                            
                            self?.importIPAFile(at: fileURL)
                            
                            NotificationCenter.default.post(name: NSNotification.Name("IPALibraryUpdated"), object: nil)
                            
                        } catch {
                            self?.showError(message: "保存失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            let observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
                DispatchQueue.main.async {
                    progressView.progress = Float(progress.fractionCompleted)
                    progressAlert.message = "下载中...(\(Int(progress.fractionCompleted * 100))%)"
                }
            }
            
            downloadTask.resume()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                observation.invalidate()
            }
        })
        
        present(alert, animated: true)
    }
    
    private func importIPAFile(at fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            showError(message: "无法找到IPA文件")
            return
        }
        
        let loadingAlert = UIAlertController(title: nil, message: "正在导入IPA...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let uuid = UUID().uuidString
                let dl = AppDownload()
                
                try handleIPAFile(destinationURL: fileURL, uuid: uuid, dl: dl)
                
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        if let downloadedApp = CoreDataManager.shared.getDatedDownloadedApps().first(where: { $0.uuid == uuid }) {
                            NotificationCenter.default.post(
                                name: Notification.Name("InstallDownloadedApp"),
                                object: nil,
                                userInfo: ["downloadedApp": downloadedApp]
                            )
                            
                            self?.showMessage(title: "导入成功", message: "IPA文件已导入并准备安装")
                            
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
        guard let udid = UserDefaults.standard.string(forKey: "deviceUDID"), !udid.isEmpty else {
            showError(message: "无法获取设备UDID，请先获取UDID")
            return
        }
        
        var urlComponents = URLComponents(string: sourceURL)
        var queryItems = urlComponents?.queryItems ?? []
        
        queryItems.append(URLQueryItem(name: "udid", value: udid))
        queryItems.append(URLQueryItem(name: "code", value: code))
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            showError(message: "无效的URL")
            return
        }
        
        let loadingAlert = UIAlertController(title: nil, message: "正在验证...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
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
                        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let codeValue = jsonObject["code"] as? Int,
                              let msgValue = jsonObject["msg"] as? String else {
                            throw NSError(domain: "无效的响应格式", code: -1, userInfo: nil)
                        }
                        
                        let unlockResponse = StoreUnlockResponse(code: codeValue, msg: msgValue)
                        
                        if unlockResponse.code == 0 {
                            self?.showMessage(title: "解锁成功", message: unlockResponse.msg) {
                                self?.loadData()
                            }
                        } else {
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
        
        if app.isLocked {
            alertController.addAction(UIAlertAction(title: "解锁", style: .default) { [weak self] _ in
                self?.showUnlockDialog()
            })
        } else {
            alertController.addAction(UIAlertAction(title: "下载", style: .default) { [weak self] _ in
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
    
    
    private func formatDate(_ dateString: String) -> String {
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
    
    private func handleSpecialSite(url: URL, html: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let host = url.host?.lowercased() ?? ""
        
        if host.contains("lanzou") || host.contains("lanzoux") || host.contains("lanzoui") {
            if let range = html.range(of: "var ajaxdata = '(.+?)'", options: .regularExpression) {
                let ajaxData = String(html[range].dropFirst(14).dropLast(1))
                
                let domain = "\(url.scheme ?? "https")://\(url.host ?? "")"
                let apiURL = "\(domain)/ajaxm.php"
                
                var request = URLRequest(url: URL(string: apiURL)!)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = "action=downprocess&sign=\(ajaxData)&ves=1".data(using: .utf8)
                
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
        
        else if host.contains("123pan") || host.contains("123") {
            let pattern = "window\\.locals\\s*=\\s*\\{(.+?)\\};"
            if let range = html.range(of: pattern, options: .regularExpression) {
                let jsonStr = String(html[range])
                
                var fileId: String?
                var shareKey: String?
                
                if let idMatch = jsonStr.range(of: "\"ItemId\":\\s*\"([^\"]+)\"", options: .regularExpression) {
                    let matchedIdText = jsonStr[idMatch]
                    if let valueRange = matchedIdText.range(of: "\"([^\"]+)\"", options: .regularExpression, range: matchedIdText.range(of: ":")!.upperBound..<matchedIdText.endIndex) {
                        let idWithQuotes = String(matchedIdText[valueRange])
                        fileId = idWithQuotes.replacingOccurrences(of: "\"", with: "")
                    }
                }
                
                if let keyMatch = jsonStr.range(of: "\"ShareKey\":\\s*\"([^\"]+)\"", options: .regularExpression) {
                    let matchedKeyText = jsonStr[keyMatch]
                    if let valueRange = matchedKeyText.range(of: "\"([^\"]+)\"", options: .regularExpression, range: matchedKeyText.range(of: ":")!.upperBound..<matchedKeyText.endIndex) {
                        let keyWithQuotes = String(matchedKeyText[valueRange])
                        shareKey = keyWithQuotes.replacingOccurrences(of: "\"", with: "")
                    }
                }
                
                if let fileId = fileId, let shareKey = shareKey {
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
        
        else if host.contains("cloud.189") {
            if let accessTokenMatch = html.range(of: "accessToken\\s*=\\s*'([^']+)'", options: .regularExpression) {
                let matchedTokenText = html[accessTokenMatch]
                var accessToken = ""
                
                if let valueRange = matchedTokenText.range(of: "'([^']+)'", options: .regularExpression) {
                    let tokenWithQuotes = String(matchedTokenText[valueRange])
                    accessToken = tokenWithQuotes.replacingOccurrences(of: "'", with: "")
                }
                
                let urlString = url.absoluteString
                if let fileIdMatch = urlString.range(of: "fileId=([^&]+)", options: .regularExpression) {
                    let matchedIdText = urlString[fileIdMatch]
                    var fileId = ""
                    
                    if let valueRange = matchedIdText.range(of: "=([^&]+)", options: .regularExpression) {
                        let fileIdWithEquals = String(matchedIdText[valueRange])
                        fileId = fileIdWithEquals.replacingOccurrences(of: "=", with: "")
                        
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
    
    @objc private func handleIPAImport(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let _ = userInfo["fileURL"] as? URL {
            
            NotificationCenter.default.post(name: NSNotification.Name("ReloadIPALibrary"), object: nil)
        }
    }
}


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
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.1
        layer.masksToBounds = false
        layer.cornerRadius = 16
        
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 16
        iconImageView.layer.masksToBounds = true
        iconImageView.backgroundColor = UIColor.systemGray6
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)
        
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textAlignment = .left
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        versionLabel.font = UIFont.systemFont(ofSize: 13)
        versionLabel.textColor = .secondaryLabel
        versionLabel.textAlignment = .left
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(versionLabel)
        
        descriptionLabel.font = UIFont.systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 2
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)
        
        downloadButton.setImage(UIImage(systemName: "icloud.and.arrow.down"), for: .normal)
        downloadButton.tintColor = .systemBlue
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(downloadButton)
        
        lockIconView.image = UIImage(systemName: "lock.fill")
        lockIconView.tintColor = .systemYellow
        lockIconView.contentMode = .scaleAspectFit
        lockIconView.isHidden = true
        lockIconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(lockIconView)
        
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
        
        lockIconView.isHidden = !app.isLocked
        
        if let iconURLString = app.iconURL {
            iconImageView.safeLoadImage(from: iconURLString, placeholder: UIImage(systemName: "square.fill"))
        } else {
            iconImageView.image = UIImage(systemName: "square.fill")
            iconImageView.tintColor = .systemBlue
            
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


extension String {
    func heightWithConstrainedWidth(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        return ceil(boundingBox.height)
    }
}

class StoreAppStoreData: Codable {
    let name: String
    let message: String
    let identifier: String
    let sourceURL: String?
    let sourceicon: String?
    let payURL: String
    let unlockURL: String
    let apps: [StoreApp]
    
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
    
    static func decode(from jsonObject: [String: Any]) -> StoreAppStoreData? {
        guard let name = jsonObject["name"] as? String,
              let message = jsonObject["message"] as? String,
              let identifier = jsonObject["identifier"] as? String,
              let payURL = jsonObject["payURL"] as? String,
              let unlockURL = jsonObject["unlockURL"] as? String,
              let appsArray = jsonObject["apps"] as? [[String: Any]] else {
            return nil
        }
        
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

struct StoreUnlockResponse: Codable {
    let code: Int
    let msg: String
}

extension UIImageView {
    func safeLoadImage(from urlString: String, placeholder: UIImage? = nil) {
        if let placeholder = placeholder {
            self.image = placeholder
        }
        
        guard let url = URL(string: urlString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                return
            }
            
            DispatchQueue.main.async {
                if let image = UIImage(data: data) {
                    self.image = image
                }
            }
        }
        task.resume()
    }
}

