
import UIKit

struct SourceCard {
    let name: String
    let sourceURL: String
    let iconURL: String?
}

class CloudCollectionViewController: UIViewController {
    
    
    private var collectionView: UICollectionView!
    private var sources: [SourceCard] = []
    private let cellIdentifier = "SourceCell"
    private var emptyStateView: UIView?
    
    private let segmentedControl = UISegmentedControl(items: ["网站源", "软件源"])
    
    
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
        
        segmentedControl.selectedSegmentIndex = 1
    }
    
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        let screenWidth = UIScreen.main.bounds.width
        let itemsPerRow: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 1
        let availableWidth = screenWidth - layout.sectionInset.left - layout.sectionInset.right - (itemsPerRow - 1) * layout.minimumInteritemSpacing
        let itemWidth = availableWidth / itemsPerRow
        let itemHeight: CGFloat = 100 // 使用固定高度的卡片
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(SourceCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0) // 为分段控制留出空间
        view.addSubview(collectionView)
        
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
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = .systemBlue
        
        let addButton = UIBarButtonItem(image: UIImage(systemName: "plus.circle.fill"), style: .plain, target: self, action: #selector(addSourceButtonTapped))
        navigationItem.rightBarButtonItem = addButton
    }
    
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            let webcloudVC = WebcloudCollectionViewController()
            navigationController?.setViewControllers([webcloudVC], animated: false)
        } else {
            loadSavedSources()
        }
    }
    
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
                addButton.tintColor = .white
                addButton.layer.cornerRadius = 20
                
                if #available(iOS 15.0, *) {
                    var config = UIButton.Configuration.filled()
                    config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
                    config.baseForegroundColor = .white
                    config.baseBackgroundColor = .systemBlue
                    addButton.configuration = config
                } else {
                    addButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
                }
                
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
    
    
    private func loadSavedSources() {
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
        var sourcesArray = UserDefaults.standard.array(forKey: "savedSources") as? [[String: String]] ?? []
        let sourceDict: [String: String] = [
            "name": source.name,
            "sourceURL": source.sourceURL,
            "iconURL": source.iconURL ?? ""
        ]
        
        if !sourcesArray.contains(where: { $0["sourceURL"] == source.sourceURL }) {
            sourcesArray.append(sourceDict)
            UserDefaults.standard.set(sourcesArray, forKey: "savedSources")
            sources.append(source)
            collectionView.reloadData()
        }
    }
    
    
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
        
        guard let url = URL(string: sourceURL) else {
            UIView.animate(withDuration: 0.3, animations: {
                loadingView.alpha = 0
            }) { _ in
                loadingView.removeFromSuperview()
                self.showErrorAlert(message: "无效的URL")
            }
            return
        }
        
        let udid = UserDefaults.standard.string(forKey: "deviceUDID") ?? ""
        
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
                        let decoder = JSONDecoder()
                        let storeData = try decoder.decode(AppStoreData.self, from: data)
                        
                        let sourceCard = SourceCard(
                            name: storeData.name,
                            sourceURL: sourceURL,
                            iconURL: storeData.sourceicon
                        )
                        self?.saveSource(source: sourceCard)
                        
                        let successAlert = UIAlertController(
                            title: "添加成功",
                            message: "成功添加软件源: \(storeData.name)",
                            preferredStyle: .alert
                        )
                        successAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self?.present(successAlert, animated: true)
                        
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
        
        let listVC = ListCollectionViewController(sourceURL: source.sourceURL, sourceName: source.name)
        navigationController?.pushViewController(listVC, animated: true)
    }
}


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
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.1
        layer.masksToBounds = false
        layer.cornerRadius = 16
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 22
        iconImageView.layer.masksToBounds = true
        iconImageView.backgroundColor = UIColor.systemGray6
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)
        
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        nameLabel.textAlignment = .left
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        urlLabel.font = UIFont.systemFont(ofSize: 14)
        urlLabel.textColor = .secondaryLabel
        urlLabel.textAlignment = .left
        urlLabel.numberOfLines = 1
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(urlLabel)
        
        arrowImageView.image = UIImage(systemName: "chevron.right")
        arrowImageView.tintColor = .tertiaryLabel
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(arrowImageView)
        
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
        
        if let iconURLString = source.iconURL, let iconURL = URL(string: iconURLString) {
            URLSession.shared.dataTask(with: iconURL) { [weak self] data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.iconImageView.image = image
                    }
                }
            }.resume()
        } else {
            iconImageView.image = UIImage(systemName: "cloud.fill")
            iconImageView.tintColor = .systemBlue
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
    }
}


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

struct UnlockResponse: Codable {
    let code: Int
    let msg: String
}

