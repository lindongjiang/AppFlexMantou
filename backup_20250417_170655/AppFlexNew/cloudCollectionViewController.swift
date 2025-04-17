//
//  cloudCollectionViewController.swift
//  mantou
//
//  Created by mantou on 2025/3/28.
//

import UIKit

// 软件源卡片数据模型
struct SourceCard {
    let name: String
    let sourceURL: String
    let iconURL: String?
}

class CloudCollectionViewController: UIViewController {
    
    // MARK: - 属性
    
    private var collectionView: UICollectionView!
    private var sources: [SourceCard] = []
    private let cellIdentifier = "SourceCell"
    private var emptyStateView: UIView?
    
    // 用于在同一个TabBar页面切换的分段控制
    private let segmentedControl = UISegmentedControl(items: ["网站源", "软件源"])
    
    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSegmentedControl()
        configureNavBar()
        loadSavedSources()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSavedSources()
        
        // 确保选择了"软件源"标签
        segmentedControl.selectedSegmentIndex = 1
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
        
        // 计算每行显示的卡片数量和大小
        let screenWidth = UIScreen.main.bounds.width
        let itemsPerRow: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 1
        let availableWidth = screenWidth - layout.sectionInset.left - layout.sectionInset.right - (itemsPerRow - 1) * layout.minimumInteritemSpacing
        let itemWidth = availableWidth / itemsPerRow
        let itemHeight: CGFloat = 100 // 使用固定高度的卡片
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        
        // 创建CollectionView
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(SourceCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0) // 为分段控制留出空间
        view.addSubview(collectionView)
        
