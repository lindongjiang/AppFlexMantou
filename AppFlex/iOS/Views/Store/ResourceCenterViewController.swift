//
//  ResourceCenterViewController.swift
//  AppFlex
//
//  Created by AppFlex Developer on 2025/4/17.
//

import UIKit
import WebKit
import Foundation

class ResourceCenterViewController: UIViewController {
    
    // MARK: - 属性
    
    private var collectionView: UICollectionView!
    private var resources: [ResourceCard] = []
    private let cellIdentifier = "ResourceCell"
    private var emptyStateView: UIView?
    
    private var jsonURL: String {
        return StringObfuscator.shared.getResourceConfigURL()
    }
    
    private var isLoading = false
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // 用于在同一个TabBar页面切换的分段控制
    private let segmentedControl = UISegmentedControl(items: ["内容资源", "应用资源"])
    
    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSegmentedControl()
        configureNavBar()
        fetchResourceData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if resources.isEmpty && !isLoading {
            fetchResourceData()
        }
        
        // 确保选择了"内容资源"标签
        segmentedControl.selectedSegmentIndex = 0
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
        let itemsPerRow: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        let availableWidth = screenWidth - layout.sectionInset.left - layout.sectionInset.right - (itemsPerRow - 1) * layout.minimumInteritemSpacing
        let itemWidth = availableWidth / itemsPerRow
        let itemHeight: CGFloat = 160 // 增加卡片高度以适应图片
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        
        // 创建CollectionView
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(ResourceCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0) // 为分段控制留出空间
        view.addSubview(collectionView)
        
        // 添加下拉刷新控件
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .systemBlue
        refreshControl.addTarget(self, action: #selector(refreshResources), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        // 配置加载指示器
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = .systemBlue
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupSegmentedControl() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = 0
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
        title = "资源中心"
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
        
        // 添加刷新按钮
        let refreshButton = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refreshResources))
        navigationItem.rightBarButtonItem = refreshButton
    }
    
    // 添加空状态视图
    private func setupEmptyStateView() {
        if resources.isEmpty && !isLoading {
            if emptyStateView == nil {
                let emptyView = UIView()
                emptyView.translatesAutoresizingMaskIntoConstraints = false
                
                let stackView = UIStackView()
                stackView.axis = .vertical
                stackView.spacing = 16
                stackView.alignment = .center
                stackView.translatesAutoresizingMaskIntoConstraints = false
                
                let imageView = UIImageView(image: UIImage(systemName: "globe"))
                imageView.tintColor = .systemGray3
                imageView.contentMode = .scaleAspectFit
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.heightAnchor.constraint(equalToConstant: 80).isActive = true
                imageView.widthAnchor.constraint(equalToConstant: 80).isActive = true
                
                let titleLabel = UILabel()
                titleLabel.text = "没有可用内容"
                titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
                titleLabel.textColor = .label
                
                let descLabel = UILabel()
                descLabel.text = "无法加载内容数据，请检查网络连接后重试"
                descLabel.font = UIFont.systemFont(ofSize: 16)
                descLabel.textColor = .secondaryLabel
                descLabel.textAlignment = .center
                descLabel.numberOfLines = 0
                
                let retryButton = UIButton(type: .system)
                retryButton.setTitle("重试", for: .normal)
                retryButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
                retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                retryButton.backgroundColor = .systemBlue
                retryButton.setTitleColor(.white, for: .normal)
                retryButton.tintColor = .white
                retryButton.layer.cornerRadius = 20
                retryButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
                retryButton.addTarget(self, action: #selector(refreshResources), for: .touchUpInside)
                
                stackView.addArrangedSubview(imageView)
                stackView.addArrangedSubview(titleLabel)
                stackView.addArrangedSubview(descLabel)
                stackView.addArrangedSubview(retryButton)
                
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
    
    @objc private func refreshResources() {
        fetchResourceData()
        collectionView.refreshControl?.endRefreshing()
    }
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            // 内容资源 - 当前页面
            fetchResourceData()
        } else {
            // 应用资源 - 切换到CloudCollectionViewController
            let cloudVC = CloudCollectionViewController()
            // 保持相同的导航控制器，只替换当前视图控制器
            navigationController?.setViewControllers([cloudVC], animated: false)
        }
    }
    
    // MARK: - 数据获取
    
    private func fetchResourceData() {
        guard !isLoading else { return }
        
        isLoading = true
        loadingIndicator.startAnimating()
        
        guard let url = URL(string: jsonURL) else {
            self.showErrorAlert(message: "无效的URL")
            self.isLoading = false
            self.loadingIndicator.stopAnimating()
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.loadingIndicator.stopAnimating()
                
                if let error = error {
                    self.showErrorAlert(message: "网络错误: \(error.localizedDescription)")
                    self.setupEmptyStateView()
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    self.showErrorAlert(message: "服务器返回错误")
                    self.setupEmptyStateView()
                    return
                }
                
                guard let data = data else {
                    self.showErrorAlert(message: "未收到数据")
                    self.setupEmptyStateView()
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let socialLinks = json["social_links"] as? [String: Any] {
                        
                        var newResources: [ResourceCard] = []
                        
                        // 解析更新后的JSON结构，支持图片
                        for (name, details) in socialLinks {
                            if let detailsDict = details as? [String: String] {
                                let url = detailsDict["url"] ?? ""
                                let imageURL = detailsDict["image"] ?? ""
                                newResources.append(ResourceCard(name: name, url: url, imageURL: imageURL))
                            } else if let url = details as? String {
                                // 向下兼容旧格式
                                newResources.append(ResourceCard(name: name, url: url, imageURL: nil))
                            }
                        }
                        
                        self.resources = newResources
                        self.collectionView.reloadData()
                        self.setupEmptyStateView()
                    } else {
                        self.showErrorAlert(message: "解析JSON数据失败")
                        self.setupEmptyStateView()
                    }
                } catch {
                    self.showErrorAlert(message: "JSON解析错误: \(error.localizedDescription)")
                    self.setupEmptyStateView()
                }
            }
        }
        
        task.resume()
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate

extension ResourceCenterViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return resources.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! ResourceCollectionViewCell
        
        let resource = resources[indexPath.item]
        cell.configure(with: resource)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let resource = resources[indexPath.item]
        
        // 创建ContentDetailViewController并显示所选内容
        let contentDetailVC = ContentDetailViewController()
        contentDetailVC.websiteURL = resource.url
        contentDetailVC.websiteName = resource.name
        navigationController?.pushViewController(contentDetailVC, animated: true)
    }
}

// ResourceCollectionViewCell 已移至 StoreModels.swift 