        // 添加下拉刷新控件
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .systemBlue
        refreshControl.addTarget(self, action: #selector(refreshSources), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    private func setupSegmentedControl() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.backgroundColor = .systemBackground
        segmentedControl.selectedSegmentTintColor = .systemBlue
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.systemBlue], for: .normal)
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        
        view.addSubview(segmentedControl)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            segmentedControl.heightAnchor.constraint(equalToConstant: 34)
        ])
    }
    
    private func configureNavBar() {
        title = "软件源"
        navigationController?.navigationBar.prefersLargeTitles = true
        
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
        
        // 添加右上角按钮
        let addButton = UIBarButtonItem(image: UIImage(systemName: "plus.circle.fill"), style: .plain, target: self, action: #selector(addSourceButtonTapped))
        navigationItem.rightBarButtonItem = addButton
    }
    
    // MARK: - 分段控制切换
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            // 网站源 - 切换到WebcloudCollectionViewController
            let webcloudVC = WebcloudCollectionViewController()
            // 保持相同的导航控制器，只替换当前视图控制器
            navigationController?.setViewControllers([webcloudVC], animated: false)
        } else {
            // 软件源 - 当前页面，刷新数据
            loadSavedSources()
        }
    }
    
    // 添加空状态视图
    private func setupEmptyStateView() {
        if sources.isEmpty {
            if emptyStateView == nil {
                let emptyView = UIView()
                emptyView.translatesAutoresizingMaskIntoConstraints = false
                
                let stackView = UIStackView()
                stackView.axis = .vertical
                stackView.spacing = 16
                stackView.alignment = .center
                stackView.translatesAutoresizingMaskIntoConstraints = false
                
                let imageView = UIImageView(image: UIImage(systemName: "cloud.fill"))
                imageView.tintColor = .systemGray3
                imageView.contentMode = .scaleAspectFit
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.heightAnchor.constraint(equalToConstant: 80).isActive = true
                imageView.widthAnchor.constraint(equalToConstant: 80).isActive = true
                
                let titleLabel = UILabel()
                titleLabel.text = "没有软件源"
                titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
                titleLabel.textColor = .label
                
                let descLabel = UILabel()
                descLabel.text = "点击右上角添加按钮来添加软件源"
                descLabel.font = UIFont.systemFont(ofSize: 16)
                descLabel.textColor = .secondaryLabel
                descLabel.textAlignment = .center
                descLabel.numberOfLines = 0
                
                let addButton = UIButton(type: .system)
                addButton.setTitle("添加软件源", for: .normal)
                addButton.setImage(UIImage(systemName: "plus"), for: .normal)
                addButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                addButton.backgroundColor = .systemBlue
                addButton.setTitleColor(.white, for: .normal)
                addButton.tintColor = .white
                addButton.layer.cornerRadius = 20
                addButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
                addButton.addTarget(self, action: #selector(addSourceButtonTapped), for: .touchUpInside)
                
                stackView.addArrangedSubview(imageView)
                stackView.addArrangedSubview(titleLabel)
                stackView.addArrangedSubview(descLabel)
                stackView.addArrangedSubview(addButton)
                
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
    
    @objc private func refreshSources() {
        loadSavedSources()
        collectionView.refreshControl?.endRefreshing()
    }
    
    // MARK: - 数据操作
    
    private func loadSavedSources() {
        // 从UserDefaults加载保存的源
        if let savedSources = UserDefaults.standard.array(forKey: "savedSources") as? [[String: String]] {
            sources = savedSources.compactMap { sourceDict in
                guard let name = sourceDict["name"],
                      let sourceURL = sourceDict["sourceURL"] else {
                    return nil
                }
                return SourceCard(name: name, sourceURL: sourceURL, iconURL: sourceDict["iconURL"])
            }
            collectionView.reloadData()
            setupEmptyStateView()
        }
    }
    
    private func saveSource(source: SourceCard) {
        // 转换为字典并保存到UserDefaults
        var sourcesArray = UserDefaults.standard.array(forKey: "savedSources") as? [[String: String]] ?? []
        let sourceDict: [String: String] = [
            "name": source.name,
            "sourceURL": source.sourceURL,
            "iconURL": source.iconURL ?? ""
        ]
        
        // 检查是否已存在相同URL的源
        if !sourcesArray.contains(where: { $0["sourceURL"] == source.sourceURL }) {
            sourcesArray.append(sourceDict)
            UserDefaults.standard.set(sourcesArray, forKey: "savedSources")
            sources.append(source)
            collectionView.reloadData()
        }
    }
    
    // MARK: - 操作响应
    
    @objc private func addSourceButtonTapped() {
        let alertController = UIAlertController(title: "添加软件源", message: "请输入软件源链接", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "https://example.com/appstore"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.clearButtonMode = .whileEditing
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        let addAction = UIAlertAction(title: "添加", style: .default) { [weak self] _ in
            guard let sourceURL = alertController.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !sourceURL.isEmpty else {
                return
            }
            
            self?.fetchSourceInfo(sourceURL: sourceURL)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(addAction)
        
        present(alertController, animated: true)
    }
    
    private func fetchSourceInfo(sourceURL: String) {
        // 显示加载指示器，使用现代的加载样式
        let loadingView = UIView(frame: view.bounds)
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        loadingView.alpha = 0
        
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        blurView.layer.cornerRadius = 20
        blurView.clipsToBounds = true
        blurView.center = loadingView.center
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = CGPoint(x: blurView.bounds.midX, y: blurView.bounds.midY - 20)
        activityIndicator.startAnimating()
        
        let loadingLabel = UILabel(frame: CGRect(x: 0, y: 0, width: blurView.frame.width, height: 30))
        loadingLabel.center = CGPoint(x: blurView.bounds.midX, y: blurView.bounds.midY + 30)
        loadingLabel.text = "正在加载..."
        loadingLabel.textAlignment = .center
        loadingLabel.textColor = .label
        
        blurView.contentView.addSubview(activityIndicator)
        blurView.contentView.addSubview(loadingLabel)
        loadingView.addSubview(blurView)
        
        view.addSubview(loadingView)
        
        UIView.animate(withDuration: 0.3) {
            loadingView.alpha = 1.0
        }
        
        // 创建URL请求
        guard let url = URL(string: sourceURL) else {
            UIView.animate(withDuration: 0.3, animations: {
                loadingView.alpha = 0
            }) { _ in
                loadingView.removeFromSuperview()
                self.showErrorAlert(message: "无效的URL")
            }
            return
        }
        
        // 获取UDID (如果有)
        let udid = UserDefaults.standard.string(forKey: "deviceUDID") ?? ""
        
        // 构建带UDID的请求URL
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if !udid.isEmpty {
            var queryItems = urlComponents?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "udid", value: udid))
            urlComponents?.queryItems = queryItems
        }
        
        guard let requestURL = urlComponents?.url else {
            UIView.animate(withDuration: 0.3, animations: {
                loadingView.alpha = 0
            }) { _ in
                loadingView.removeFromSuperview()
                self.showErrorAlert(message: "URL构建失败")
            }
            return
        }
        
        // 发起网络请求
        URLSession.shared.dataTask(with: requestURL) { [weak self] data, response, error in
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3, animations: {
                    loadingView.alpha = 0
                }) { _ in
                    loadingView.removeFromSuperview()
                    
                    if let error = error {
                        self?.showErrorAlert(message: "网络错误: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data else {
                        self?.showErrorAlert(message: "没有返回数据")
                        return
                    }
                    
                    do {
                        // 解析JSON数据
                        let decoder = JSONDecoder()
                        let storeData = try decoder.decode(AppStoreData.self, from: data)
                        
                        // 创建并保存源卡片
                        let sourceCard = SourceCard(
                            name: storeData.name,
                            sourceURL: sourceURL,
                            iconURL: storeData.sourceicon
                        )
                        self?.saveSource(source: sourceCard)
                        
                        // 显示源添加成功提示
                        let successAlert = UIAlertController(
                            title: "添加成功",
                            message: "成功添加软件源: \(storeData.name)",
                            preferredStyle: .alert
                        )
                        successAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self?.present(successAlert, animated: true)
                        
                        // 如果有公告消息，显示公告
                        if !storeData.message.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                let messageAlert = UIAlertController(
                                    title: "公告",
                                    message: storeData.message,
                                    preferredStyle: .alert
                                )
                                messageAlert.addAction(UIAlertAction(title: "确定", style: .default))
                                self?.present(messageAlert, animated: true)
                            }
                        }
                        
                    } catch {
                        self?.showErrorAlert(message: "数据解析错误: \(error.localizedDescription)")
                    }
                }
            }
        }.resume()
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionView 数据源与代理

extension CloudCollectionViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sources.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? SourceCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        let source = sources[indexPath.item]
        cell.configure(with: source)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let source = sources[indexPath.item]
        
        // 创建并推送应用列表视图控制器
        let listVC = ListCollectionViewController(sourceURL: source.sourceURL, sourceName: source.name)
        navigationController?.pushViewController(listVC, animated: true)
    }
}

// MARK: - 自定义集合视图单元格

class SourceCollectionViewCell: UICollectionViewCell {
    
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let urlLabel = UILabel()
    private let arrowImageView = UIImageView()
    
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
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 22
        iconImageView.layer.masksToBounds = true
        iconImageView.backgroundColor = UIColor.systemGray6
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)
        
        // 名称标签
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        nameLabel.textAlignment = .left
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        // URL标签
        urlLabel.font = UIFont.systemFont(ofSize: 14)
        urlLabel.textColor = .secondaryLabel
        urlLabel.textAlignment = .left
        urlLabel.numberOfLines = 1
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(urlLabel)
        
        // 添加右箭头图标
        arrowImageView.image = UIImage(systemName: "chevron.right")
        arrowImageView.tintColor = .tertiaryLabel
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(arrowImageView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 44),
            iconImageView.heightAnchor.constraint(equalToConstant: 44),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),
            
            urlLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            urlLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            urlLabel.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),
            urlLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
            
            arrowImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            arrowImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 16),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with source: SourceCard) {
        nameLabel.text = source.name
        urlLabel.text = source.sourceURL
        
        // 加载图标（如果有）
        if let iconURLString = source.iconURL, let iconURL = URL(string: iconURLString) {
            URLSession.shared.dataTask(with: iconURL) { [weak self] data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.iconImageView.image = image
                    }
                }
            }.resume()
        } else {
            // 使用默认图标
            iconImageView.image = UIImage(systemName: "cloud.fill")
            iconImageView.tintColor = .systemBlue
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
    }
}

// MARK: - 数据模型

// 软件源数据模型
struct AppStoreData: Codable {
    let name: String
    let message: String
    let identifier: String
    let sourceURL: String?
    let sourceicon: String?
    let payURL: String
    let unlockURL: String
    let apps: [App]
}

// 应用数据模型
struct App: Codable {
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
}

// 解锁响应模型
struct UnlockResponse: Codable {
    let code: Int
    let msg: String
}

